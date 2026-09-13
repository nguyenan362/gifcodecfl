#!/usr/bin/env bash
# deploy/termux/install.sh
# Cai dat va quan ly gifcodecfl tren Termux (Android).
# Co the chay truc tiep trong repo hoac duoc goi tu termux-bootstrap.sh.
#
# Hai che do quan ly process:
#  1) service  (mac dinh) - dung termux-services (runit):
#     - tu start khi mo Termux, tu restart khi crash
#     - quan ly bang `sv up/down/restart/status`
#  2) nohup    (fallback) - chay nen bang nohup, PID file
#     - khong co auto-start/auto-restart
#     - chi dung neu user go enable khong duoc
set -euo pipefail

APP_NAME="gifcodecfl"
GO_MIN_VERSION="1.22"
APP_REPO_DEFAULT="https://github.com/nguyenan362/gifcodecfl.git"
APP_REPO_BRANCH_DEFAULT="main"
SERVICE_NAME="gifcodecfl"
BASHRC_MARKER="gifcodecfl-runsvdir"

# --- Resolve duong dan -------------------------------------------------------
SCRIPT_SRC="${BASH_SOURCE[0]:-$0}"
if command -v readlink >/dev/null 2>&1; then
  SCRIPT_SRC="$(readlink -f "${SCRIPT_SRC}" 2>/dev/null || printf '%s' "${SCRIPT_SRC}")"
fi
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_SRC}")" && pwd)"
APP_HOME_DEFAULT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

APP_HOME="${CFL_APP_HOME:-${APP_HOME_DEFAULT}}"
APP_REPO="${CFL_REPO_URL:-${APP_REPO_DEFAULT}}"
APP_REPO_BRANCH="${CFL_REPO_BRANCH:-${APP_REPO_BRANCH_DEFAULT}}"
APP_BIN="${APP_HOME}/server"
APP_PID_FILE="${APP_HOME}/${APP_NAME}.pid"
APP_LOG_FILE="${APP_HOME}/${APP_NAME}.log"
APP_ENV_FILE="${APP_HOME}/.env"
SERVICE_DIR="${PREFIX:-/data/data/com.termux/files/usr}/etc/sv/${SERVICE_NAME}"
SERVICE_ACTIVE_DIR="${PREFIX:-/data/data/com.termux/files/usr}/etc/service/${SERVICE_NAME}"

# --- Mau mau -----------------------------------------------------------------
if [[ -t 1 ]]; then
  RST=$'\033[0m'; GRN=$'\033[1;32m'; YLW=$'\033[1;33m'; RED=$'\033[1;31m'; CYN=$'\033[1;36m'
else
  RST=""; GRN=""; YLW=""; RED=""; CYN=""
fi

log()  { printf "%s[cfl]%s %s\n" "${CYN}" "${RST}" "$*"; }
warn() { printf "%s[cfl]%s %s\n" "${YLW}" "${RST}" "$*"; }
err()  { printf "%s[cfl]%s %s\n" "${RED}" "${RST}" "$*" >&2; }
ok()   { printf "%s[cfl]%s %s\n" "${GRN}" "${RST}" "$*"; }
die()  { err "$*"; exit 1; }

# --- Kiem tra moi truong -----------------------------------------------------
require_termux() {
  if [[ -z "${PREFIX:-}" || "${PREFIX}" != */com.termux/* ]]; then
    die "script nay chi danh cho Termux (Android). Hay chay trong app Termux."
  fi
  if ! command -v pkg >/dev/null 2>&1; then
    die "khong tim thay 'pkg'. Hay cai Termux chinh hang tu F-Droid."
  fi
}

ensure_pkg_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "cai dat $1"
    pkg install -y "$1"
  fi
}

ensure_git()  { ensure_pkg_cmd git;  }
ensure_curl() { ensure_pkg_cmd curl; }

ensure_go() {
  if command -v go >/dev/null 2>&1; then
    local current
    current="$(go version | awk '{print $3}' | sed 's/^go//')"
    if printf '%s\n%s\n' "${GO_MIN_VERSION}" "${current}" | sort -V -C; then
      ok "Go ${current} (>= ${GO_MIN_VERSION})"
      return
    fi
    warn "Go ${current} cu hon ${GO_MIN_VERSION}, se nang cap"
  fi
  log "cai dat golang"
  pkg install -y golang
}

ensure_termux_services() {
  if ! command -v runsvdir >/dev/null 2>&1; then
    log "cai dat termux-services (cho runit supervision)"
    pkg install -y termux-services
  fi
  if ! command -v sv >/dev/null 2>&1; then
    die "sau khi cai termux-services, lenh 'sv' van khong co. Kiem tra PATH."
  fi
}

# --- Service (runit) helpers -------------------------------------------------
is_service_enabled() {
  [[ -e "${SERVICE_ACTIVE_DIR}" ]]
}

is_service_installed() {
  [[ -x "${SERVICE_DIR}/run" ]]
}

service_status_text() {
  sv status "${SERVICE_NAME}" 2>/dev/null || true
}

write_service_run() {
  ensure_termux_services
  ensure_dir "$(dirname "${SERVICE_DIR}")"
  log "ghi runit service: ${SERVICE_DIR}/run"
  cat > "${SERVICE_DIR}/run" <<EOF
#!/data/data/com.termux/files/usr/bin/sh
# gifcodecfl - runit service (auto-restart khi crash)
exec 2>&1
APP_HOME="${APP_HOME}"
APP_ENV_FILE="${APP_ENV_FILE}"
APP_BIN="${APP_BIN}"
APP_LOG="${APP_LOG_FILE}"
cd "\${APP_HOME}" || exit 1
if [ -f "\${APP_ENV_FILE}" ]; then
  set -a
  . "\${APP_ENV_FILE}"
  set +a
fi
exec "\${APP_BIN}" >>"\${APP_LOG}" 2>&1
EOF
  chmod +x "${SERVICE_DIR}/run"
}

ensure_bashrc_runsvdir() {
  local bashrc="${HOME}/.bashrc"
  touch "${bashrc}"
  if grep -qF "${BASHRC_MARKER}" "${bashrc}" 2>/dev/null; then
    return 0
  fi
  log "them runsvdir hook vao ${bashrc}"
  cat >> "${bashrc}" <<EOF

# ${BASHRC_MARKER}: bat runit supervision moi khi mo Termux
if [ -z "\${RUNSVDIR:-}" ] && [ -x "\$PREFIX/bin/runsvdir" ]; then
  export RUNSVDIR="\$PREFIX/var/service"
  export SVDIR="\$PREFIX/etc/sv"
  runsvdir "\${SVDIR}" >/dev/null 2>&1 &
  disown
fi
EOF
}

start_runsvdir_now() {
  if ! pgrep -f "runsvdir .*\$PREFIX/etc/sv" >/dev/null 2>&1; then
    log "khoi dong runsvdir cho session hien tai"
    (
      export RUNSVDIR="${PREFIX}/var/service"
      export SVDIR="${PREFIX}/etc/sv"
      nohup runsvdir "${PREFIX}/etc/sv" >/dev/null 2>&1 &
      disown || true
    )
  fi
}

install_service() {
  write_service_run
  ensure_bashrc_runsvdir
  start_runsvdir_now

  if ! is_service_enabled; then
    log "enable service (sv-enable ${SERVICE_NAME})"
    if command -v sv-enable >/dev/null 2>&1; then
      sv-enable "${SERVICE_NAME}"
    else
      ensure_dir "$(dirname "${SERVICE_ACTIVE_DIR}")"
      ln -sf "../sv/${SERVICE_NAME}" "${SERVICE_ACTIVE_DIR}"
    fi
  else
    log "service da duoc enable san"
  fi
  ok "service da san sang (runit se start khi mo Termux)"
}

uninstall_service() {
  if is_service_enabled; then
    log "stop + disable service"
    sv down "${SERVICE_NAME}" 2>/dev/null || true
    if command -v sv-disable >/dev/null 2>&1; then
      sv-disable "${SERVICE_NAME}" 2>/dev/null || rm -f "${SERVICE_ACTIVE_DIR}"
    else
      rm -f "${SERVICE_ACTIVE_DIR}"
    fi
  fi
  if [[ -d "${SERVICE_DIR}" ]]; then
    log "xoa runit service dir ${SERVICE_DIR}"
    rm -rf "${SERVICE_DIR}"
  fi
}

# --- Wake lock helpers -------------------------------------------------------
wake_lock_supported() {
  command -v termux-wake-lock >/dev/null 2>&1
}

cmd_wake_lock() {
  if ! wake_lock_supported; then
    err "khong co 'termux-wake-lock'. Cai Termux:API tu F-Droid:"
    err "  https://f-droid.org/packages/com.termux.api/"
    return 1
  fi
  log "bat wake-lock (chan Android suspend Termux)"
  if termux-wake-lock; then
    ok "wake-lock da bat (se ton tai cho den khi unlock)"
  else
    err "wake-lock that bai (co the Termux:API chua duoc grant quyen)"
    return 1
  fi
}

cmd_wake_unlock() {
  if ! command -v termux-wake-unlock >/dev/null 2>&1; then
    warn "khong co 'termux-wake-unlock' (Termux:API chua duoc cai?)"
    return 0
  fi
  log "tat wake-lock"
  termux-wake-unlock
  ok "wake-lock da tat"
}

# --- Repo / source -----------------------------------------------------------
ensure_repo() {
  if [[ ! -d "${APP_HOME}" ]]; then
    log "tao thu muc ${APP_HOME}"
    mkdir -p "${APP_HOME}"
  fi

  if [[ -d "${APP_HOME}/.git" ]]; then
    return
  fi

  log "clone repo ${APP_REPO} (branch ${APP_REPO_BRANCH}) -> ${APP_HOME}"
  rm -rf "${APP_HOME}"
  git clone --depth 1 -b "${APP_REPO_BRANCH}" "${APP_REPO}" "${APP_HOME}"
}

update_repo() {
  if [[ ! -d "${APP_HOME}/.git" ]]; then
    die "khong phat hien git repo tai ${APP_HOME}. Hay clone truoc."
  fi
  log "cap nhat repo"
  (cd "${APP_HOME}" && git fetch --depth 1 origin "${APP_REPO_BRANCH}" && git reset --hard "origin/${APP_REPO_BRANCH}")
}

ensure_env_file() {
  if [[ ! -f "${APP_ENV_FILE}" ]]; then
    log "tao .env mac dinh"
    cat > "${APP_ENV_FILE}" <<EOF
REDEEM_CLIENT_REGION=VN
PORT=:8386
EOF
  fi
}

# --- Build -------------------------------------------------------------------
build_app() {
  log "build binary (go build)"
  (
    cd "${APP_HOME}"
    CGO_ENABLED=0 go build -buildvcs=false -o "${APP_BIN}" .
  )
  ok "build xong: ${APP_BIN}"
}

# --- Process / network helpers -----------------------------------------------
ensure_dir() {
  mkdir -p "$1"
}

is_running() {
  if is_service_enabled; then
    service_status_text | grep -q "^run:"
    return $?
  fi
  [[ -f "${APP_PID_FILE}" ]] || return 1
  local pid
  pid="$(cat "${APP_PID_FILE}" 2>/dev/null || true)"
  [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null
}

read_port() {
  local port=":8386"
  if [[ -f "${APP_ENV_FILE}" ]]; then
    port="$(awk -F= '/^[[:space:]]*PORT[[:space:]]*=/{print $2; exit}' "${APP_ENV_FILE}" | tr -d ' \r')"
  fi
  printf '%s' "${port:-:8386}"
}

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

print_access_info() {
  local port ip
  port="$(read_port)"
  ip="$(get_local_ip)"
  log "truy cap tren may:        http://localhost${port}"
  if [[ -n "${ip}" ]]; then
    log "truy cap tu thiet bi khac: http://${ip}${port}"
  fi
  log "log: ${APP_LOG_FILE}"
}

start_app() {
  if is_service_enabled; then
    if is_running; then
      warn "service dang chay"
      status_app
      return 0
    fi
    log "sv up ${SERVICE_NAME}"
    sv up "${SERVICE_NAME}" 2>/dev/null || true
    sleep 1
    if is_running; then
      ok "service da khoi dong (runit se tu restart neu crash)"
      status_app
    else
      err "service khong len. Log: ${APP_LOG_FILE}"
      tail -n 30 "${APP_LOG_FILE}" 2>/dev/null || true
      return 1
    fi
    return 0
  fi

  # Fallback: nohup
  if is_running; then
    warn "app dang chay (pid $(cat "${APP_PID_FILE}"))"
    status_app
    return 0
  fi
  if [[ ! -x "${APP_BIN}" ]]; then
    build_app
  fi
  log "khoi dong app (nohup)"
  : > "${APP_LOG_FILE}"

  (
    cd "${APP_HOME}"
    set -a
    # shellcheck disable=SC1090
    source "${APP_ENV_FILE}"
    set +a
    nohup "${APP_BIN}" >>"${APP_LOG_FILE}" 2>&1 < /dev/null &
    disown || true
    echo "$!" > "${APP_PID_FILE}"
  )

  sleep 1
  if is_running; then
    status_app
  else
    err "app khoi dong that bai, log:"
    tail -n 30 "${APP_LOG_FILE}" || true
    return 1
  fi
}

stop_app() {
  if is_service_enabled; then
    if is_running; then
      log "sv down ${SERVICE_NAME}"
      sv down "${SERVICE_NAME}" 2>/dev/null || true
      for _ in 1 2 3 4 5; do
        is_running || break
        sleep 1
      done
    fi
    if is_running; then
      err "service van chay (kiem tra log)"
      return 1
    fi
    ok "service da dung"
    return 0
  fi

  if ! is_running; then
    warn "app chua chay"
    return 0
  fi
  local pid
  pid="$(cat "${APP_PID_FILE}")"
  log "dung app (pid ${pid})"
  kill "${pid}" 2>/dev/null || true
  for _ in 1 2 3 4 5 6 7 8; do
    kill -0 "${pid}" 2>/dev/null || break
    sleep 1
  done
  if kill -0 "${pid}" 2>/dev/null; then
    warn "app khong phan hoi, force kill"
    kill -9 "${pid}" 2>/dev/null || true
  fi
  rm -f "${APP_PID_FILE}"
  ok "da dung app"
}

status_app() {
  if is_service_enabled; then
    if is_running; then
      ok "service dang chay (runit)"
      log "trang thai chi tiet:"
      sed 's/^/   /' <<<"$(service_status_text)"
    else
      warn "service dang tat (runit se start no khi runsvdir hoat dong)"
    fi
    print_access_info
    if wake_lock_supported; then
      log "(de song khi tat man hinh: ~/gifcodecfl/deploy/termux/install.sh wake-lock)"
    else
      warn "(Termux:API chua cai -> app co the bi Android suspend khi tat man hinh)"
    fi
    return 0
  fi

  if is_running; then
    local pid
    pid="$(cat "${APP_PID_FILE}")"
    ok "app dang chay (pid ${pid}, che do nohup - khong auto-restart)"
  else
    warn "app chua chay"
    return 1
  fi
  print_access_info
}

restart_app() {
  if is_service_enabled; then
    log "sv restart ${SERVICE_NAME}"
    sv restart "${SERVICE_NAME}" 2>/dev/null || sv down "${SERVICE_NAME}" 2>/dev/null || true
    sleep 1
    if ! is_running; then
      sv up "${SERVICE_NAME}" 2>/dev/null || true
      sleep 1
    fi
    status_app || true
    return 0
  fi
  stop_app || true
  start_app
}

tail_log() {
  if [[ ! -f "${APP_LOG_FILE}" ]]; then
    warn "log chua ton tai (app chua chay lan nao)"
    return
  fi
  log "xem log (Ctrl+C de thoat)"
  tail -n 50 -f "${APP_LOG_FILE}"
}

update_app() {
  update_repo
  ensure_env_file
  build_app
  if is_service_enabled; then
    log "restart service de nap binary moi"
    sv restart "${SERVICE_NAME}" 2>/dev/null || true
    sleep 1
    status_app
  elif is_running; then
    restart_app
  else
    start_app
  fi
}

cmd_enable() {
  require_termux
  install_service
  sv up "${SERVICE_NAME}" 2>/dev/null || true
  sleep 1
  status_app
}

cmd_disable() {
  require_termux
  # Stop app first (in both modes) so the port is freed
  stop_app || true
  uninstall_service
  ok "da disable autostart. Lan sau start se chay bang nohup."
  status_app || true
}

uninstall_app() {
  stop_app || true
  uninstall_service || true
  log "xoa thu muc app: ${APP_HOME}"
  rm -rf "${APP_HOME}"
  ok "da go bo"
}

# --- Full install ------------------------------------------------------------
full_install() {
  require_termux
  ensure_curl
  ensure_git
  ensure_go
  ensure_repo
  ensure_env_file
  build_app

  if ! is_service_enabled; then
    log "khoi tao runit service (che do persistence)"
    install_service
  fi

  # Dam bao app dang chay (service hoac fallback)
  if ! is_running; then
    start_app
  else
    status_app
  fi

  cat <<EOF

Hoan tat cai dat tren Termux.
  Thu muc app:    ${APP_HOME}
  Binary:         ${APP_BIN}
  Env:            ${APP_ENV_FILE}
  Log:            ${APP_LOG_FILE}
  PID:            ${APP_PID_FILE}
  Service (runit): ${SERVICE_DIR}
  Bashrc hook:    ~\/.bashrc (${BASHRC_MARKER})

Persistence:
  - Service se TU START moi khi ban mo Termux.
  - Neu app crash, runit TU RESTART (mac dinh sau 1s).
  - De app song khi TAT MAN HINH:
EOF

  if wake_lock_supported; then
    cat <<EOF
    bang lenh:
      ~/gifcodecfl/deploy/termux/install.sh wake-lock
EOF
  else
    cat <<EOF
    can cai them Termux:API tu F-Droid:
      https://f-droid.org/packages/com.termux.api/
    sau do chay:
      ~/gifcodecfl/deploy/termux/install.sh wake-lock
EOF
  fi

  cat <<EOF

Cac lenh quan ly:
  ${APP_HOME}/deploy/termux/install.sh status    # trang thai
  ${APP_HOME}/deploy/termux/install.sh start     # khoi dong
  ${APP_HOME}/deploy/termux/install.sh stop      # dung
  ${APP_HOME}/deploy/termux/install.sh restart   # khoi dong lai
  ${APP_HOME}/deploy/termux/install.sh log       # xem log
  ${APP_HOME}/deploy/termux/install.sh update    # git pull + rebuild + restart
  ${APP_HOME}/deploy/termux/install.sh menu      # menu tuong tac
  ${APP_HOME}/deploy/termux/install.sh wake-lock # chong Android suspend
  ${APP_HOME}/deploy/termux/install.sh disable   # tat autostart (quay lai nohup)
  ${APP_HOME}/deploy/termux/install.sh uninstall # go bo hoan toan
EOF
}

# --- Menu --------------------------------------------------------------------
show_menu() {
  while true; do
    printf '\n'
    cat <<EOF
========== GIFCODECFL (TERMUX) ==========
 1) Trang thai
 2) Khoi dong
 3) Dung
 4) Khoi dong lai
 5) Cap nhat ma nguon (git pull + rebuild)
 6) Xem log
 7) Wake lock (chong Android suspend)
 8) Enable/Disable autostart (runit)
 9) Thoat
EOF
    local choice
    read -r -p "Chon chuc nang [1-9]: " choice
    case "${choice}" in
      1) status_app ;;
      2) start_app ;;
      3) stop_app ;;
      4) restart_app ;;
      5) update_app ;;
      6) tail_log ;;
      7)
        if wake_lock_supported; then
          if termux-wake-lock; then
            ok "wake-lock da bat"
          else
            warn "wake-lock that bai"
          fi
        else
          warn "khong co termux-wake-lock (cai Termux:API tu F-Droid)"
        fi
        ;;
      8)
        if is_service_enabled; then
          cmd_disable
        else
          cmd_enable
        fi
        ;;
      9) exit 0 ;;
      *) warn "lua chon khong hop le" ;;
    esac
  done
}

# --- Help --------------------------------------------------------------------
show_help() {
  cat <<EOF
gifcodecfl Termux installer

Su dung: $0 [lenh]

Lenh:
  (mac dinh)   Cai dat, build va khoi dong app (kem runit service)
  start        Khoi dong app (sv up neu service, nohup neu fallback)
  stop         Dung app
  restart      Khoi dong lai
  status       Xem trang thai + dia chi truy cap
  log          Xem log (tail -f)
  update       Git pull + rebuild + restart
  menu         Menu quan ly tuong tac
  enable       Bat runit service (auto-start + auto-restart)
  disable      Tat runit service, quay lai che do nohup
  wake-lock    Bat termux-wake-lock (can Termux:API tu F-Droid)
  wake-unlock  Tat termux-wake-lock
  uninstall    Dung app, go service, xoa thu muc app
  help         Hien thi tro giup nay

Bien moi truong (optional):
  CFL_REPO_URL       URL git (mac dinh: ${APP_REPO_DEFAULT})
  CFL_REPO_BRANCH    Branch (mac dinh: ${APP_REPO_BRANCH_DEFAULT})
  CFL_APP_HOME       Thu muc app (mac dinh: ${APP_HOME_DEFAULT})

File quan trong:
  Ma nguon:      ${APP_HOME}
  Binary:        ${APP_BIN}
  Env:           ${APP_ENV_FILE}
  Log:           ${APP_LOG_FILE}
  PID (fallback): ${APP_PID_FILE}
  Service dir:   ${SERVICE_DIR}
  Service active: ${SERVICE_ACTIVE_DIR}
EOF
}

# --- Entry point -------------------------------------------------------------
case "${1:-}" in
  "")            full_install ;;
  start)         require_termux; start_app ;;
  stop)          require_termux; stop_app ;;
  restart)       require_termux; restart_app ;;
  status)        require_termux; status_app ;;
  log)           require_termux; tail_log ;;
  update)        require_termux; update_app ;;
  menu)          require_termux; show_menu ;;
  enable)        cmd_enable ;;
  disable)       cmd_disable ;;
  wake-lock)     require_termux; cmd_wake_lock ;;
  wake-unlock)   require_termux; cmd_wake_unlock ;;
  uninstall)     require_termux; uninstall_app ;;
  help|-h|--help) show_help ;;
  *)             err "lenh khong hop le: $1"; show_help; exit 1 ;;
esac
