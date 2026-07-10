#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./config.sh
source "${SCRIPT_DIR}/config.sh"

preset="${1:-08b:think}"
load_preset "${preset}"
ensure_dirs

export HF_REPO MODEL_CONSTANT MODEL_ALIAS TEMPERATURE TOP_P TOP_K MIN_P PRESENCE_PENALTY ENABLE_THINKING
export REPEAT_PENALTY FREQUENCY_PENALTY REASONING_BUDGET
export QVAC_CONFIG_PATH QVAC_CONTEXT_SIZE QVAC_PRELOAD QVAC_MODEL_FIELD

python_bin="$(choose_python)"
"${python_bin}" "${SCRIPT_DIR}/lib/write_qvac_config.py" >/dev/null

env_file="${RUN_DIR}/${PRESET_SAFE}.env"
cat >"${env_file}" <<EOF
PRESET=${PRESET}
MODEL_ALIAS=${MODEL_ALIAS}
HF_REPO=${HF_REPO}
MODEL_CONSTANT=${MODEL_CONSTANT}
TEMPERATURE=${TEMPERATURE}
TOP_P=${TOP_P}
TOP_K=${TOP_K}
MIN_P=${MIN_P}
PRESENCE_PENALTY=${PRESENCE_PENALTY}
REPEAT_PENALTY=${REPEAT_PENALTY}
FREQUENCY_PENALTY=${FREQUENCY_PENALTY}
REASONING_BUDGET=${REASONING_BUDGET}
ENABLE_THINKING=${ENABLE_THINKING}
QVAC_CONFIG_PATH=${QVAC_CONFIG_PATH}
QVAC_BASE_URL=${QVAC_BASE_URL}
EOF

print_preset
printf 'qvac_config=%s\n' "${QVAC_CONFIG_PATH}"
printf 'env_file=%s\n' "${env_file}"
printf '\nNext:\n'
printf '  bash %s/03-serve-model.sh %s\n' "${SCRIPT_DIR}" "${PRESET}"
printf '  bash %s/04-smoke.sh %s\n' "${SCRIPT_DIR}" "${PRESET}"
