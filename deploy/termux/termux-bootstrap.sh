#!/usr/bin/env bash
# deploy/termux/termux-bootstrap.sh
# Entry point nhe de pipe tu curl:
#   curl -fsSL https://raw.githubusercontent.com/AN/gifcodecfl/main/deploy/termux/termux-bootstrap.sh | bash
# Script nay chi dam bao Termux + curl + git co san, clone repo roi ban giao
# cho install.sh de thuc hien build/start.
set -euo pipefail

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

# --- Detect Termux -----------------------------------------------------------
if [[ -z "${PREFIX:-}" || "${PREFIX}" != */com.termux/* ]]; then
  err "script nay chi danh cho Termux tren Android."
  err "Hay cai Termux tu F-Droid va chay lai trong app Termux."
  exit 1
fi

if ! command -v pkg >/dev/null 2>&1; then
  err "khong tim thay 'pkg'. Hay su dung Termux chinh hang."
  exit 1
fi

# --- Bien --------------------------------------------------------------------
APP_HOME="${CFL_APP_HOME:-${HOME}/gifcodecfl}"
APP_REPO="${CFL_REPO_URL:-https://github.com/AN/gifcodecfl.git}"
APP_REPO_BRANCH="${CFL_REPO_BRANCH:-main}"

# --- Cap nhat repo list va goi can thiet -------------------------------------
log "cap nhat danh sach goi (pkg update)..."
pkg update -y >/dev/null

for dep in curl git ca-certificates; do
  if ! command -v "${dep}" >/dev/null 2>&1; then
    log "cai dat ${dep}"
    pkg install -y "${dep}"
  fi
done

# --- Clone hoac update repo --------------------------------------------------
if [[ -d "${APP_HOME}/.git" ]]; then
  log "phat hien repo cu tai ${APP_HOME}, giu nguyen"
else
  if [[ -e "${APP_HOME}" ]]; then
    warn "duong dan ${APP_HOME} ton tai nhung khong phai git repo, xoa va clone moi"
    rm -rf "${APP_HOME}"
  fi
  log "clone ${APP_REPO} (branch ${APP_REPO_BRANCH}) -> ${APP_HOME}"
  git clone --depth 1 -b "${APP_REPO_BRANCH}" "${APP_REPO}" "${APP_HOME}"
fi

# --- Ban giao cho install.sh -------------------------------------------------
INSTALLER="${APP_HOME}/deploy/termux/install.sh"
if [[ ! -f "${INSTALLER}" ]]; then
  err "khong tim thay installer tai ${INSTALLER}"
  exit 1
fi

ok "ban giao cho installer (${INSTALLER})"
exec bash "${INSTALLER}" "$@"
