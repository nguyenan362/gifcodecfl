#!/usr/bin/env bash
# deploy/termux/termux-bootstrap.sh
# Entry point nhe de pipe tu curl:
#   curl -fsSL https://raw.githubusercontent.com/nguyenan362/gifcodecfl/main/deploy/termux/termux-bootstrap.sh | bash
# Chi dam bao Termux + curl + git co san, clone repo roi ban giao cho install.sh.
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "[cfl] error: script nay chi danh cho Termux tren Android." >&2
  exit 1
fi

PREFIX="${PREFIX:-}"
if [[ -z "${PREFIX}" || "${PREFIX}" != */com.termux/* ]]; then
  echo "[cfl] error: khong phat hien Termux (PREFIX='${PREFIX}')." >&2
  echo "[cfl]        Hay cai Termux chinh hang tu F-Droid va chay lai." >&2
  exit 1
fi

if ! command -v pkg >/dev/null 2>&1; then
  echo "[cfl] error: khong tim thay 'pkg'. Hay su dung Termux chinh hang." >&2
  exit 1
fi

APP_HOME="${CFL_APP_HOME:-${HOME}/gifcodecfl}"
APP_REPO="${CFL_REPO_URL:-https://github.com/nguyenan362/gifcodecfl.git}"
APP_REPO_BRANCH="${CFL_REPO_BRANCH:-main}"

log() { printf '[cfl] %s\n' "$*"; }

log "cap nhat danh sach goi (pkg update)..."
pkg update -y >/dev/null

for dep in curl git ca-certificates awk grep sed findutils; do
  if ! command -v "${dep}" >/dev/null 2>&1; then
    log "cai dat ${dep}"
    pkg install -y "${dep}"
  fi
done

if [[ -d "${APP_HOME}/.git" ]]; then
  log "phat hien repo cu tai ${APP_HOME}, giu nguyen"
else
  if [[ -e "${APP_HOME}" ]]; then
    log "duong dan ${APP_HOME} ton tai nhung khong phai git repo, xoa va clone moi"
    rm -rf "${APP_HOME}"
  fi
  log "clone ${APP_REPO} (branch ${APP_REPO_BRANCH}) -> ${APP_HOME}"
  git clone --depth 1 -b "${APP_REPO_BRANCH}" "${APP_REPO}" "${APP_HOME}"
fi

INSTALLER="${APP_HOME}/deploy/termux/install.sh"
if [[ ! -f "${INSTALLER}" ]]; then
  echo "[cfl] error: khong tim thay installer tai ${INSTALLER}" >&2
  exit 1
fi

log "ban giao cho installer (${INSTALLER})"
exec bash "${INSTALLER}" "$@"
