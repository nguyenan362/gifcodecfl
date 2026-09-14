#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
PREFIX="${PREFIX:-}"
[[ "${PREFIX}" == */com.termux/* ]] || { printf '[cfl] error: hay chay trong Termux\n' >&2; exit 1; }
command -v pkg >/dev/null 2>&1 || { printf '[cfl] error: khong tim thay pkg\n' >&2; exit 1; }
pkg update -y
for dep in bash curl git ca-certificates; do command -v "$dep" >/dev/null 2>&1 || pkg install -y "$dep"; done
APP_HOME="${CFL_APP_HOME:-${HOME}/gifcodecfl}"
if [[ ! -f "$APP_HOME/deploy/termux/install.sh" ]]; then
  [[ ! -e "$APP_HOME" ]] || rm -rf "$APP_HOME"
  git clone --depth 1 -b "${CFL_REPO_BRANCH:-main}" "${CFL_REPO_URL:-https://github.com/nguyenan362/gifcodecfl.git}" "$APP_HOME"
fi
exec bash "$APP_HOME/deploy/termux/install.sh" "$@"
