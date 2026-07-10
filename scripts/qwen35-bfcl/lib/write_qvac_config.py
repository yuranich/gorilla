#!/usr/bin/env python3

from __future__ import annotations

import json
import os
from pathlib import Path


def env_bool(name: str, default: bool = False) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.lower() in {"1", "true", "yes", "y"}


def maybe_number(value: str | None) -> int | float | None:
    if value is None or value == "":
        return None
    if "." in value:
        return float(value)
    return int(value)


def main() -> None:
    alias = os.environ["MODEL_ALIAS"]
    source = os.environ["HF_REPO"]
    model_constant = os.getenv("MODEL_CONSTANT", "")
    output = Path(os.environ["QVAC_CONFIG_PATH"])
    model_field = os.getenv("QVAC_MODEL_FIELD", "src")
    enable_thinking = env_bool("ENABLE_THINKING")

    model_config: dict[str, object] = {
        "ctx_size": int(os.getenv("QVAC_CONTEXT_SIZE", "32768")),
        "tools": True,
        "temp": float(os.environ["TEMPERATURE"]),
        "top_p": float(os.environ["TOP_P"]),
        "top_k": int(os.environ["TOP_K"]),
        "presence_penalty": float(os.environ["PRESENCE_PENALTY"]),
        "reasoning_budget": -1 if enable_thinking else 0,
    }

    repeat_penalty = maybe_number(os.getenv("REPEAT_PENALTY"))
    if repeat_penalty is not None:
        model_config["repeat_penalty"] = repeat_penalty

    min_p = maybe_number(os.getenv("MIN_P"))
    if min_p is not None:
        model_config["min_p"] = min_p

    frequency_penalty = maybe_number(os.getenv("FREQUENCY_PENALTY"))
    if frequency_penalty is not None:
        model_config["frequency_penalty"] = frequency_penalty

    entry: dict[str, object] = {
        "default": True,
        "preload": env_bool("QVAC_PRELOAD"),
        "config": model_config,
        "type": "llamacpp-completion",
    }
    if model_constant:
        entry["model"] = model_constant
    else:
        entry[model_field] = source

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps({"serve": {"models": {alias: entry}}}, indent=2) + "\n",
        encoding="utf-8",
    )
    print(output)


if __name__ == "__main__":
    main()
