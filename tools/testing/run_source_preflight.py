#!/usr/bin/env python3
"""Cheap checked-in-source checks; no installs, devices or release authority."""
from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]


def commands():
    python = sys.executable
    return [
        ("Isar persisted schema and provenance", [python, "tools/isar/verify_v4_isar_schema.py", "--release"]),
        ("Isar verifier rejection contracts", [python, "-m", "unittest", "discover", "-s", "tools/isar", "-p", "test_verify_v4_isar_schema.py"]),
        ("Test evidence taxonomy", [python, "tools/testing/verify_test_evidence_taxonomy.py"]),
        ("Architecture ownership inventory", [python, "tools/v4/a02_architecture_inventory.py"]),
        ("gRPC dependency pin contracts", [python, "-m", "unittest", "discover", "-s", "tools/v4", "-p", "test_grpc_dependency_policy.py"]),
        ("CLI dependency and workflow pin contracts", [python, "-m", "unittest", "discover", "-s", "tools/v4", "-p", "test_basic_ftp_dependency_policy.py"]),
        ("Preflight sequencing and failure contracts", [python, "-m", "unittest", "discover", "-s", "tools/testing", "-p", "test_source_preflight.py"]),
        ("Local gate status reporting contracts", [python, "-m", "unittest", "discover", "-s", "tools/testing", "-p", "test_local_gate_reporting.py"]),
        ("CLI complete lock pin contracts", ["pwsh", "-NoProfile", "-File", "tools/v4/Test-FirebaseCliLabPins.ps1", "-RepositoryRoot", str(ROOT)]),
    ]


def main():
    checks = commands()
    outcomes = [{"name": name, "status": "untested"} for name, _ in checks]
    exit_code = 0
    for index, (name, command) in enumerate(checks):
        print(f"SOURCE_PREFLIGHT: {name}", flush=True)
        try:
            result = subprocess.run(command, cwd=ROOT, check=False)
            exit_code = result.returncode
        except OSError as error:
            print(f"SOURCE_PREFLIGHT: could not start {name}: {error}", file=sys.stderr)
            exit_code = 1
        outcomes[index]["status"] = "passed" if exit_code == 0 else "failed"
        if exit_code:
            break
    print(json.dumps({
        "evidenceKind": "checked-in-source-preflight",
        "checks": outcomes,
        "notEstablished": ["dependency-ready A03 persistence audit", "remaining CI jobs", "DEV runtime acceptance", "production signing", "distribution", "release authorization"],
    }), flush=True)
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
