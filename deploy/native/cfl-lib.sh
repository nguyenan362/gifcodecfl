#!/usr/bin/env bash
set -euo pipefail

CFL_SERVICE_NAME="${CFL_SERVICE_NAME:-gifcodecfl}"
CFL_APP_USER="${CFL_APP_USER:-gifcodecfl}"
CFL_INSTALL_ROOT="${CFL_INSTALL_ROOT:-/opt/gifcodecfl}"
CFL_BIN_DIR="${CFL_BIN_DIR:-/opt/gifcodecfl/bin}"
CFL_ETC_DIR="${CFL_ETC_DIR:-/etc/gifcodecfl}"
CFL_ENV_FILE="${CFL_ENV_FILE:-/etc/gifcodecfl/.env}"
CFL_PROFILE_FILE="${CFL_PROFILE_FILE:-/etc/profile.d/cfl.sh}"
CFL_BIN_LINK="${CFL_BIN_LINK:-/usr/local/bin/cfl}"
CFL_INSTALL_SCRIPT="${CFL_INSTALL_SCRIPT:-/opt/gifcodecfl/bin/install.sh}"
CFL_MENU_SCRIPT="${CFL_MENU_SCRIPT:-/opt/gifcodecfl/bin/cfl-menu.sh}"
CFL_SYSTEMD_DIR="${CFL_SYSTEMD_DIR:-/etc/systemd/system}"
CFL_CLOUDFLARED_DIR="${CFL_CLOUDFLARED_DIR:-/etc/cloudflared}"
CFL_CLOUDFLARED_CONFIG="${CFL_CLOUDFLARED_CONFIG:-/etc/cloudflared/config.yml}"
CFL_CLOUDFLARED_CERT="${CFL_CLOUDFLARED_CERT:-/etc/cloudflared/cert.pem}"
CFL_CLOUDFLARED_SERVICE_NAME="${CFL_CLOUDFLARED_SERVICE_NAME:-gifcodecfl-cloudflared}"
CFL_DOMAIN_FILE="${CFL_DOMAIN_FILE:-/etc/gifcodecfl/cloudflare.env}"
CFL_TUNNEL_NAME="${CFL_TUNNEL_NAME:-gifcodecfl}"

log() {
  printf '[cfl] %s\n' "$*"
}

warn() {
  printf '[cfl] warning: %s\n' "$*" >&2
}

fail() {
  printf '[cfl] error: %s\n' "$*" >&2
  exit 1
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    fail "hay chay script nay bang root hoac sudo"
  fi
}

require_linux() {
  if [[ "$(uname -s)" != "Linux" ]]; then
    fail "bo script nay chi ho tro Linux"
  fi
}

prompt_yes_no() {
  local message="$1"
  local default="${2:-y}"
  local choice=""
  local suffix="[Y/n]"

  if [[ "${default}" == "n" ]]; then
    suffix="[y/N]"
  fi

  while true; do
    read -r -p "${message} ${suffix}: " choice
    choice="${choice:-${default}}"
    case "${choice}" in
      y|Y|yes|YES) return 0 ;;
      n|N|no|NO) return 1 ;;
    esac
    warn "chi nhap y hoac n"
  done
}

prompt_default() {
  local message="$1"
  local default_value="${2:-}"
  local answer=""

  if [[ -n "${default_value}" ]]; then
    read -r -p "${message} [${default_value}]: " answer
    printf '%s' "${answer:-${default_value}}"
    return
  fi

  read -r -p "${message}: " answer
  printf '%s' "${answer}"
}

ensure_dir() {
  install -d -m 0755 "$1"
}

read_env_value() {
  local file_path="$1"
  local key="$2"
  if [[ ! -f "${file_path}" ]]; then
    return 1
  fi
  awk -F '=' -v key="${key}" '$1 == key {sub(/^[^=]*=/, "", $0); print $0; exit}' "${file_path}"
}

normalize_port() {
  local value="$1"
  value="${value#http://}"
  value="${value#https://}"
  value="${value##*:}"
  printf '%s' "${value}"
}

get_listen_port() {
  local port_value=":8386"
  if [[ -f "${CFL_ENV_FILE}" ]]; then
    port_value="$(read_env_value "${CFL_ENV_FILE}" "PORT" || printf ':8386')"
  fi
  port_value="${port_value:-:8386}"
  printf '%s' "$(normalize_port "${port_value}")"
}

write_profile_file() {
  ensure_dir "$(dirname "${CFL_PROFILE_FILE}")"
  cat > "${CFL_PROFILE_FILE}" <<EOF
export CFL_SERVICE_NAME="${CFL_SERVICE_NAME}"
export CFL_APP_USER="${CFL_APP_USER}"
export CFL_INSTALL_ROOT="${CFL_INSTALL_ROOT}"
export CFL_BIN_DIR="${CFL_BIN_DIR}"
export CFL_ETC_DIR="${CFL_ETC_DIR}"
export CFL_ENV_FILE="${CFL_ENV_FILE}"
export CFL_PROFILE_FILE="${CFL_PROFILE_FILE}"
export CFL_BIN_LINK="${CFL_BIN_LINK}"
export CFL_INSTALL_SCRIPT="${CFL_INSTALL_SCRIPT}"
export CFL_MENU_SCRIPT="${CFL_MENU_SCRIPT}"
export CFL_SYSTEMD_DIR="${CFL_SYSTEMD_DIR}"
export CFL_CLOUDFLARED_DIR="${CFL_CLOUDFLARED_DIR}"
export CFL_CLOUDFLARED_CONFIG="${CFL_CLOUDFLARED_CONFIG}"
export CFL_CLOUDFLARED_CERT="${CFL_CLOUDFLARED_CERT}"
export CFL_CLOUDFLARED_SERVICE_NAME="${CFL_CLOUDFLARED_SERVICE_NAME}"
export CFL_DOMAIN_FILE="${CFL_DOMAIN_FILE}"
export CFL_TUNNEL_NAME="${CFL_TUNNEL_NAME}"
EOF
  chmod 0644 "${CFL_PROFILE_FILE}"
}

ensure_profile_vars() {
  local missing=0
  if [[ ! -f "${CFL_PROFILE_FILE}" ]]; then
    missing=1
  else
    for key in CFL_SERVICE_NAME CFL_INSTALL_ROOT CFL_ENV_FILE CFL_INSTALL_SCRIPT CFL_MENU_SCRIPT CFL_DOMAIN_FILE; do
      if ! grep -q "^export ${key}=" "${CFL_PROFILE_FILE}"; then
        missing=1
        break
      fi
    done
  fi

  if [[ "${missing}" -eq 1 ]]; then
    log "tao bo bien moi truong mac dinh tai ${CFL_PROFILE_FILE}"
    write_profile_file
  else
    log "bo bien moi truong da day du"
  fi
}

load_profile_file() {
  if [[ -f "${CFL_PROFILE_FILE}" ]]; then
    # shellcheck disable=SC1090
    . "${CFL_PROFILE_FILE}"
  fi
}

ensure_app_user() {
  if id "${CFL_APP_USER}" >/dev/null 2>&1; then
    return
  fi

  log "tao system user ${CFL_APP_USER}"
  useradd --system --home-dir "${CFL_INSTALL_ROOT}" --shell /usr/sbin/nologin "${CFL_APP_USER}"
}

ensure_default_env_file() {
  ensure_dir "${CFL_ETC_DIR}"
  if [[ -f "${CFL_ENV_FILE}" ]]; then
    return
  fi

  cat > "${CFL_ENV_FILE}" <<EOF
REDEEM_CLIENT_REGION=VN
PORT=:8386
EOF
  chmod 0640 "${CFL_ENV_FILE}"
}

configure_env_interactive() {
  ensure_default_env_file

  local current_region="VN"
  local current_port=":8386"
  current_region="$(read_env_value "${CFL_ENV_FILE}" "REDEEM_CLIENT_REGION" || printf 'VN')"
  current_port="$(read_env_value "${CFL_ENV_FILE}" "PORT" || printf ':8386')"

  local redeem_region
  local port_value
  redeem_region="$(prompt_default "Nhap REDEEM_CLIENT_REGION" "${current_region}")"
  port_value="$(prompt_default "Nhap PORT" "${current_port}")"

  cat > "${CFL_ENV_FILE}" <<EOF
REDEEM_CLIENT_REGION=${redeem_region}
PORT=${port_value}
EOF
  chmod 0640 "${CFL_ENV_FILE}"
  chown root:"${CFL_APP_USER}" "${CFL_ENV_FILE}" || true
  log "da cap nhat ${CFL_ENV_FILE}"
}

ensure_binary() {
  command -v "$1" >/dev/null 2>&1 || fail "thieu lenh $1"
}

install_go() {
  if command -v go >/dev/null 2>&1; then
    return
  fi

  log "go chua duoc cai dat, dang tien hanh cai"

  if command -v apt-get >/dev/null 2>&1; then
    apt-get update
    apt-get install -y golang-go
    return
  fi

  if command -v dnf >/dev/null 2>&1; then
    dnf install -y golang
    return
  fi

  if command -v yum >/dev/null 2>&1; then
    yum install -y golang
    return
  fi

  fail "khong tim thay trinh quan ly goi de cai Go"
}

install_cloudflared() {
  if command -v cloudflared >/dev/null 2>&1; then
    return
  fi

  log "cloudflared chua duoc cai dat, dang tien hanh cai"

  if command -v apt-get >/dev/null 2>&1; then
    ensure_binary curl
    ensure_binary gpg
    curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | gpg --dearmor -o /usr/share/keyrings/cloudflare-main.gpg
    printf 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main\n' > /etc/apt/sources.list.d/cloudflared.list
    apt-get update
    apt-get install -y cloudflared
    return
  fi

  if command -v dnf >/dev/null 2>&1; then
    ensure_binary rpm
    rpm --import https://pkg.cloudflare.com/cloudflare-main.gpg
    cat > /etc/yum.repos.d/cloudflared.repo <<EOF
[cloudflared]
name=cloudflared
baseurl=https://pkg.cloudflare.com/cloudflared/rpm
enabled=1
gpgcheck=1
gpgkey=https://pkg.cloudflare.com/cloudflare-main.gpg
EOF
    dnf install -y cloudflared
    return
  fi

  if command -v yum >/dev/null 2>&1; then
    ensure_binary rpm
    rpm --import https://pkg.cloudflare.com/cloudflare-main.gpg
    cat > /etc/yum.repos.d/cloudflared.repo <<EOF
[cloudflared]
name=cloudflared
baseurl=https://pkg.cloudflare.com/cloudflared/rpm
enabled=1
gpgcheck=1
gpgkey=https://pkg.cloudflare.com/cloudflare-main.gpg
EOF
    yum install -y cloudflared
    return
  fi

  fail "khong tim thay trinh quan ly goi de cai cloudflared"
}

cloudflared_bin() {
  command -v cloudflared || true
}

current_domain() {
  read_env_value "${CFL_DOMAIN_FILE}" "CFL_DOMAIN" || true
}

current_tunnel_id() {
  read_env_value "${CFL_DOMAIN_FILE}" "CFL_TUNNEL_ID" || true
}

save_domain_state() {
  local domain="$1"
  local tunnel_id="$2"
  ensure_dir "${CFL_ETC_DIR}"
  cat > "${CFL_DOMAIN_FILE}" <<EOF
CFL_DOMAIN=${domain}
CFL_TUNNEL_NAME=${CFL_TUNNEL_NAME}
CFL_TUNNEL_ID=${tunnel_id}
EOF
  chmod 0640 "${CFL_DOMAIN_FILE}"
}

extract_tunnel_id() {
  local tunnel_name="$1"
  cloudflared tunnel info "${tunnel_name}" 2>/dev/null | awk -F ': ' '/^ID:/ {print $2; exit}'
}

copy_cloudflared_materials() {
  local tunnel_id="$1"
  local source_home="${HOME:-/root}"
  local source_dir="${source_home}/.cloudflared"
  ensure_dir "${CFL_CLOUDFLARED_DIR}"

  if [[ -f "${source_dir}/cert.pem" ]]; then
    install -m 0600 "${source_dir}/cert.pem" "${CFL_CLOUDFLARED_CERT}"
  fi

  if [[ -f "${source_dir}/${tunnel_id}.json" ]]; then
    install -m 0600 "${source_dir}/${tunnel_id}.json" "${CFL_CLOUDFLARED_DIR}/${tunnel_id}.json"
    return
  fi

  fail "khong tim thay credentials tunnel ${source_dir}/${tunnel_id}.json"
}

write_cloudflared_config() {
  local domain="$1"
  local tunnel_id="$2"
  local listen_port="$3"
  ensure_dir "${CFL_CLOUDFLARED_DIR}"
  cat > "${CFL_CLOUDFLARED_CONFIG}" <<EOF
tunnel: ${tunnel_id}
credentials-file: ${CFL_CLOUDFLARED_DIR}/${tunnel_id}.json
ingress:
  - hostname: ${domain}
    service: http://127.0.0.1:${listen_port}
  - service: http_status:404
EOF
  chmod 0600 "${CFL_CLOUDFLARED_CONFIG}"
}

configure_cloudflare_tunnel() {
  install_cloudflared
  ensure_dir "${CFL_CLOUDFLARED_DIR}"

  log "bat dau xac thuc Cloudflare Tunnel"
  cloudflared tunnel login

  local domain_default
  local domain
  local tunnel_id
  local listen_port

  domain_default="$(current_domain)"
  domain="$(prompt_default "Nhap domain muon expose qua Cloudflare Tunnel" "${domain_default}")"
  if [[ -z "${domain}" ]]; then
    fail "domain khong duoc de trong"
  fi

  if ! cloudflared tunnel info "${CFL_TUNNEL_NAME}" >/dev/null 2>&1; then
    log "tao tunnel ${CFL_TUNNEL_NAME}"
    cloudflared tunnel create "${CFL_TUNNEL_NAME}"
  else
    log "tunnel ${CFL_TUNNEL_NAME} da ton tai"
  fi

  tunnel_id="$(extract_tunnel_id "${CFL_TUNNEL_NAME}")"
  if [[ -z "${tunnel_id}" ]]; then
    fail "khong doc duoc tunnel id cho ${CFL_TUNNEL_NAME}"
  fi

  copy_cloudflared_materials "${tunnel_id}"

  log "gan DNS route cho ${domain}"
  cloudflared tunnel route dns "${CFL_TUNNEL_NAME}" "${domain}"

  listen_port="$(get_listen_port)"
  write_cloudflared_config "${domain}" "${tunnel_id}" "${listen_port}"
  save_domain_state "${domain}" "${tunnel_id}"
  log "da luu cau hinh Cloudflare Tunnel vao ${CFL_CLOUDFLARED_CONFIG}"
}

service_enabled() {
  systemctl is-enabled "$1" >/dev/null 2>&1
}

service_active() {
  systemctl is-active "$1" >/dev/null 2>&1
}

show_service_status() {
  local service_name="$1"
  if systemctl list-unit-files "${service_name}.service" >/dev/null 2>&1; then
    systemctl status "${service_name}" --no-pager || true
  else
    warn "khong tim thay service ${service_name}"
  fi
}
