#!/usr/bin/env python3

from __future__ import annotations

import os
import shutil
import sys
from pathlib import Path


def find_qvac_root() -> Path:
    override = os.getenv("QVAC_CLI_ROOT")
    if override:
        root = Path(override).expanduser().resolve()
        if (root / "package.json").is_file():
            return root
        raise SystemExit(f"QVAC_CLI_ROOT does not look like @qvac/cli root: {root}")

    qvac = shutil.which("qvac")
    if not qvac:
        raise SystemExit("qvac command not found")

    resolved = Path(qvac).resolve()
    for candidate in (resolved.parent, *resolved.parents):
        if (candidate / "package.json").is_file() and candidate.name == "cli":
            return candidate

    raise SystemExit(f"could not locate @qvac/cli root from {resolved}")


def patch_file(path: Path, replacements: list[tuple[str, str]]) -> bool:
    text = path.read_text(encoding="utf-8")
    original = text

    for needle, replacement in replacements:
        if replacement in text:
            continue
        if needle not in text:
            raise SystemExit(f"patch anchor not found in {path}: {needle!r}")
        text = text.replace(needle, replacement, 1)

    if text == original:
        return False

    path.write_text(text, encoding="utf-8")
    return True


def main() -> None:
    root = find_qvac_root()
    sdk_root = root / "node_modules" / "@qvac" / "sdk" / "dist" / "schemas"
    llm_root = root / "node_modules" / "@qvac" / "llm-llamacpp"

    patched = []

    if patch_file(
        sdk_root / "llamacpp-config.js",
        [
            (
                "    top_p: z.number().min(0).max(1).optional(),\n"
                "    top_k: z.number().int().min(0).max(128).optional(),",
                "    top_p: z.number().min(0).max(1).optional(),\n"
                "    min_p: z.number().min(0).max(1).optional(),\n"
                "    top_k: z.number().int().min(0).max(128).optional(),",
            )
        ],
    ):
        patched.append("llamacpp-config.js")

    if patch_file(
        sdk_root / "llamacpp-config.d.ts",
        [
            (
                "    top_p: z.ZodOptional<z.ZodNumber>;\n"
                "    top_k: z.ZodOptional<z.ZodNumber>;",
                "    top_p: z.ZodOptional<z.ZodNumber>;\n"
                "    min_p: z.ZodOptional<z.ZodNumber>;\n"
                "    top_k: z.ZodOptional<z.ZodNumber>;",
            )
        ],
    ):
        patched.append("llamacpp-config.d.ts")

    if patch_file(
        llm_root / "index.d.ts",
        [
            (
                "  top_p?: NumericLike\n"
                "  top_k?: NumericLike",
                "  top_p?: NumericLike\n"
                "  min_p?: NumericLike\n"
                "  top_k?: NumericLike",
            )
        ],
    ):
        patched.append("@qvac/llm-llamacpp/index.d.ts")

    if patched:
        print(f"Patched QVAC min_p support in {root}: {', '.join(patched)}")
    else:
        print(f"QVAC min_p support already patched in {root}")


if __name__ == "__main__":
    main()
