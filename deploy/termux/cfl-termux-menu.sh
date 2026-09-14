#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/cfl-termux-lib.sh"
load_profile_file
while true; do
  printf '\n===== CFL TERMUX =====\n1. Kiem tra trang thai\n2. Bat/Tat app\n3. Xem log\n4. Bat/Tat wake-lock\n5. Thoat\n'
  read -r -p 'Chon [1-5]: ' choice
  case "$choice" in
    1) show_service_status; printf 'URL: http://localhost%s\n' "$(get_listen_port)"; ip="$(get_local_ip)"; [[ -n "$ip" ]] && printf 'LAN: http://%s%s\n' "$ip" "$(get_listen_port)"; is_wake_locked && printf 'wake-lock: on\n' || printf 'wake-lock: off\n';;
    2) service_active && stop_app || start_app;;
    3) [[ -f "$CFL_LOG_FILE" ]] && tail -n 50 "$CFL_LOG_FILE" || warn 'chua co log';;
    4) is_wake_locked && cmd_wake_unlock || cmd_wake_lock;;
    5) exit 0;; *) warn 'lua chon khong hop le';;
  esac
