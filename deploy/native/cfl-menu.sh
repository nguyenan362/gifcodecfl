#!/usr/bin/env bash
set -euo pipefail

SCRIPT_SRC="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_SRC}")" && pwd)"

# shellcheck disable=SC1091
. "${SCRIPT_DIR}/cfl-lib.sh"

load_profile_file

check_status() {
  require_linux
  log "trang thai app"
  show_service_status "${CFL_SERVICE_NAME}"

  if [[ -f "${CFL_DOMAIN_FILE}" ]]; then
    log "domain Cloudflare hien tai: $(current_domain)"
    show_service_status "${CFL_CLOUDFLARED_SERVICE_NAME}"
  fi
}

toggle_app() {
  require_linux
  require_root

  if service_enabled "${CFL_SERVICE_NAME}"; then
    log "app dang bat, tien hanh tat"
    systemctl disable "${CFL_SERVICE_NAME}" >/dev/null
    systemctl stop "${CFL_SERVICE_NAME}" >/dev/null
    log "app da duoc tat"
  else
    log "app dang tat, tien hanh bat"
    systemctl enable "${CFL_SERVICE_NAME}" >/dev/null
    systemctl start "${CFL_SERVICE_NAME}" >/dev/null
    log "app da duoc bat"
  fi
}

reconfigure_domain() {
  require_linux
  require_root
  "${CFL_INSTALL_SCRIPT}" --configure-domain
}

remove_tunnel() {
  require_linux
  require_root
  if ! prompt_yes_no "Ban chac chan muon go bo Cloudflare Tunnel?" "n"; then
    log "huy bo go Cloudflare Tunnel"
    return
  fi
  "${CFL_INSTALL_SCRIPT}" --remove-tunnel
}

show_menu() {
  while true; do
    cat <<EOF

========= CFL MENU =========
1. Kiem tra trang thai hoat dong cua app
2. Bat/Tat chay app
3. Cau hinh lai hoac go bo Cloudflare Tunnel
4. Thoat
EOF

    read -r -p "Chon chuc nang [1-4]: " choice
    case "${choice}" in
      1)
        check_status
        ;;
      2)
        toggle_app
        ;;
      3)
        if prompt_yes_no "Ban muon cau hinh lai (y) hay go bo (n) Cloudflare Tunnel?" "y"; then
          reconfigure_domain
        else
          remove_tunnel
        fi
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
