#!/usr/bin/env bash
# deploy/termux/cfl-termux-menu.sh
# Menu tuong tac quan ly gifcodecfl tren Termux.
# Mirror cfl-menu.sh cua Linux, bo sung wake-lock (tinh nang rieng Termux).
set -euo pipefail

SCRIPT_SRC="${BASH_SOURCE[0]:-$0}"
if command -v readlink >/dev/null 2>&1; then
  SCRIPT_SRC="$(readlink -f "${SCRIPT_SRC}" 2>/dev/null || printf '%s' "${SCRIPT_SRC}")"
fi
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_SRC}")" && pwd)"

# Neu menu duoc copy ra $PREFIX/bin thi source lib o do, nguoc lai lay trong repo
if [[ -f "${SCRIPT_DIR}/cfl-termux-lib.sh" ]]; then
  # shellcheck disable=SC1091
  . "${SCRIPT_DIR}/cfl-termux-lib.sh"
elif [[ -f "${PREFIX:-/data/data/com.termux/files/usr}/bin/cfl-termux-lib.sh" ]]; then
  # shellcheck disable=SC1091
  . "${PREFIX}/bin/cfl-termux-lib.sh"
else
  echo "[cfl] error: khong tim thay cfl-termux-lib.sh" >&2
  exit 1
fi

load_profile_file

get_local_ip() {
  if command -v ip >/dev/null 2>&1; then
    ip -4 addr show 2>/dev/null \
      | awk '/inet /{print $2}' \
      | cut -d/ -f1 \
      | grep -v '^127\.' \
      | head -1
    return
  fi
  if command -v ifconfig >/dev/null 2>&1; then
    ifconfig 2>/dev/null \
      | awk '/inet /{print $2}' \
      | grep -v '^127\.' \
      | head -1
  fi
}

check_status() {
  require_termux
  log "trang thai app"
  show_service_status "${CFL_SERVICE_NAME}"

  local port ip
  port="$(get_listen_port)"
  ip="$(get_local_ip)"
  log "truy cap tren may:        http://localhost${port}"
  if [[ -n "${ip}" ]]; then
    log "truy cap tu thiet bi khac: http://${ip}${port}"
  fi

  if is_wake_locked; then
    ok "wake-lock dang bat"
  elif wake_lock_supported; then
    warn "wake-lock chua bat (tat man hinh co the suspend app)"
  else
    warn "Termux:API chua cai -> khong the bat wake-lock"
  fi

  if [[ -f "${CFL_DOMAIN_FILE}" ]]; then
    log "domain Cloudflare hien tai: $(current_domain)"
    show_service_status "${CFL_TUNNEL_SERVICE_NAME}"
  fi
}

toggle_app() {
  require_termux
  if service_enabled "${CFL_SERVICE_NAME}" && service_active "${CFL_SERVICE_NAME}"; then
    log "app dang bat, tien hanh tat"
    sv down "${CFL_SERVICE_NAME}" >/dev/null 2>&1 || true
    disable_runit_service "${CFL_SERVICE_NAME}"
    log "app da duoc tat"
  else
    log "app dang tat, tien hanh bat"
    install_app_service
    sv up "${CFL_SERVICE_NAME}" >/dev/null 2>&1 || true
    log "app da duoc bat"
  fi
}

reconfigure_domain() {
  require_termux
  "${CFL_INSTALL_SCRIPT}" --configure-domain
}

remove_tunnel() {
  require_termux
  if ! prompt_yes_no "Ban chac chan muon go bo Cloudflare Tunnel?" "n"; then
    log "huy bo go Cloudflare Tunnel"
    return
  fi
  "${CFL_INSTALL_SCRIPT}" --remove-tunnel
}

toggle_wake_lock() {
  require_termux
  if ! wake_lock_supported; then
    warn "khong co 'termux-wake-lock'. Cai Termux:API tu F-Droid:"
    warn "  https://f-droid.org/packages/com.termux.api/"
    return
  fi
  if is_wake_locked; then
    cmd_wake_unlock
  else
    cmd_wake_lock
  fi
}

show_menu() {
  while true; do
    cat <<EOF

========== CFL TERMUX MENU ==========
 1. Kiem tra trang thai hoat dong cua app
 2. Bat/Tat chay app
 3. Cau hinh lai hoac go bo Cloudflare Tunnel
 4. Bat/Tat wake-lock (chong Android suspend)
 5. Thoat
EOF

    read -r -p "Chon chuc nang [1-5]: " choice
    case "${choice}" in
      1) check_status ;;
      2) toggle_app ;;
      3)
        if prompt_yes_no "Ban muon cau hinh lai (y) hay go bo (n) Cloudflare Tunnel?" "y"; then
          reconfigure_domain
        else
          remove_tunnel
        fi
        ;;
      4) toggle_wake_lock ;;
      5) exit 0 ;;
      *) warn "lua chon khong hop le" ;;
    esac
  done
}

show_menu
