#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
CFL_SERVICE_NAME="${CFL_SERVICE_NAME:-gifcodecfl}"
CFL_INSTALL_ROOT="${CFL_INSTALL_ROOT:-${HOME}/gifcodecfl}"
CFL_ETC_DIR="${CFL_ETC_DIR:-${PREFIX}/etc/gifcodecfl}"
CFL_ENV_FILE="${CFL_ENV_FILE:-${CFL_ETC_DIR}/.env}"
CFL_PROFILE_FILE="${CFL_PROFILE_FILE:-${CFL_ETC_DIR}/profile.sh}"
CFL_BIN_LINK="${CFL_BIN_LINK:-${PREFIX}/bin/cfl-termux}"
CFL_INSTALL_SCRIPT="${CFL_INSTALL_SCRIPT:-${PREFIX}/bin/cfl-install.sh}"
CFL_MENU_SCRIPT="${CFL_MENU_SCRIPT:-${PREFIX}/bin/cfl-termux-menu.sh}"
CFL_PID_FILE="${CFL_PID_FILE:-${CFL_ETC_DIR}/server.pid}"
CFL_LOG_FILE="${CFL_LOG_FILE:-${CFL_INSTALL_ROOT}/gifcodecfl.log}"
CFL_REPO_URL="${CFL_REPO_URL:-https://github.com/nguyenan362/gifcodecfl.git}"
CFL_REPO_BRANCH="${CFL_REPO_BRANCH:-main}"
CFL_WAKE_LOCK_STATE="${CFL_WAKE_LOCK_STATE:-${CFL_ETC_DIR}/wakelock.state}"
CFL_CLOUDFLARED_DIR="${CFL_CLOUDFLARED_DIR:-${PREFIX}/etc/cloudflared}"
CFL_CLOUDFLARED_CONFIG="${CFL_CLOUDFLARED_CONFIG:-${CFL_CLOUDFLARED_DIR}/config.yml}"
CFL_TUNNEL_NAME="${CFL_TUNNEL_NAME:-gifcodecfl}"
CFL_TUNNEL_STATE_FILE="${CFL_TUNNEL_STATE_FILE:-${CFL_ETC_DIR}/cloudflare.env}"
CFL_TUNNEL_PID_FILE="${CFL_TUNNEL_PID_FILE:-${CFL_ETC_DIR}/cloudflared.pid}"
CFL_TUNNEL_LOG_FILE="${CFL_TUNNEL_LOG_FILE:-${CFL_INSTALL_ROOT}/cloudflared.log}"

log() { printf '[cfl] %s\n' "$*"; }
warn() { printf '[cfl] warning: %s\n' "$*" >&2; }
fail() { printf '[cfl] error: %s\n' "$*" >&2; exit 1; }

require_termux() {
  [[ "$(uname -s)" == Linux ]] || fail 'script chi chay tren Termux/Linux'
  [[ "${PREFIX}" == */com.termux/* ]] || fail "khong phat hien Termux (PREFIX=${PREFIX})"
  command -v pkg >/dev/null 2>&1 || fail "khong tim thay lenh pkg"
}
ensure_binary() { command -v "$1" >/dev/null 2>&1 || fail "thieu lenh $1"; }
ensure_pkg_cmd() { command -v "$1" >/dev/null 2>&1 || { log "cai dat $1"; pkg install -y "$1"; }; }
ensure_dir() { mkdir -p "$1"; }

prompt_yes_no() {
  local message="$1" default="${2:-y}" answer suffix='[Y/n]'
  [[ "$default" == n ]] && suffix='[y/N]'
  while read -r -p "$message $suffix: " answer; do
    answer="${answer:-$default}"
    case "$answer" in y|Y|yes|YES) return 0;; n|N|no|NO) return 1;; esac
    warn 'chi nhap y hoac n'
  done
  return 1
}
prompt_default() {
  local message="$1" default="${2:-}" answer
  read -r -p "$message${default:+ [$default]}: " answer
  printf '%s' "${answer:-$default}"
}
read_env_value() { [[ -f "$1" ]] || return 1; awk -F= -v key="$2" '$1 == key {sub(/^[^=]*=/,"",$0); print; exit}' "$1"; }
normalize_port() { local value="${1#http://}"; value="${value#https://}"; value="${value##*:}"; printf '%s' "$value"; }
get_listen_port() { local p; p="$(read_env_value "$CFL_ENV_FILE" PORT 2>/dev/null || printf ':8386')"; p="$(normalize_port "${p:-:8386}")"; printf '%s' "${p:+:$p}"; }

write_profile_file() {
  ensure_dir "$(dirname "$CFL_PROFILE_FILE")"
  cat > "$CFL_PROFILE_FILE" <<EOF
export CFL_SERVICE_NAME="$CFL_SERVICE_NAME"
export CFL_INSTALL_ROOT="$CFL_INSTALL_ROOT"
export CFL_ETC_DIR="$CFL_ETC_DIR"
export CFL_ENV_FILE="$CFL_ENV_FILE"
export CFL_PROFILE_FILE="$CFL_PROFILE_FILE"
export CFL_BIN_LINK="$CFL_BIN_LINK"
export CFL_INSTALL_SCRIPT="$CFL_INSTALL_SCRIPT"
export CFL_MENU_SCRIPT="$CFL_MENU_SCRIPT"
export CFL_PID_FILE="$CFL_PID_FILE"
export CFL_LOG_FILE="$CFL_LOG_FILE"
export CFL_REPO_URL="$CFL_REPO_URL"
export CFL_REPO_BRANCH="$CFL_REPO_BRANCH"
export CFL_WAKE_LOCK_STATE="$CFL_WAKE_LOCK_STATE"
export CFL_CLOUDFLARED_DIR="$CFL_CLOUDFLARED_DIR"
export CFL_CLOUDFLARED_CONFIG="$CFL_CLOUDFLARED_CONFIG"
export CFL_TUNNEL_NAME="$CFL_TUNNEL_NAME"
export CFL_TUNNEL_STATE_FILE="$CFL_TUNNEL_STATE_FILE"
export CFL_TUNNEL_PID_FILE="$CFL_TUNNEL_PID_FILE"
export CFL_TUNNEL_LOG_FILE="$CFL_TUNNEL_LOG_FILE"
EOF
}
load_profile_file() {
  if [[ -f "$CFL_PROFILE_FILE" ]]; then
    . "$CFL_PROFILE_FILE"
  fi
}
ensure_profile_vars() { [[ -f "$CFL_PROFILE_FILE" ]] || write_profile_file; }
ensure_default_env_file() {
  ensure_dir "$CFL_ETC_DIR"
  [[ -f "$CFL_ENV_FILE" ]] || printf 'REDEEM_CLIENT_REGION=VN\nPORT=:8386\n' > "$CFL_ENV_FILE"
}
configure_env_interactive() {
  ensure_default_env_file
  local region port
  region="$(prompt_default 'Nhap REDEEM_CLIENT_REGION' "$(read_env_value "$CFL_ENV_FILE" REDEEM_CLIENT_REGION 2>/dev/null || printf VN)")"
  port="$(prompt_default 'Nhap PORT' "$(read_env_value "$CFL_ENV_FILE" PORT 2>/dev/null || printf :8386)")"
  port="$(normalize_port "$port")"; [[ "$port" == :* ]] || port=":$port"
  printf 'REDEEM_CLIENT_REGION=%s\nPORT=%s\n' "$region" "$port" > "$CFL_ENV_FILE"
}

pid_running() { [[ -s "$CFL_PID_FILE" ]] && kill -0 "$(cat "$CFL_PID_FILE")" 2>/dev/null; }
start_app() {
  pid_running && { log 'app dang chay'; return; }
  ensure_default_env_file; ensure_dir "$CFL_INSTALL_ROOT"
  [[ -x "$CFL_INSTALL_ROOT/server" ]] || fail "chua co binary: $CFL_INSTALL_ROOT/server"
  ( set -a; . "$CFL_ENV_FILE"; set +a; cd "$CFL_INSTALL_ROOT"; nohup "$CFL_INSTALL_ROOT/server" >> "$CFL_LOG_FILE" 2>&1 & printf '%s' "$!" > "$CFL_PID_FILE" )
  sleep 1; pid_running || fail "app khong khoi dong; xem log $CFL_LOG_FILE"
  log "app da chay (PID $(cat "$CFL_PID_FILE"))"
}
stop_app() { if pid_running; then kill "$(cat "$CFL_PID_FILE")" 2>/dev/null || true; fi; rm -f "$CFL_PID_FILE"; log 'app da dung'; }
service_enabled() { [[ -x "$CFL_INSTALL_ROOT/server" ]]; }
service_active() { pid_running; }
show_service_status() { service_active && printf 'running (PID %s)\n' "$(cat "$CFL_PID_FILE")" || printf 'stopped\n'; }

cmd_wake_lock() { require_termux; command -v termux-wake-lock >/dev/null 2>&1 || fail 'can cai Termux:API de dung termux-wake-lock'; termux-wake-lock; ensure_dir "$CFL_ETC_DIR"; date '+%Y-%m-%dT%H:%M:%S%z' > "$CFL_WAKE_LOCK_STATE"; log 'wake-lock da bat'; }
cmd_wake_unlock() { require_termux; command -v termux-wake-unlock >/dev/null 2>&1 && termux-wake-unlock || true; rm -f "$CFL_WAKE_LOCK_STATE"; log 'wake-lock da tat'; }
is_wake_locked() { [[ -f "$CFL_WAKE_LOCK_STATE" ]]; }
get_local_ip() { command -v ip >/dev/null 2>&1 && ip -4 addr show 2>/dev/null | awk '/inet / && $2 !~ /^127\./ {sub(/\/.*/,"",$2); print $2; exit}'; }

cloudflared_bin() { command -v cloudflared || true; }
install_cloudflared() {
  log 'cai cap nhat cloudflared tu kho Termux'
  pkg install -y cloudflared
  command -v cloudflared >/dev/null 2>&1 || fail 'khong cai duoc cloudflared tu kho Termux'
}
tunnel_running() { [[ -s "$CFL_TUNNEL_PID_FILE" ]] && kill -0 "$(cat "$CFL_TUNNEL_PID_FILE")" 2>/dev/null; }
start_tunnel() {
  [[ -f "$CFL_CLOUDFLARED_CONFIG" ]] || fail 'chua cau hinh Cloudflare Tunnel'
  tunnel_running && { log 'Cloudflare Tunnel dang chay'; return; }
  local bin; bin="$(cloudflared_bin)"
  [[ -n "$bin" ]] || { install_cloudflared; bin="$(cloudflared_bin)"; }
  nohup "$bin" tunnel --config "$CFL_CLOUDFLARED_CONFIG" --no-autoupdate run >> "$CFL_TUNNEL_LOG_FILE" 2>&1 &
  printf '%s' "$!" > "$CFL_TUNNEL_PID_FILE"
  sleep 1; tunnel_running || fail "Tunnel khong khoi dong; xem log $CFL_TUNNEL_LOG_FILE"
  log "Cloudflare Tunnel da chay (PID $(cat "$CFL_TUNNEL_PID_FILE"))"
}
stop_tunnel() { if tunnel_running; then kill "$(cat "$CFL_TUNNEL_PID_FILE")" 2>/dev/null || true; fi; rm -f "$CFL_TUNNEL_PID_FILE"; log 'Cloudflare Tunnel da dung'; }
current_domain() { read_env_value "$CFL_TUNNEL_STATE_FILE" CFL_DOMAIN 2>/dev/null || true; }
configure_cloudflare_tunnel() {
  local bin domain tunnel_id port
  install_cloudflared; bin="$(cloudflared_bin)"
  log 'Cloudflared se hien URL dang nhap. Mo URL tren browser, xac thuc Cloudflare, roi quay lai Termux.'
  "$bin" tunnel login
  domain="$(prompt_default 'Nhap domain expose (vd: cfl.example.com)' "$(current_domain)")"
  [[ -n "$domain" ]] || fail 'domain khong duoc de trong'
  if ! "$bin" tunnel info "$CFL_TUNNEL_NAME" >/dev/null 2>&1; then
    log "tao tunnel $CFL_TUNNEL_NAME"
    "$bin" tunnel create "$CFL_TUNNEL_NAME"
  fi
  tunnel_id="$("$bin" tunnel info "$CFL_TUNNEL_NAME" 2>/dev/null | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -n 1 || true)"
  [[ -n "$tunnel_id" ]] || fail "khong lay duoc ID tunnel $CFL_TUNNEL_NAME"
  "$bin" tunnel route dns "$CFL_TUNNEL_NAME" "$domain"
  ensure_dir "$CFL_CLOUDFLARED_DIR"
  port="$(get_listen_port)"
  cat > "$CFL_CLOUDFLARED_CONFIG" <<EOF
tunnel: $tunnel_id
credentials-file: ${HOME}/.cloudflared/${tunnel_id}.json
ingress:
  - hostname: $domain
    service: http://127.0.0.1${port}
  - service: http_status:404
EOF
  printf 'CFL_DOMAIN=%s\nCFL_TUNNEL_ID=%s\n' "$domain" "$tunnel_id" > "$CFL_TUNNEL_STATE_FILE"
  log "Tunnel da cau hinh cho https://$domain"
  start_tunnel
}
remove_cloudflare_tunnel() {
  local bin; stop_tunnel
  if [[ -f "$CFL_TUNNEL_STATE_FILE" ]] && [[ -n "$(cloudflared_bin)" ]]; then
    bin="$(cloudflared_bin)"
    "$bin" tunnel delete "$CFL_TUNNEL_NAME" || warn 'khong xoa duoc tunnel tren Cloudflare'
  fi
  rm -f "$CFL_CLOUDFLARED_CONFIG" "$CFL_TUNNEL_STATE_FILE"
  log 'da go cau hinh Cloudflare Tunnel'
}
