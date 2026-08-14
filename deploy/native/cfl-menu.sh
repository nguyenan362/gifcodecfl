#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
. "${SCRIPT_DIR}/cfl-lib.sh"

load_profile_file

start_app() {
  require_linux
  require_root
  systemctl enable "${CFL_SERVICE_NAME}" >/dev/null
  systemctl restart "${CFL_SERVICE_NAME}"
  log "app da duoc khoi dong lai"
}

reconfigure_domain() {
  require_linux
  require_root
  "${CFL_INSTALL_SCRIPT}" --configure-domain
}

check_status() {
  require_linux
  log "trang thai app"
  show_service_status "${CFL_SERVICE_NAME}"

  if [[ -f "${CFL_DOMAIN_FILE}" ]]; then
    log "domain Cloudflare hien tai: $(current_domain)"
    show_service_status "${CFL_CLOUDFLARED_SERVICE_NAME}"
  fi
}

show_menu() {
  while true; do
    cat <<EOF

========= CFL MENU =========
1. Khoi dong app
2. Cau hinh lai domain Cloudflare Tunnel
3. Check trang thai app
4. Thoat
EOF

    read -r -p "Chon chuc nang [1-4]: " choice
    case "${choice}" in
      1)
        start_app
        ;;
      2)
        reconfigure_domain
        ;;
      3)
        check_status
        ;;
      4)
        exit 0
        ;;
      *)
        warn "lua chon khong hop le"
        ;;
    esac
  done
}

show_menu
