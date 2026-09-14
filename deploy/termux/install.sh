#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/cfl-termux-lib.sh"
load_profile_file

ensure_repo_source() {
  if [[ ! -f "$CFL_INSTALL_ROOT/go.mod" ]]; then
    [[ ! -e "$CFL_INSTALL_ROOT" ]] || rm -rf "$CFL_INSTALL_ROOT"
    git clone --depth 1 -b "$CFL_REPO_BRANCH" "$CFL_REPO_URL" "$CFL_INSTALL_ROOT"
  fi
}
build_app() {
  ensure_repo_source; ensure_pkg_cmd golang; ensure_dir "$CFL_INSTALL_ROOT"
  (cd "$CFL_INSTALL_ROOT" && CGO_ENABLED=0 go build -trimpath -buildvcs=false -o server .)
  install -Dm755 "$SCRIPT_DIR/cfl-termux-lib.sh" "$PREFIX/bin/cfl-termux-lib.sh"
  install -Dm755 "$SCRIPT_DIR/install.sh" "$CFL_INSTALL_SCRIPT"
  install -Dm755 "$SCRIPT_DIR/cfl-termux-menu.sh" "$CFL_MENU_SCRIPT"
  ln -sfn "$CFL_MENU_SCRIPT" "$CFL_BIN_LINK"
}
interactive_install() {
  require_termux
  for dep in git curl ca-certificates awk grep sed; do ensure_pkg_cmd "$dep"; done
  ensure_profile_vars; load_profile_file; ensure_default_env_file
  prompt_yes_no 'Cau hinh file .env ngay bay gio?' y && configure_env_interactive || true
  build_app; start_app
  cat <<EOF

Cai dat xong.
- Menu: $CFL_BIN_LINK
- URL: http://localhost$(get_listen_port)
- Log: $CFL_LOG_FILE
EOF
}
cmd_update() { require_termux; [[ -d "$CFL_INSTALL_ROOT/.git" ]] || fail 'khong phat hien git repo'; (cd "$CFL_INSTALL_ROOT" && git pull --ff-only); build_app; stop_app; start_app; }
cmd_uninstall() { require_termux; stop_app; rm -f "$CFL_BIN_LINK" "$CFL_INSTALL_SCRIPT" "$CFL_MENU_SCRIPT" "$PREFIX/bin/cfl-termux-lib.sh"; rm -rf "$CFL_INSTALL_ROOT"; log 'da go bo app'; }
show_help() { printf '%s\n' 'Dung: cfl-install.sh [--update|--enable-service|--disable-service|--wake-lock|--wake-unlock|--uninstall|help]'; }
case "${1:-}" in
  '') interactive_install;; --update) cmd_update;; --enable-service) require_termux; start_app;; --disable-service) require_termux; stop_app;; --wake-lock) cmd_wake_lock;; --wake-unlock) cmd_wake_unlock;; --uninstall) cmd_uninstall;; help|-h|--help) show_help;; *) fail "tham so khong hop le: $1";;
esac
