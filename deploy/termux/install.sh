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
  ln -sfn "$CFL_MENU_SCRIPT" "$PREFIX/bin/cfl"
}
interactive_install() {
  require_termux
  for dep in git curl ca-certificates awk grep sed; do ensure_pkg_cmd "$dep"; done
  ensure_profile_vars; load_profile_file; ensure_default_env_file
  prompt_yes_no 'Cau hinh file .env ngay bay gio?' y && configure_env_interactive || true
  build_app; start_app
  prompt_yes_no 'Cau hinh Cloudflare Tunnel?' n && configure_cloudflare_tunnel || true
  cat <<EOF

Cai dat xong.
- Menu: $CFL_BIN_LINK
- Menu: $PREFIX/bin/cfl
- URL: http://localhost$(get_listen_port)
- Log: $CFL_LOG_FILE
EOF
  exec "$CFL_MENU_SCRIPT"
}
cmd_update() { require_termux; [[ -d "$CFL_INSTALL_ROOT/.git" ]] || fail 'khong phat hien git repo'; (cd "$CFL_INSTALL_ROOT" && git pull --ff-only); build_app; stop_app; start_app; }
cmd_uninstall() { require_termux; stop_app; stop_tunnel; rm -f "$CFL_BIN_LINK" "$PREFIX/bin/cfl" "$CFL_INSTALL_SCRIPT" "$CFL_MENU_SCRIPT" "$PREFIX/bin/cfl-termux-lib.sh"; rm -rf "$CFL_INSTALL_ROOT"; log 'da go bo app'; }
show_help() { printf '%s\n' 'Dung: cfl-install.sh [--update|--enable-service|--disable-service|--configure-tunnel|--remove-tunnel|--wake-lock|--wake-unlock|--uninstall|help]'; }
case "${1:-}" in
  '') interactive_install;; --update) cmd_update;; --enable-service) require_termux; start_app;; --disable-service) require_termux; stop_app;; --configure-tunnel) require_termux; configure_cloudflare_tunnel;; --remove-tunnel) require_termux; remove_cloudflare_tunnel;; --wake-lock) cmd_wake_lock;; --wake-unlock) cmd_wake_unlock;; --uninstall) cmd_uninstall;; help|-h|--help) show_help;; *) fail "tham so khong hop le: $1";;
esac
