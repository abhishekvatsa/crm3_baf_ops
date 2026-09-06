#!/usr/bin/env python3
"""Compare generated Isar schema declarations across a Git boundary."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCHEMA_START = re.compile(r"^const (\w+Schema) = CollectionSchema\($", re.MULTILINE)
VERSION = re.compile(r"version:\s*'[^']+',?")
TRAILING_COMMA = re.compile(r",(?=[)}\]])")


class SchemaIdentityError(RuntimeError):
    """Raised when schema identity cannot be proven continuous."""


def _schema_blocks(text: str) -> dict[str, str]:
    blocks: dict[str, str] = {}
    for match in SCHEMA_START.finditer(text):
        end = text.find("\n);", match.end())
        if end < 0:
            raise SchemaIdentityError(f"Unterminated schema: {match.group(1)}")
        name = match.group(1)
        if name in blocks:
            raise SchemaIdentityError(f"Duplicate schema declaration: {name}")
        blocks[name] = text[match.start() : end + 3]
    return blocks


def _canonical(block: str) -> str:
    value = VERSION.sub("version:<generator-version>,", block)
    value = re.sub(r"\s+", "", value)
    previous = ""
    while value != previous:
        previous = value
        value = TRAILING_COMMA.sub("", value)
    return value


def _git_text(reference: str, relative_path: str) -> str:
    result = subprocess.run(
        ["git", "show", f"{reference}:{relative_path}"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        check=False,
    )
    if result.returncode != 0:
        raise SchemaIdentityError(
            f"Cannot read {relative_path} from {reference}: {result.stderr.strip()}"
        )
    return result.stdout


def _git_generated_files(reference: str) -> set[str]:
    result = subprocess.run(
        ["git", "ls-tree", "-r", "--name-only", reference, "--", "lib"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        check=False,
    )
    if result.returncode != 0:
        raise SchemaIdentityError(
            f"Cannot list generated files from {reference}: {result.stderr.strip()}"
        )
    return {
        line.strip()
        for line in result.stdout.splitlines()
        if line.strip().endswith(".g.dart")
    }


def _add_blocks(
    destination: dict[str, tuple[str, str]],
    relative_path: str,
    text: str,
) -> None:
    for name, block in _schema_blocks(text).items():
        if name in destination:
            raise SchemaIdentityError(
                f"Duplicate schema declaration across files: "
                f"{name} ({destination[name][0]}, {relative_path})"
            )
        destination[name] = (relative_path, _canonical(block))


def compare(reference: str) -> tuple[int, int]:
    current_files = {
        path.relative_to(ROOT).as_posix()
        for path in ROOT.joinpath("lib").rglob("*.g.dart")
    }
    baseline_files = _git_generated_files(reference)
    current: dict[str, tuple[str, str]] = {}
    baseline: dict[str, tuple[str, str]] = {}

    for relative in sorted(current_files | baseline_files):
        if relative in current_files:
            _add_blocks(
                current,
                relative,
                ROOT.joinpath(relative).read_text(encoding="utf-8"),
            )
        if relative in baseline_files:
            _add_blocks(baseline, relative, _git_text(reference, relative))

    if not current:
        raise SchemaIdentityError("No generated Isar schemas were found")
    if set(current) != set(baseline):
        raise SchemaIdentityError(
            "Schema set changed; "
            f"added={sorted(set(current) - set(baseline))}; "
            f"removed={sorted(set(baseline) - set(current))}"
        )

    changed = [
        name for name in sorted(current) if current[name][1] != baseline[name][1]
    ]
    if changed:
        detail = ", ".join(
            f"{name} ({baseline[name][0]} -> {current[name][0]})"
            for name in changed
        )
        raise SchemaIdentityError(f"Generated schema identity changed: {detail}")
    return len(current_files), len(current)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline-ref", default="origin/main")
    args = parser.parse_args()
    try:
        file_count, schema_count = compare(args.baseline_ref)
        print(
            "PASS_ISAR_GENERATED_SCHEMA_IDENTITY_CONTINUITY: "
            f"baseline={args.baseline_ref} files={file_count} schemas={schema_count}"
        )
        return 0
    except (OSError, SchemaIdentityError) as exc:
        print(f"FAIL_ISAR_GENERATED_SCHEMA_IDENTITY_CONTINUITY: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
