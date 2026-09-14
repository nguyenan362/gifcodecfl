#!/usr/bin/env bash
# deploy/termux/cfl-termux-lib.sh
# Thu vien dung chung cho bo script Termux (install.sh + cfl-termux-menu.sh).
# Duoc thiet ke de mirror chuc nang cua deploy/native/cfl-lib.sh nhung thay
# systemd = termux-services (runit), root user = user hien tai, duong dan he
# thong = $PREFIX. Bo sung tinh nang rieng Termux: wake-lock.
set -euo pipefail

# --- Duong dan va bien mac dinh ----------------------------------------------
# Dung ${VAR:=default} de xu ly ca truong hop PREFIX bi set rong (khac unset).
PREFIX="${PREFIX:=/data/data/com.termux/files/usr}"

CFL_SERVICE_NAME="${CFL_SERVICE_NAME:-gifcodecfl}"
CFL_APP_USER="${CFL_APP_USER:-$(id -un 2>/dev/null || echo termux)}"
CFL_INSTALL_ROOT="${CFL_INSTALL_ROOT:-${HOME}/gifcodecfl}"
CFL_BIN_DIR="${CFL_BIN_DIR:-${PREFIX}/bin}"
CFL_ETC_DIR="${CFL_ETC_DIR:-${PREFIX}/etc/gifcodecfl}"
CFL_ENV_FILE="${CFL_ENV_FILE:-${CFL_ETC_DIR}/.env}"
CFL_PROFILE_FILE="${CFL_PROFILE_FILE:-${CFL_ETC_DIR}/profile.sh}"
CFL_BIN_LINK="${CFL_BIN_LINK:-${PREFIX}/bin/cfl-termux}"
CFL_INSTALL_SCRIPT="${CFL_INSTALL_SCRIPT:-${PREFIX}/bin/cfl-install.sh}"
CFL_MENU_SCRIPT="${CFL_MENU_SCRIPT:-${PREFIX}/bin/cfl-termux-menu.sh}"
CFL_SV_DIR="${CFL_SV_DIR:-${PREFIX}/etc/sv}"
CFL_VAR_SERVICE_DIR="${CFL_VAR_SERVICE_DIR:-${PREFIX}/var/service}"
CFL_CLOUDFLARED_DIR="${CFL_CLOUDFLARED_DIR:-${PREFIX}/etc/cloudflared}"
CFL_CLOUDFLARED_CONFIG="${CFL_CLOUDFLARED_CONFIG:-${CFL_CLOUDFLARED_DIR}/config.yml}"
CFL_CLOUDFLARED_CERT="${CFL_CLOUDFLARED_CERT:-${CFL_CLOUDFLARED_DIR}/cert.pem}"
CFL_TUNNEL_SERVICE_NAME="${CFL_TUNNEL_SERVICE_NAME:-gifcodecfl-tunnel}"
CFL_DOMAIN_FILE="${CFL_DOMAIN_FILE:-${CFL_ETC_DIR}/cloudflare.env}"
CFL_TUNNEL_NAME="${CFL_TUNNEL_NAME:-gifcodecfl}"
CFL_WAKE_LOCK_STATE="${CFL_WAKE_LOCK_STATE:-${CFL_ETC_DIR}/wakelock.state}"
CFL_REPO_URL="${CFL_REPO_URL:-https://github.com/nguyenan362/gifcodecfl.git}"
CFL_REPO_BRANCH="${CFL_REPO_BRANCH:-main}"
CFL_BASHRC_MARKER="gifcodecfl-runsvdir"
GO_MIN_VERSION="${GO_MIN_VERSION:-1.22}"

# --- Log / color -------------------------------------------------------------
if [[ -t 1 ]]; then
  _RST=$'\033[0m'; _GRN=$'\033[1;32m'; _YLW=$'\033[1;33m'
  _RED=$'\033[1;31m'; _CYN=$'\033[1;36m'
else
  _RST=""; _GRN=""; _YLW=""; _RED=""; _CYN=""
fi

log()   { printf "%s[cfl]%s %s\n" "${_CYN}" "${_RST}" "$*"; }
ok()    { printf "%s[cfl]%s %s\n" "${_GRN}" "${_RST}" "$*"; }
warn()  { printf "%s[cfl] warning:%s %s\n" "${_YLW}" "${_RST}" "$*" >&2; }
fail()  { printf "%s[cfl] error:%s %s\n" "${_RED}" "${_RST}" "$*" >&2; exit 1; }

# --- Kiem tra moi truong -----------------------------------------------------
require_termux() {
  if [[ "$(uname -s)" != "Linux" ]]; then
    fail "bo script nay chi ho tro Linux/Termux"
  fi
  if [[ "${PREFIX}" != */com.termux/* ]]; then
    fail "khong phat hien Termux (PREFIX=${PREFIX}). Hay chay trong app Termux."
  fi
  if ! command -v pkg >/dev/null 2>&1; then
    fail "khong tim thay 'pkg'. Hay cai Termux chinh hang tu F-Droid."
  fi
  warn_if_termux_googleplay
}

ensure_binary() {
  command -v "$1" >/dev/null 2>&1 || fail "thieu lenh $1"
}

ensure_pkg_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "cai dat $1"
    pkg install -y "$1"
  fi
}

prompt_yes_no() {
  local message="$1" default="${2:-y}" choice="" suffix="[Y/n]"
  if [[ "${default}" == "n" ]]; then suffix="[y/N]"; fi
  while true; do
    read -r -p "${message} ${suffix}: " choice
    choice="${choice:-${default}}"
    case "${choice}" in
      y|Y|yes|YES) return 0 ;;
      n|N|no|NO)   return 1 ;;
    esac
    warn "chi nhap y hoac n"
  done
}

# --- Kiem tra Termux ban Google Play (loi e_type khi chay binary Go) ---------
detect_termux_googleplay() {
  local t_info t_ver
  t_info="$(termux-info 2>/dev/null || echo "")"
  t_ver="$(echo "${t_info}" | grep "TERMUX_VERSION" | cut -d'=' -f2)"
  t_ver="${t_ver:-${TERMUX_VERSION:-unknown}}"
  if [[ "${t_ver}" == *"googleplay"* ]] || [[ "${t_info}" == *"googleplay"* ]] || [[ "${t_ver}" == "0.101" ]]; then
    return 0
  fi
  return 1
}

warn_if_termux_googleplay() {
  detect_termux_googleplay || return 0
  echo ""
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo "  CANH BAO: PHAT HIEN TERMUX BAN GOOGLE PLAY"
  echo "----------------------------------------------------------------"
  echo "Ban dang dung Termux tai tu Google Play. Ban nay bi han che boi"
  echo "chinh sach cua Google nen KHONG THE chay cac ung dung Go nhu"
  echo "gifcodecfl tren Android 10+ (loi e_type khi exec binary)."
  echo ""
  echo "CACH KHAC PHUC:"
  echo "  1. Go cai dat Termux hien tai."
  echo "  2. Cai ban moi nhat tu F-Droid hoac GitHub:"
  echo "     https://github.com/termux/termux-app/releases"
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo ""
  if [[ -t 0 ]]; then
    if ! prompt_yes_no "Ban van muon tiep tuc du co the gap loi?" "n"; then
      exit 1
    fi
  else
    warn "khong co terminal tuong tac, tiep tuc voi rui ro loi e_type"
  fi
}

prompt_default() {
  local message="$1" default_value="${2:-}" answer=""
  if [[ -n "${default_value}" ]]; then
    read -r -p "${message} [${default_value}]: " answer
    printf '%s' "${answer:-${default_value}}"
    return
  fi
  read -r -p "${message}: " answer
  printf '%s' "${answer}"
}

ensure_dir() {
  mkdir -p "$1" || fail "khong the tao thu muc: $1"
}

read_env_value() {
  local file_path="$1" key="$2"
  [[ -f "${file_path}" ]] || return 1
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

# --- Profile vars (mirror native's write_profile_file) -----------------------
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
export CFL_SV_DIR="${CFL_SV_DIR}"
export CFL_VAR_SERVICE_DIR="${CFL_VAR_SERVICE_DIR}"
export CFL_CLOUDFLARED_DIR="${CFL_CLOUDFLARED_DIR}"
export CFL_CLOUDFLARED_CONFIG="${CFL_CLOUDFLARED_CONFIG}"
export CFL_CLOUDFLARED_CERT="${CFL_CLOUDFLARED_CERT}"
export CFL_TUNNEL_SERVICE_NAME="${CFL_TUNNEL_SERVICE_NAME}"
export CFL_DOMAIN_FILE="${CFL_DOMAIN_FILE}"
export CFL_TUNNEL_NAME="${CFL_TUNNEL_NAME}"
export CFL_WAKE_LOCK_STATE="${CFL_WAKE_LOCK_STATE}"
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

# --- Env file -----------------------------------------------------------------
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
  local current_region="VN" current_port=":8386"
  current_region="$(read_env_value "${CFL_ENV_FILE}" "REDEEM_CLIENT_REGION" || printf 'VN')"
  current_port="$(read_env_value "${CFL_ENV_FILE}" "PORT" || printf ':8386')"

  local redeem_region port_value
  redeem_region="$(prompt_default "Nhap REDEEM_CLIENT_REGION" "${current_region}")"
  port_value="$(prompt_default "Nhap PORT" "${current_port}")"
  port_value="$(normalize_port "${port_value}")"
  if [[ "${port_value}" != :* ]]; then
    port_value=":${port_value}"
  fi
  cat > "${CFL_ENV_FILE}" <<EOF
REDEEM_CLIENT_REGION=${redeem_region}
PORT=${port_value}
EOF
  chmod 0640 "${CFL_ENV_FILE}"
  log "da cap nhat ${CFL_ENV_FILE}"
}

# --- Wake lock (Termux-specific) ---------------------------------------------
wake_lock_supported() {
  command -v termux-wake-lock >/dev/null 2>&1
}

is_wake_locked() {
  # Termux khong co API doc trang thai wake-lock; dung state file ta tu quan ly.
  [[ -f "${CFL_WAKE_LOCK_STATE}" ]]
}

ensure_wake_lock_state_dir() {
  ensure_dir "$(dirname "${CFL_WAKE_LOCK_STATE}")"
}

cmd_wake_lock() {
  require_termux
  if ! wake_lock_supported; then
    warn "khong co 'termux-wake-lock'."
    warn "Cai Termux:API tu F-Droid:"
    warn "  https://f-droid.org/packages/com.termux.api/"
    warn "Sau do mo lai Termux va chay lenh nay."
    return 1
  fi
  if termux-wake-lock; then
    ensure_wake_lock_state_dir
    date '+%Y-%m-%dT%H:%M:%S%z' > "${CFL_WAKE_LOCK_STATE}"
    ok "wake-lock da bat (app se song khi tat man hinh)"
  else
    fail "termux-wake-lock that bai (co the Termux:API chua grant quyen)"
  fi
}

cmd_wake_unlock() {
  require_termux
  if ! command -v termux-wake-unlock >/dev/null 2>&1; then
    warn "khong co 'termux-wake-unlock' (Termux:API chua cai?)"
    rm -f "${CFL_WAKE_LOCK_STATE}"
    return 0
  fi
  termux-wake-unlock || true
  rm -f "${CFL_WAKE_LOCK_STATE}"
  ok "wake-lock da tat"
}

# --- Runit service management (mirror native systemctl) ----------------------
ensure_termux_services() {
  if ! command -v runsvdir >/dev/null 2>&1; then
    log "cai dat termux-services (runit supervision)"
    pkg install -y termux-services
  fi
  command -v sv >/dev/null 2>&1 || fail "sau khi cai termux-services, van khong co 'sv'"
}

ensure_bashrc_runsvdir() {
  local bashrc="${HOME}/.bashrc"
  touch "${bashrc}"
  if grep -qF "${CFL_BASHRC_MARKER}" "${bashrc}" 2>/dev/null; then
    return 0
  fi
  log "them runsvdir hook vao ${bashrc}"
  cat >> "${bashrc}" <<EOF

# ${CFL_BASHRC_MARKER}: bat runit supervision moi khi mo Termux
if [ -z "\${RUNSVDIR:-}" ] && [ -x "\$PREFIX/bin/runsvdir" ]; then
  export RUNSVDIR="\$PREFIX/var/service"
  export SVDIR="\$PREFIX/etc/sv"
  runsvdir "\${RUNSVDIR}" >/dev/null 2>&1 &
  disown
fi
EOF
}

start_runsvdir_now() {
  if pgrep -f "runsvdir .*${CFL_VAR_SERVICE_DIR}" >/dev/null 2>&1; then
    return 0
  fi
  log "khoi dong runsvdir cho session hien tai"
  ensure_dir "${CFL_VAR_SERVICE_DIR}"
  (
    export RUNSVDIR="${CFL_VAR_SERVICE_DIR}"
    export SVDIR="${CFL_SV_DIR}"
    nohup runsvdir "${CFL_VAR_SERVICE_DIR}" >/dev/null 2>&1 &
    disown || true
  )
}

enable_runit_service() {
  local name="$1"
  local target_sv="${CFL_SV_DIR}/${name}"
  local active_link="${CFL_VAR_SERVICE_DIR}/${name}"

  [[ -x "${target_sv}/run" ]] || fail "khong co run script: ${target_sv}/run"
  if [[ -L "${active_link}" || -e "${active_link}" ]]; then
    log "service ${name} da duoc enable"
    return 0
  fi

  ensure_dir "${CFL_VAR_SERVICE_DIR}"
  if command -v sv-enable >/dev/null 2>&1; then
    if sv-enable "${name}" 2>/dev/null; then
      return 0
    fi
    warn "sv-enable that bai, thu manual symlink"
  fi
  ln -sfn "../sv/${name}" "${active_link}" \
    || fail "khong tao duoc symlink ${active_link}"
}

disable_runit_service() {
  local name="$1"
  local active_link="${CFL_VAR_SERVICE_DIR}/${name}"
  if command -v sv-disable >/dev/null 2>&1; then
    sv-disable "${name}" 2>/dev/null || rm -f "${active_link}"
  else
    rm -f "${active_link}"
  fi
}

service_enabled() {
  local name="$1"
  [[ -L "${CFL_VAR_SERVICE_DIR}/${name}" || -e "${CFL_SV_DIR}/${name}" ]] \
    && [[ -L "${CFL_VAR_SERVICE_DIR}/${name}" ]]
}

service_active() {
  local name="$1"
  command -v sv >/dev/null 2>&1 \
    && sv status "${name}" 2>/dev/null | grep -q "^run:"
}

show_service_status() {
  local name="$1"
  if command -v sv >/dev/null 2>&1; then
    sv status "${name}" 2>/dev/null || echo "(chua chay)"
  else
    warn "khong co 'sv' de xem trang thai"
  fi
}

# --- App runit service --------------------------------------------------------
write_app_service_run() {
  ensure_termux_services
  ensure_dir "${CFL_SV_DIR}/${CFL_SERVICE_NAME}"
  log "ghi runit service: ${CFL_SV_DIR}/${CFL_SERVICE_NAME}/run"
  cat > "${CFL_SV_DIR}/${CFL_SERVICE_NAME}/run" <<EOF
#!/data/data/com.termux/files/usr/bin/sh
# gifcodecfl - runit service (tu restart khi crash)
exec 2>&1
APP_HOME="${CFL_INSTALL_ROOT}"
APP_ENV_FILE="${CFL_ENV_FILE}"
APP_BIN="${CFL_INSTALL_ROOT}/server"
APP_LOG="${CFL_INSTALL_ROOT}/gifcodecfl.log"
# Bat wake-lock moi khi service khoi dong de song qua dem sau khi reboot.
# Chi nhap lenh khi chua co lock (trang thai state file do lib quan ly).
if [ -x "${PREFIX}/bin/termux-wake-lock" ] && [ ! -f "${CFL_WAKE_LOCK_STATE}" ]; then
  "${PREFIX}/bin/termux-wake-lock" 2>/dev/null || true
fi
cd "\${APP_HOME}" || exit 1
if [ -f "\${APP_ENV_FILE}" ]; then
  set -a
  . "\${APP_ENV_FILE}"
  set +a
fi
# Cap nhat state file de run script khong goi termux-wake-lock lap lai moi lan restart.
if [ ! -f "${CFL_WAKE_LOCK_STATE}" ] && [ -x "${PREFIX}/bin/termux-wake-lock" ]; then
  mkdir -p "$(dirname "${CFL_WAKE_LOCK_STATE}")" 2>/dev/null || true
  date '+%Y-%m-%dT%H:%M:%S%z' > "${CFL_WAKE_LOCK_STATE}" 2>/dev/null || true
fi
exec "\${APP_BIN}" >>"\${APP_LOG}" 2>&1
EOF
  chmod +x "${CFL_SV_DIR}/${CFL_SERVICE_NAME}/run"
}

install_app_service() {
  write_app_service_run
  ensure_bashrc_runsvdir
  start_runsvdir_now
  enable_runit_service "${CFL_SERVICE_NAME}"
  ok "app service da san sang (runit se start khi mo Termux)"
}

uninstall_app_service() {
  if service_enabled "${CFL_SERVICE_NAME}"; then
    sv down "${CFL_SERVICE_NAME}" 2>/dev/null || true
    disable_runit_service "${CFL_SERVICE_NAME}"
  fi
  if [[ -d "${CFL_SV_DIR}/${CFL_SERVICE_NAME}" ]]; then
    rm -rf "${CFL_SV_DIR}/${CFL_SERVICE_NAME}"
  fi
}

# --- Cloudflared binary -------------------------------------------------------
detect_termux_arch() {
  # uu tien dpkg (Termux) vi uname -m co tra ve 32bit tren kernel 64bit -> sai arch
  local arch=""
  if [[ "${PREFIX}" == */com.termux/* ]] && command -v dpkg >/dev/null 2>&1; then
    arch="$(dpkg --print-architecture 2>/dev/null || echo "")"
  fi
  case "${arch:-$(uname -m)}" in
    aarch64|arm64)        echo "arm64" ;;
    arm|armv7l|armv7|armhf) echo "arm" ;;
    x86_64|amd64)         echo "amd64" ;;
    i386|i686|386)        echo "386" ;;
    *) return 1 ;;
  esac
}

install_cloudflared() {
  if command -v cloudflared >/dev/null 2>&1; then
    return 0
  fi
  ensure_binary curl
  local arch url dest="${PREFIX}/bin/cloudflared"
  arch="$(detect_termux_arch)" || fail "khong ho tro kien truc: $(uname -m)"
  url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${arch}"
  log "tai cloudflared (${arch}) -> ${dest}"
  if ! curl -fsSL --retry 3 -o "${dest}.tmp" "${url}"; then
    rm -f "${dest}.tmp"
    fail "tai cloudflared that bai. Truy cap thu cong: ${url}"
  fi
  mv -f "${dest}.tmp" "${dest}"
  chmod +x "${dest}"
  # Verify binary chay duoc (phat hien mount noexec / sai arch som hon la luc service crash)
  if ! "${dest}" --version >/dev/null 2>&1; then
    rm -f "${dest}"
    fail "cloudflared tai ve khong chay duoc tren thiet bi nay (co the do mount noexec hoac sai kien truc ${arch}). Cai bang pkg: pkg install -y cloudflared"
  fi
  ok "cloudflared: $("${dest}" --version 2>&1 | head -1)"
}

cloudflared_bin() {
  command -v cloudflared || true
}

# --- Tunnel state -------------------------------------------------------------
current_domain() {
  read_env_value "${CFL_DOMAIN_FILE}" "CFL_DOMAIN" || true
}

current_tunnel_id() {
  read_env_value "${CFL_DOMAIN_FILE}" "CFL_TUNNEL_ID" || true
}

save_domain_state() {
  local domain="$1" tunnel_id="$2"
  ensure_dir "${CFL_ETC_DIR}"
  cat > "${CFL_DOMAIN_FILE}" <<EOF
CFL_DOMAIN=${domain}
CFL_TUNNEL_NAME=${CFL_TUNNEL_NAME}
CFL_TUNNEL_ID=${tunnel_id}
EOF
  chmod 0640 "${CFL_DOMAIN_FILE}"
}

extract_tunnel_id() {
  local tunnel_name="$1" id
  id="$(cloudflared tunnel info "${tunnel_name}" 2>/dev/null \
    | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' \
    | head -n1 || true)"
  printf '%s' "${id}"
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
  local domain="$1" tunnel_id="$2" listen_port="$3"
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

cloudflared_login() {
  local source_cert="${HOME:-/root}/.cloudflared/cert.pem"
  if [[ -f "${source_cert}" ]]; then
    log "phat hien cert da ton tai tai ${source_cert}"
    if prompt_yes_no "Ban co muon xac thuc lai (se ghi de cert cu) khong?" "n"; then
      rm -f "${source_cert}"
      cloudflared tunnel login
    else
      log "giu nguyen cert hien tai, bo qua xac thuc lai"
    fi
  else
    log "==============================================================="
    log "  cloudflared se in 1 URL. Copy va mo trong browser tren"
    log "  thiet bi nao do, dang nhap Cloudflare, chon domain,"
    log "  bam Authorize. Quay lai day cho den khi xong."
    log "==============================================================="
    cloudflared tunnel login
  fi
}

configure_cloudflare_tunnel() {
  install_cloudflared
  ensure_dir "${CFL_CLOUDFLARED_DIR}"

  log "bat dau xac thuc Cloudflare Tunnel"
  cloudflared_login

  local domain_default domain tunnel_id listen_port
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

remove_cloudflare_tunnel() {
  if [[ -f "${CFL_DOMAIN_FILE}" ]]; then
    local tunnel_id
    tunnel_id="$(current_tunnel_id)"
    if [[ -n "${tunnel_id}" ]] && command -v cloudflared >/dev/null 2>&1; then
      log "xoa tunnel ${CFL_TUNNEL_NAME} (id ${tunnel_id})"
      cloudflared tunnel delete "${CFL_TUNNEL_NAME}" || warn "khong the xoa tunnel tren Cloudflare"
    fi
  fi
  uninstall_tunnel_service
  rm -f "${CFL_CLOUDFLARED_CONFIG}" "${CFL_CLOUDFLARED_CERT}" "${CFL_DOMAIN_FILE}"
  log "da go bo cau hinh Cloudflare Tunnel"
}

# --- Tunnel runit service ------------------------------------------------------
write_tunnel_service_run() {
  ensure_termux_services
  ensure_dir "${CFL_SV_DIR}/${CFL_TUNNEL_SERVICE_NAME}"
  cat > "${CFL_SV_DIR}/${CFL_TUNNEL_SERVICE_NAME}/run" <<EOF
#!/data/data/com.termux/files/usr/bin/sh
# gifcodecfl cloudflare tunnel (runit service)
exec 2>&1
CF_BIN="${PREFIX}/bin/cloudflared"
CF_CFG="${CFL_CLOUDFLARED_CONFIG}"
if [ ! -x "\${CF_BIN}" ]; then
  echo "cloudflared not found at \${CF_BIN}" >&2
  sleep 5
  exit 1
fi
if [ ! -f "\${CF_CFG}" ]; then
  echo "tunnel config not found at \${CF_CFG}" >&2
  sleep 5
  exit 1
fi
exec "\${CF_BIN}" tunnel --config "\${CF_CFG}" --no-autoupdate run
EOF
  chmod +x "${CFL_SV_DIR}/${CFL_TUNNEL_SERVICE_NAME}/run"
}

install_tunnel_service() {
  [[ -f "${CFL_CLOUDFLARED_CONFIG}" ]] || fail "chua co config tunnel. Chay configure_cloudflare_tunnel truoc."
  write_tunnel_service_run
  enable_runit_service "${CFL_TUNNEL_SERVICE_NAME}"
  ok "tunnel service da enable"
}

uninstall_tunnel_service() {
  if service_enabled "${CFL_TUNNEL_SERVICE_NAME}"; then
    sv down "${CFL_TUNNEL_SERVICE_NAME}" 2>/dev/null || true
    disable_runit_service "${CFL_TUNNEL_SERVICE_NAME}"
  fi
  if [[ -d "${CFL_SV_DIR}/${CFL_TUNNEL_SERVICE_NAME}" ]]; then
    rm -rf "${CFL_SV_DIR}/${CFL_TUNNEL_SERVICE_NAME}"
  fi
}

enable_tunnel_service_if_configured() {
  if [[ -f "${CFL_CLOUDFLARED_CONFIG}" ]]; then
    install_tunnel_service
    sv up "${CFL_TUNNEL_SERVICE_NAME}" 2>/dev/null || true
  fi
}
