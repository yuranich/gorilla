#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./config.sh
source "${SCRIPT_DIR}/config.sh"

status() {
  local name="$1"
  local command="$2"
  if eval "${command}" >/dev/null 2>&1; then
    printf 'ok      %s\n' "${name}"
  else
    printf 'missing %s\n' "${name}"
  fi
}

printf 'repo: %s\n' "${REPO_ROOT}"
printf 'bfcl: %s\n' "${BFCL_DIR}"
printf 'os: %s\n' "$(describe_os)"
printf '\n'

status "git" "command -v git"
status "curl" "command -v curl"
status "jq" "command -v jq"
status "node" "command -v node"
status "npm" "command -v npm"
status "qvac" "command -v qvac"
status "uv" "command -v uv"
status "python3.12" "command -v python3.12"
status "python3.11" "command -v python3.11"
status "python3.10" "command -v python3.10"

python_bin="$(choose_python)"
printf '\nselected_python: %s (%s)\n' "${python_bin}" "$("${python_bin}" --version)"

if [[ ! -d "${BFCL_DIR}" ]]; then
  die "BFCL directory not found: ${BFCL_DIR}"
fi

if [[ -f "${VENV_DIR}/bin/activate" ]]; then
  printf 'ok      BFCL virtualenv: %s\n' "${VENV_DIR}"
else
  printf 'missing BFCL virtualenv: %s\n' "${VENV_DIR}"
fi

printf '\nnotes:\n'
if ! command -v qvac >/dev/null 2>&1; then
  printf '%s\n' '- install @qvac/cli with 01-install-user-deps.sh before serving models'
fi
case "$("${python_bin}" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')" in
  3.10|3.11|3.12) ;;
  *)
    printf '%s\n' "- Python $("${python_bin}" --version) is newer than BFCL was documented against; prefer python3.12/3.11/3.10"
    ;;
esac
printf '%s\n' '- QVAC will download model weights on the first serve request for each GGUF source'
