#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
. "${SCRIPT_DIR}/cfl-lib.sh"

APP_TEMPLATE="${SCRIPT_DIR}/gifcodecfl.service.tpl"
TUNNEL_TEMPLATE="${SCRIPT_DIR}/gifcodecfl-cloudflared.service.tpl"

render_template() {
  local template_path="$1"
  local output_path="$2"
  local cloudflared_exec

  cloudflared_exec="$(cloudflared_bin)"
  cloudflared_exec="${cloudflared_exec:-/usr/local/bin/cloudflared}"

  sed \
    -e "s|__CFL_SERVICE_NAME__|${CFL_SERVICE_NAME}|g" \
    -e "s|__CFL_APP_USER__|${CFL_APP_USER}|g" \
    -e "s|__CFL_INSTALL_ROOT__|${CFL_INSTALL_ROOT}|g" \
    -e "s|__CFL_ENV_FILE__|${CFL_ENV_FILE}|g" \
    -e "s|__CFL_CLOUDFLARED_SERVICE_NAME__|${CFL_CLOUDFLARED_SERVICE_NAME}|g" \
    -e "s|__CFL_CLOUDFLARED_CONFIG__|${CFL_CLOUDFLARED_CONFIG}|g" \
    -e "s|__CLOUDFLARED_BIN__|${cloudflared_exec}|g" \
    "${template_path}" > "${output_path}"
}

build_app() {
  install_go
  ensure_binary go
  ensure_dir "${CFL_INSTALL_ROOT}"
  ensure_dir "${CFL_BIN_DIR}"

  log "build binary Go"
  (
    cd "${REPO_ROOT}"
    CGO_ENABLED=0 go build -o "${CFL_INSTALL_ROOT}/server" .
  )

  rm -rf "${CFL_INSTALL_ROOT}/web"
  cp -R "${REPO_ROOT}/web" "${CFL_INSTALL_ROOT}/web"
  install -m 0755 "${SCRIPT_DIR}/cfl-lib.sh" "${CFL_BIN_DIR}/cfl-lib.sh"
  install -m 0755 "${SCRIPT_DIR}/install.sh" "${CFL_BIN_DIR}/install.sh"
  install -m 0755 "${SCRIPT_DIR}/cfl-menu.sh" "${CFL_BIN_DIR}/cfl-menu.sh"
  install -m 0644 "${APP_TEMPLATE}" "${CFL_BIN_DIR}/gifcodecfl.service.tpl"
  install -m 0644 "${TUNNEL_TEMPLATE}" "${CFL_BIN_DIR}/gifcodecfl-cloudflared.service.tpl"
  ln -sf "${CFL_MENU_SCRIPT}" "${CFL_BIN_LINK}"
  chown -R "${CFL_APP_USER}:${CFL_APP_USER}" "${CFL_INSTALL_ROOT}"
}

install_systemd_units() {
  ensure_dir "${CFL_SYSTEMD_DIR}"
  render_template "${APP_TEMPLATE}" "${CFL_SYSTEMD_DIR}/${CFL_SERVICE_NAME}.service"
  render_template "${TUNNEL_TEMPLATE}" "${CFL_SYSTEMD_DIR}/${CFL_CLOUDFLARED_SERVICE_NAME}.service"
  chmod 0644 "${CFL_SYSTEMD_DIR}/${CFL_SERVICE_NAME}.service" "${CFL_SYSTEMD_DIR}/${CFL_CLOUDFLARED_SERVICE_NAME}.service"
  systemctl daemon-reload
}

enable_core_services() {
  systemctl enable "${CFL_SERVICE_NAME}" >/dev/null
  systemctl restart "${CFL_SERVICE_NAME}"
}

enable_tunnel_service_if_configured() {
  if [[ -f "${CFL_CLOUDFLARED_CONFIG}" ]]; then
    systemctl enable "${CFL_CLOUDFLARED_SERVICE_NAME}" >/dev/null
    systemctl restart "${CFL_CLOUDFLARED_SERVICE_NAME}"
  fi
}

interactive_install() {
  require_linux
  require_root
  ensure_binary systemctl
  ensure_binary sed
  ensure_binary cp
  ensure_binary install
  ensure_binary curl

  load_profile_file
  ensure_profile_vars
  load_profile_file
  ensure_app_user
  ensure_default_env_file
  build_app
  install_systemd_units

  if prompt_yes_no "Ban co muon cau hinh file .env ngay bay gio khong?" "y"; then
    configure_env_interactive
  else
    log "giu nguyen cau hinh hien tai trong ${CFL_ENV_FILE}"
  fi

  enable_core_services

  if prompt_yes_no "Ban co muon cau hinh Cloudflare Tunnel khong?" "n"; then
    configure_cloudflare_tunnel
    install_systemd_units
    enable_tunnel_service_if_configured
  else
    log "bo qua Cloudflare Tunnel"
  fi

  cat <<EOF

Hoan tat cai dat.
- Lenh menu: ${CFL_BIN_LINK}
- Service app: ${CFL_SERVICE_NAME}
- File env: ${CFL_ENV_FILE}
EOF

  if [[ -f "${CFL_DOMAIN_FILE}" ]]; then
    printf '%s\n' "- Domain tunnel: $(current_domain)"
  fi
}

reconfigure_domain_only() {
  require_linux
  require_root
  load_profile_file
  ensure_profile_vars
  load_profile_file
  configure_cloudflare_tunnel
  install_systemd_units
  enable_tunnel_service_if_configured
}

case "${1:-}" in
  --configure-domain)
    reconfigure_domain_only
    ;;
  "")
    interactive_install
    ;;
  *)
    fail "tham so khong hop le: ${1}"
    ;;
esac
