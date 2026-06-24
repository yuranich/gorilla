#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./config.sh
source "${SCRIPT_DIR}/config.sh"

python_bin="$(choose_python)"
printf 'Using Python: %s (%s)\n' "${python_bin}" "$("${python_bin}" --version)"

if [[ ! -d "${VENV_DIR}" ]]; then
  "${python_bin}" -m venv "${VENV_DIR}"
fi

# shellcheck source=/dev/null
source "${VENV_DIR}/bin/activate"
python -m pip install --upgrade pip setuptools wheel
python -m pip install -e "${BFCL_DIR}"
# qwen-agent imports soundfile at module import time but does not declare it.
python -m pip install soundfile

if ! command -v npm >/dev/null 2>&1; then
  die "npm is required to install @qvac/cli"
fi

if ! command -v qvac >/dev/null 2>&1; then
  npm install -g @qvac/cli
else
  printf 'qvac already installed: %s\n' "$(command -v qvac)"
fi

printf '\nInstalled BFCL dependencies in %s\n' "${VENV_DIR}"
printf 'Run: bash %s/00-check-env.sh\n' "${SCRIPT_DIR}"
