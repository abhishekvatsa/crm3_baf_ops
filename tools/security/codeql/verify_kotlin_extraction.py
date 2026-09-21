#!/usr/bin/env python3
"""Verify the real MainActivityBodies.ql CSV before publishing extraction proof.

This validates decoded query evidence; it does not run CodeQL or substitute for
the workflow's traced build, database finalization, and query execution.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import sys


SOURCE_PATH = "android/app/src/main/kotlin/in/co/sail/bsl/crm3/bafops/MainActivity.kt"
CLASS_NAME = "in.co.sail.bsl.crm3.bafops.MainActivity"
EXPECTED_METHODS = (
    "configureFlutterEngine",
    "configureCriticalAlarmChannel",
    "configureNetworkAccessChannel",
    "showCriticalAlarmNotification",
)
CSV_COLUMNS = (
    "source_path",
    "class_name",
    "method_name",
    "body_start_line",
    "body_end_line",
)
MAX_CSV_BYTES = 64 * 1024
MAX_SOURCE_BYTES = 1024 * 1024
COMMIT_PATTERN = re.compile(r"[0-9a-f]{40}")
VERSION_PATTERN = re.compile(r"(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)")
LINE_PATTERN = re.compile(r"[1-9][0-9]{0,6}")


class ProofError(ValueError):
    """The supplied extraction evidence is not sufficient for a proof."""


def _sha256(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _read_bounded(path: Path, limit: int, label: str) -> bytes:
    with path.open("rb") as handle:
        value = handle.read(limit + 1)
    if not value or len(value) > limit:
        raise ProofError(f"{label} must be nonempty and at most {limit} bytes")
    return value


def _source_text(value: bytes) -> str:
    try:
        text = value.decode("utf-8")
    except UnicodeDecodeError as error:
        raise ProofError("Kotlin source must be valid UTF-8") from error
    if "\x00" in text:
        raise ProofError("Kotlin source contains a NUL character")
    # Git may check out CRLF on Windows. Other content must match the commit.
    return text.replace("\r\n", "\n")


def verify_rows(csv_bytes: bytes, source_line_count: int) -> list[dict[str, object]]:
    """Require one source-body row for each fixed method, with no extra rows."""
    if not csv_bytes or len(csv_bytes) > MAX_CSV_BYTES:
        raise ProofError("Query CSV is empty or exceeds the size limit")
    try:
        csv_text = csv_bytes.decode("utf-8")
    except UnicodeDecodeError as error:
        raise ProofError("Query CSV must be valid UTF-8") from error
    if "\x00" in csv_text:
        raise ProofError("Query CSV contains a NUL character")
    try:
        rows = list(csv.reader(io.StringIO(csv_text, newline=""), strict=True))
    except csv.Error as error:
        raise ProofError("Query CSV is malformed") from error
    if not rows or tuple(rows[0]) != CSV_COLUMNS:
        raise ProofError("Query CSV has an unexpected header")
    methods: dict[str, dict[str, object]] = {}
    for row in rows[1:]:
        if len(row) != len(CSV_COLUMNS):
            raise ProofError("Query CSV has a malformed row")
        source_path, class_name, method_name, start_text, end_text = row
        if source_path != SOURCE_PATH or class_name != CLASS_NAME:
            raise ProofError("Query row does not identify the exact MainActivity source and class")
        if method_name not in EXPECTED_METHODS:
            raise ProofError("Query row identifies an unexpected method")
        if method_name in methods:
            raise ProofError(f"Query CSV repeats method {method_name}")
        if not LINE_PATTERN.fullmatch(start_text) or not LINE_PATTERN.fullmatch(end_text):
            raise ProofError("Method body line numbers must be positive decimal integers")
        start_line, end_line = int(start_text), int(end_text)
        if not 1 <= start_line <= end_line <= source_line_count:
            raise ProofError("Method body line range is outside the checked-out source")
        methods[method_name] = {
            "methodName": method_name,
            "bodyStartLine": start_line,
            "bodyEndLine": end_line,
        }
    missing = set(EXPECTED_METHODS) - methods.keys()
    if missing:
        raise ProofError("Query CSV is missing method bodies: " + ", ".join(sorted(missing)))
    return [methods[name] for name in EXPECTED_METHODS]


def _git(repository_root: Path, *arguments: str) -> bytes:
    try:
        result = subprocess.run(
            ["git", "-C", str(repository_root), *arguments],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=20,
        )
    except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
        raise ProofError("Unable to verify the checked-out Git commit and source") from error
    return result.stdout


def build_proof(
    *, csv_path: Path, diagnostics_path: Path, repository_root: Path, commit: str, codeql_version: str
) -> dict[str, object]:
    if not COMMIT_PATTERN.fullmatch(commit) or commit == "0" * 40:
        raise ProofError("Commit must be a nonzero, lowercase, full 40-character Git SHA")
    if not VERSION_PATTERN.fullmatch(codeql_version):
        raise ProofError("CodeQL version must be a numeric major.minor.patch version")
    repository_root = repository_root.resolve(strict=True)
    actual_root = Path(_git(repository_root, "rev-parse", "--show-toplevel").decode().strip()).resolve()
    if actual_root != repository_root:
        raise ProofError("Repository root must be the actual Git working-tree root")
    actual_commit = _git(repository_root, "rev-parse", "--verify", "HEAD^{commit}").decode().strip()
    if actual_commit != commit:
        raise ProofError("Supplied commit does not match the checked-out HEAD")
    source_path = repository_root / SOURCE_PATH
    if source_path.resolve(strict=True) != source_path:
        raise ProofError("MainActivity source path must not redirect through a symbolic link")
    source_bytes = _read_bounded(source_path, MAX_SOURCE_BYTES, "Kotlin source")
    source_text = _source_text(source_bytes)
    committed_bytes = _git(repository_root, "show", f"{commit}:{SOURCE_PATH}")
    if source_text != _source_text(committed_bytes):
        raise ProofError("Checked-out Kotlin source differs from the supplied commit")
    csv_bytes = _read_bounded(csv_path, MAX_CSV_BYTES, "Query CSV")
    methods = verify_rows(csv_bytes, len(source_text.splitlines()))
    diagnostics_bytes = _read_bounded(diagnostics_path, MAX_SOURCE_BYTES, "Diagnostics CSV")
    try:
        diagnostic_rows = list(csv.reader(io.StringIO(diagnostics_bytes.decode("utf-8"), newline=""), strict=True))
    except (UnicodeDecodeError, csv.Error) as error:
        raise ProofError("Diagnostics CSV is malformed") from error
    if not diagnostic_rows or diagnostic_rows[0] != ["source_path", "severity", "tag", "message", "full_message"]:
        raise ProofError("Diagnostics CSV has an unexpected header")
    if len(diagnostic_rows) != 1:
        raise ProofError("CodeQL reported app extraction errors; inspect diagnostics.csv before claiming coverage")
    return {
        "schemaVersion": 2,
        "status": "verified",
        "commitSha": commit,
        "codeqlVersion": codeql_version,
        "sourcePath": SOURCE_PATH,
        "className": CLASS_NAME,
        "sourceSha256": _sha256(source_bytes),
        "committedSourceSha256": _sha256(committed_bytes),
        "queryCsvSha256": _sha256(csv_bytes),
        "diagnosticsCsvSha256": _sha256(diagnostics_bytes),
        "appExtractionErrorCount": 0,
        "methodBodies": methods,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--csv", required=True, type=Path)
    parser.add_argument("--diagnostics", required=True, type=Path)
    parser.add_argument("--repository-root", required=True, type=Path)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--codeql-version", required=True)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args(argv)
    try:
        proof = build_proof(
            csv_path=args.csv,
            diagnostics_path=args.diagnostics,
            repository_root=args.repository_root,
            commit=args.commit,
            codeql_version=args.codeql_version,
        )
        # Never overwrite an earlier proof, input evidence, or repository source.
        with args.output.open("x", encoding="utf-8", newline="\n") as handle:
            handle.write(json.dumps(proof, indent=2) + "\n")
    except (ProofError, OSError) as error:
        print(f"Kotlin extraction proof refused: {error}", file=sys.stderr)
        return 1
    print(f"Verified extracted MainActivity bodies for all {len(EXPECTED_METHODS)} required methods.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
