#!/usr/bin/env python3
"""Stage the exact locked Windows Isar core for hermetic Flutter tests.

The script trusts only the package selected by Dart's generated
`.dart_tool/package_config.json`, verifies that `pubspec.lock` pins the expected
`isar_flutter_libs` version and archive SHA-256, selects exactly one AMD64
`isar.dll` from that package, copies it into the disposable laboratory
workspace, and writes a custody record for the evidence bundle.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import struct
import sys
from pathlib import Path
from typing import Any
from urllib.parse import unquote, urlparse
from urllib.request import url2pathname

PACKAGE_NAME = "isar_flutter_libs"
DLL_NAME = "isar.dll"
PE_MACHINE_AMD64 = 0x8664


class CustodyError(RuntimeError):
    """Raised when the governed native-core custody cannot be proven."""


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def _locked_package(text: str, package_name: str) -> dict[str, str]:
    lines = text.splitlines()
    start = None
    marker = f"  {package_name}:"
    for index, line in enumerate(lines):
        if line == marker:
            start = index + 1
            break
    if start is None:
        raise CustodyError(f"pubspec.lock has no {package_name} entry")

    body: list[str] = []
    for line in lines[start:]:
        if line.startswith("  ") and not line.startswith("    ") and line.endswith(":"):
            break
        body.append(line)

    values: dict[str, str] = {}
    for line in body:
        stripped = line.strip()
        if stripped.startswith("sha256:"):
            values["sha256"] = stripped.split(":", 1)[1].strip().strip('"')
        elif stripped.startswith("version:"):
            values["version"] = stripped.split(":", 1)[1].strip().strip('"')
    if "version" not in values or "sha256" not in values:
        raise CustodyError(f"Incomplete {package_name} lock entry")
    return values


def _package_root(project_root: Path) -> Path:
    config_path = project_root / ".dart_tool" / "package_config.json"
    if not config_path.is_file():
        raise CustodyError(
            ".dart_tool/package_config.json is missing; run flutter pub get first"
        )
    try:
        config = json.loads(config_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise CustodyError(f"Cannot read package_config.json: {exc}") from exc

    matches = [
        row
        for row in config.get("packages", [])
        if isinstance(row, dict) and row.get("name") == PACKAGE_NAME
    ]
    if len(matches) != 1:
        raise CustodyError(
            f"Expected one {PACKAGE_NAME} package-config entry; found {len(matches)}"
        )

    raw_uri = str(matches[0].get("rootUri", "")).strip()
    if not raw_uri:
        raise CustodyError(f"{PACKAGE_NAME} rootUri is empty")

    parsed = urlparse(raw_uri)
    if parsed.scheme:
        if parsed.scheme.lower() != "file":
            raise CustodyError(
                f"{PACKAGE_NAME} rootUri is not a local file URI: {raw_uri}"
            )
        uri_path = url2pathname(unquote(parsed.path))
        if parsed.netloc:
            uri_path = f"//{parsed.netloc}{uri_path}"
        package_root = Path(uri_path)
    else:
        package_root = config_path.parent / unquote(raw_uri)

    package_root = package_root.resolve()
    if not package_root.is_dir():
        raise CustodyError(f"Resolved package root does not exist: {package_root}")
    return package_root


def _package_pubspec_identity(package_root: Path) -> dict[str, str]:
    pubspec = package_root / "pubspec.yaml"
    if not pubspec.is_file():
        raise CustodyError(f"Resolved package has no pubspec.yaml: {package_root}")

    values: dict[str, str] = {}
    for raw_line in pubspec.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or ":" not in line:
            continue
        key, value = line.split(":", 1)
        key = key.strip()
        if key in {"name", "version"} and key not in values:
            values[key] = value.strip().strip("\"'")
    if values.get("name") != PACKAGE_NAME or not values.get("version"):
        raise CustodyError(
            "Resolved package pubspec identity is invalid: "
            f"name={values.get('name')!r}; version={values.get('version')!r}"
        )
    return values


def _pe_machine(path: Path) -> int:
    with path.open("rb") as handle:
        if handle.read(2) != b"MZ":
            raise CustodyError(f"Not a PE DLL (missing MZ header): {path.name}")
        handle.seek(0x3C)
        offset_bytes = handle.read(4)
        if len(offset_bytes) != 4:
            raise CustodyError(f"Truncated DOS header: {path.name}")
        pe_offset = struct.unpack("<I", offset_bytes)[0]
        handle.seek(pe_offset)
        if handle.read(4) != b"PE\x00\x00":
            raise CustodyError(f"Invalid PE signature: {path.name}")
        machine_bytes = handle.read(2)
        if len(machine_bytes) != 2:
            raise CustodyError(f"Truncated PE file header: {path.name}")
        return struct.unpack("<H", machine_bytes)[0]


def _select_amd64_dll(package_root: Path) -> tuple[Path, int]:
    candidates = sorted(
        path for path in package_root.rglob("*") if path.is_file() and path.name.lower() == DLL_NAME
    )
    amd64: list[tuple[Path, int]] = []
    rejected: list[str] = []
    for candidate in candidates:
        try:
            machine = _pe_machine(candidate)
        except CustodyError as exc:
            rejected.append(f"{candidate.relative_to(package_root)}: {exc}")
            continue
        if machine == PE_MACHINE_AMD64:
            amd64.append((candidate, machine))
        else:
            rejected.append(
                f"{candidate.relative_to(package_root)}: machine=0x{machine:04X}"
            )

    if len(amd64) != 1:
        details = "; ".join(rejected) if rejected else "no isar.dll candidates"
        raise CustodyError(
            "Expected exactly one AMD64 isar.dll in the locked package; "
            f"found {len(amd64)}. {details}"
        )
    return amd64[0]


def stage_core(
    *,
    project_root: Path,
    output: Path,
    evidence: Path,
    expected_version: str,
    expected_archive_sha256: str,
) -> dict[str, Any]:
    project_root = project_root.resolve()
    lock_path = project_root / "pubspec.lock"
    if not lock_path.is_file():
        raise CustodyError(f"Missing pubspec.lock: {lock_path}")

    locked = _locked_package(lock_path.read_text(encoding="utf-8"), PACKAGE_NAME)
    actual_archive_sha = locked["sha256"].upper()
    expected_archive_sha = expected_archive_sha256.upper()
    if locked["version"] != expected_version:
        raise CustodyError(
            f"{PACKAGE_NAME} version mismatch: expected {expected_version}; "
            f"got {locked['version']}"
        )
    if actual_archive_sha != expected_archive_sha:
        raise CustodyError(
            f"{PACKAGE_NAME} archive SHA-256 mismatch: expected "
            f"{expected_archive_sha}; got {actual_archive_sha}"
        )

    package_root = _package_root(project_root)
    package_identity = _package_pubspec_identity(package_root)
    if package_identity["version"] != expected_version:
        raise CustodyError(
            f"Resolved {PACKAGE_NAME} package version mismatch: expected "
            f"{expected_version}; got {package_identity['version']}"
        )
    source, machine = _select_amd64_dll(package_root)
    source_sha = _sha256(source)

    output = output.resolve()
    evidence = evidence.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    evidence.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, output)
    staged_sha = _sha256(output)
    if staged_sha != source_sha:
        raise CustodyError(
            f"Staged Isar core hash mismatch: source={source_sha}; staged={staged_sha}"
        )

    record: dict[str, Any] = {
        "schemaVersion": 1,
        "package": PACKAGE_NAME,
        "packageVersion": locked["version"],
        "resolvedPackageVersion": package_identity["version"],
        "packageArchiveSha256": actual_archive_sha,
        "sourceRelativePath": source.relative_to(package_root).as_posix(),
        "peMachine": f"0x{machine:04X}",
        "architecture": "windows-amd64",
        "dllSha256": source_sha,
        "bytes": source.stat().st_size,
        "stagedRelativePath": output.relative_to(project_root).as_posix(),
        "networkDownloadPermittedDuringFlutterTests": False,
    }
    evidence.write_text(
        json.dumps(record, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    return record


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--evidence", required=True, type=Path)
    parser.add_argument("--expected-version", required=True)
    parser.add_argument("--expected-archive-sha256", required=True)
    return parser


def main() -> int:
    args = _parser().parse_args()
    try:
        record = stage_core(
            project_root=args.project_root,
            output=args.output,
            evidence=args.evidence,
            expected_version=args.expected_version,
            expected_archive_sha256=args.expected_archive_sha256,
        )
    except CustodyError as exc:
        print(f"FAIL_GOVERNED_ISAR_CORE_CUSTODY: {exc}", file=sys.stderr)
        return 1

    print(
        "PASS_GOVERNED_ISAR_CORE_CUSTODY: "
        f"version={record['packageVersion']} "
        f"dllSha256={record['dllSha256']} "
        f"bytes={record['bytes']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
