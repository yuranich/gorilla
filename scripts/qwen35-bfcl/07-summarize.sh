#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./config.sh
source "${SCRIPT_DIR}/config.sh"
activate_bfcl_venv

export BFCL_DIR BFCL_SCORE_DIR

python - <<'PY'
from __future__ import annotations

import csv
import os
from pathlib import Path

bfcl_dir = Path(os.environ["BFCL_DIR"])
score_dir = bfcl_dir / os.environ.get("BFCL_SCORE_DIR", "score/qvac-qwen35")
overall = score_dir / "data_overall.csv"

print(f"score_dir={score_dir}")
if not overall.exists():
    print(f"missing {overall}")
    raise SystemExit(0)

with overall.open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))

if not rows:
    print("no score rows")
    raise SystemExit(0)

columns = [
    "Model",
    "Overall Acc",
    "Non-Live AST Acc",
    "Non-Live Exec Acc",
    "Live Acc",
    "Multi Turn Acc",
    "Relevance Detection",
    "Irrelevance Detection",
]
columns = [column for column in columns if column in rows[0]]

print("\t".join(columns))
for row in rows:
    if "local-qwen35" not in row.get("Model", ""):
        continue
    print("\t".join(row.get(column, "") for column in columns))
PY
