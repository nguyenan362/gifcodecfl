#!/usr/bin/env bash
# deploy/termux/install.sh
# Cai dat va quan ly gifcodecfl tren Termux (Android).
# Mirror chuc nang cua deploy/native/install.sh nhung thay systemd = runit.
set -euo pipefail

SCRIPT_SRC="${BASH_SOURCE[0]:-$0}"
if command -v readlink >/dev/null 2>&1; then
  SCRIPT_SRC="$(readlink -f "${SCRIPT_SRC}" 2>/dev/null || printf '%s' "${SCRIPT_SRC}")"
fi
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_SRC}")" && pwd)"

# shellcheck disable=SC1091
. "${SCRIPT_DIR}/cfl-termux-lib.sh"

load_profile_file

ensure_repo_source() {
  if [[ ! -d "${CFL_INSTALL_ROOT}/.git" ]]; then
    log "clone repo ${CFL_REPO_URL} -> ${CFL_INSTALL_ROOT}"
    ensure_dir "$(dirname "${CFL_INSTALL_ROOT}")"
    rm -rf "${CFL_INSTALL_ROOT}"
    git clone --depth 1 -b "${CFL_REPO_BRANCH}" "${CFL_REPO_URL}" "${CFL_INSTALL_ROOT}"
  fi
}

update_repo_source() {
  if [[ ! -d "${CFL_INSTALL_ROOT}/.git" ]]; then
    fail "khong phat hien git repo tai ${CFL_INSTALL_ROOT}. Hay chay install.sh mac dinh de clone truoc."
  fi
  log "cap nhat repo"
  (
    cd "${CFL_INSTALL_ROOT}"
    git fetch --depth 1 origin "${CFL_REPO_BRANCH}"
    git reset --hard "origin/${CFL_REPO_BRANCH}"
  )
}

# Build truc tiep trong CFL_INSTALL_ROOT (git repo). Thu muc web/ duoc embed
# vao binary bang go:embed nen khong can copy rieng.
build_app() {
  ensure_repo_source
  ensure_pkg_cmd golang
  ensure_dir "${CFL_BIN_DIR}"

  if [[ ! -f "${CFL_INSTALL_ROOT}/go.mod" ]]; then
    fail "khong tim thay source Go tai ${CFL_INSTALL_ROOT} (thieu go.mod)."
  fi

  log "build binary Go (web/ duoc embed vao binary)"
  (
    cd "${CFL_INSTALL_ROOT}"
    CGO_ENABLED=0 go build -trimpath -buildvcs=false -o server .
  )

  install -m 0755 "${SCRIPT_DIR}/cfl-termux-lib.sh"   "${CFL_BIN_DIR}/cfl-termux-lib.sh"
  install -m 0755 "${SCRIPT_DIR}/install.sh"          "${CFL_INSTALL_SCRIPT}"
  install -m 0755 "${SCRIPT_DIR}/cfl-termux-menu.sh"  "${CFL_MENU_SCRIPT}"
  ln -sf "${CFL_MENU_SCRIPT}" "${CFL_BIN_LINK}"
  ok "build xong: ${CFL_INSTALL_ROOT}/server"
}

interactive_install() {
  require_termux
  # Check som ban Google Play truoc khi cai dat/clone de tranh nguoi dung cho oan
  warn_if_termux_googleplay
  ensure_binary sed
  ensure_binary cp
  ensure_binary curl
  ensure_binary awk
  ensure_binary grep
  ensure_binary pgrep

  # 1. Kiem tra / cai bo bien moi truong he thong can thiet
  load_profile_file
  ensure_profile_vars
  load_profile_file
  ensure_default_env_file

  # 2. Hoi co muon setup Cloudflare Tunnel khong
  if prompt_yes_no "Ban co muon setup Cloudflare Tunnel de chay voi domain web khong?" "n"; then
    configure_cloudflare_tunnel
  else
    log "bo qua Cloudflare Tunnel"
  fi

  # 3. Hoi cac thiet lap trong env de thiet lap nhanh
  if prompt_yes_no "Ban co muon cau hinh file .env ngay bay gio khong?" "y"; then
    configure_env_interactive
  else
    log "giu nguyen cau hinh hien tai trong ${CFL_ENV_FILE}"
  fi

  # 4. Build app va setup chay native runit service
  build_app
  install_app_service
  sv up "${CFL_SERVICE_NAME}" 2>/dev/null || true
  enable_tunnel_service_if_configured

  # 5. Goi y bat wake-lock
  local wake_locked="chua bat"
  if is_wake_locked; then
    wake_locked="da bat"
  fi
  if wake_lock_supported; then
    if prompt_yes_no "Bat wake-lock de app song khi tat man hinh?" "y"; then
      cmd_wake_lock || true
      wake_locked="da bat"
    fi
  else
    warn "Termux:API chua duoc cai. App van chay nhung co the bi Android suspend khi tat man hinh."
    warn "Cai Termux:API tu F-Droid: https://f-droid.org/packages/com.termux.api/"
    warn "Sau do chay: cfl-termux  (menu) hoac: ${CFL_INSTALL_SCRIPT} --wake-lock"
  fi

  cat <<EOF

Hoan tat cai dat.
- Lenh menu:        ${CFL_BIN_LINK}
- Service app:      ${CFL_SERVICE_NAME}
- File env:         ${CFL_ENV_FILE}
- Log:              ${CFL_INSTALL_ROOT}/gifcodecfl.log
- Wake-lock:        ${wake_locked}
EOF

  if [[ -f "${CFL_DOMAIN_FILE}" ]]; then
    printf '%s\n' "- Domain tunnel: $(current_domain)"
  fi
}

reconfigure_domain_only() {
  require_termux
  load_profile_file
  ensure_profile_vars
  load_profile_file
  configure_cloudflare_tunnel
  enable_tunnel_service_if_configured
}

remove_tunnel_only() {
  require_termux
  load_profile_file
  ensure_profile_vars
  load_profile_file
  remove_cloudflare_tunnel
}

show_help() {
  cat <<EOF
gifcodecfl Termux installer

Su dung: $0 [lenh]

Lenh:
  (mac dinh)         Cai dat tuong tac (mirror native install.sh)
  --configure-domain Cau hinh lai Cloudflare Tunnel
  --remove-tunnel    Xoa Cloudflare Tunnel
  --wake-lock        Bat termux-wake-lock
  --wake-unlock      Tat termux-wake-lock
  --enable-service   Bat runit service cho app (neu truoc do disable)
  --disable-service  Tat runit service cho app
  --update           Git pull + rebuild + restart service
  --uninstall        Dung app, go service, xoa thu muc app
  help               Hien thi tro giup nay

Bien moi truong (optional):
  CFL_REPO_URL       URL git (mac dinh: ${CFL_REPO_URL})
  CFL_REPO_BRANCH    Branch (mac dinh: ${CFL_REPO_BRANCH})
  CFL_APP_HOME       Thu muc app (mac dinh: \${HOME}/gifcodecfl)
EOF
}

cmd_update() {
  require_termux
  update_repo_source
  ensure_default_env_file
  build_app
  if service_enabled "${CFL_SERVICE_NAME}"; then
    sv restart "${CFL_SERVICE_NAME}" 2>/dev/null || true
  fi
  enable_tunnel_service_if_configured
  ok "da cap nhat"
}

cmd_uninstall() {
  require_termux
  sv down "${CFL_SERVICE_NAME}" 2>/dev/null || true
  uninstall_app_service
  uninstall_tunnel_service
  cmd_wake_unlock || true
  log "xoa thu muc app: ${CFL_INSTALL_ROOT}"
  rm -rf "${CFL_INSTALL_ROOT}"
  ok "da go bo"
}

cmd_enable_service() {
  require_termux
  install_app_service
  sv up "${CFL_SERVICE_NAME}" 2>/dev/null || true
  sleep 1
  show_service_status "${CFL_SERVICE_NAME}"
}

cmd_disable_service() {
  require_termux
  sv down "${CFL_SERVICE_NAME}" 2>/dev/null || true
  uninstall_app_service
  cmd_wake_unlock || true
  ok "service da tat. Chay '${CFL_INSTALL_SCRIPT} --enable-service' de bat lai."
}

case "${1:-}" in
  "")                    interactive_install ;;
  --configure-domain)    reconfigure_domain_only ;;
  --remove-tunnel)       remove_tunnel_only ;;
  --wake-lock)           cmd_wake_lock ;;
  --wake-unlock)         cmd_wake_unlock ;;
  --enable-service)      cmd_enable_service ;;
  --disable-service)     cmd_disable_service ;;
  --update)              cmd_update ;;
  --uninstall)           cmd_uninstall ;;
  help|-h|--help)        show_help ;;
  *)                     fail "tham so khong hop le: ${1}" ;;
esac
