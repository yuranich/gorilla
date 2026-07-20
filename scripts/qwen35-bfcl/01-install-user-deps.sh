#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./config.sh
source "${SCRIPT_DIR}/config.sh"

python_bin="$(choose_python)"
printf 'Using Python: %s (%s)\n' "${python_bin}" "$("${python_bin}" --version)"

if [[ -d "${VENV_DIR}" && ! -f "${VENV_DIR}/bin/activate" ]]; then
  [[ -n "${VENV_DIR}" && "${VENV_DIR}" != "/" ]] || die "refusing to remove invalid VENV_DIR: ${VENV_DIR}"
  printf 'Recreating incomplete BFCL virtualenv: %s\n' "${VENV_DIR}"
  rm -rf "${VENV_DIR}"
fi

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
  npm_install_args=(-g)
  npm_prefix="$(npm config get prefix 2>/dev/null || true)"
  if [[ -n "${QVAC_NPM_PREFIX:-}" ]]; then
    npm_prefix="${QVAC_NPM_PREFIX}"
    npm_install_args=(--prefix "${npm_prefix}" -g)
  elif [[ -z "${npm_prefix}" || ! -w "${npm_prefix}" ]]; then
    npm_prefix="${HOME}/.local"
    npm_install_args=(--prefix "${npm_prefix}" -g)
  fi

  if [[ "${npm_install_args[*]}" == --prefix* ]]; then
    mkdir -p "${npm_prefix}/bin"
    export PATH="${npm_prefix}/bin:${PATH}"
    printf 'Installing qvac under user npm prefix: %s\n' "${npm_prefix}"
  fi

  npm install "${npm_install_args[@]}" @qvac/cli
else
  printf 'qvac already installed: %s\n' "$(command -v qvac)"
fi

if ! command -v qvac >/dev/null 2>&1; then
  die "qvac was installed but is not on PATH. Add ${npm_prefix}/bin to PATH and rerun this script."
fi

printf '\nInstalled BFCL dependencies in %s\n' "${VENV_DIR}"
printf 'Run: bash %s/00-check-env.sh\n' "${SCRIPT_DIR}"
