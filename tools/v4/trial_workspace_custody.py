#!/usr/bin/env python3
"""Capture and verify the disposable v4.2_R1 trial workspace boundary."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from pathlib import Path

IGNORED_PARTS = {
    "node_modules", ".dart_tool", "build", ".gradle", ".firebase", "coverage",
    "ephemeral", ".symlinks",
}
IGNORED_PREFIXES = {
    "functions/lib/", "android/.gradle/", "local_trial_evidence/",
}
CONTROLLED_ADDITIONS = {
    "lib/firebase_options.dart", "android/app/google-services.json",
    ".flutter-plugins", ".flutter-plugins-dependencies", ".packages",
    "android/local.properties", "ios/Flutter/Generated.xcconfig",
    "ios/Flutter/flutter_export_environment.sh",
}
FLUTTER_PLATFORM_REGISTRANTS = {
    "android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java",
    "ios/Runner/GeneratedPluginRegistrant.h",
    "ios/Runner/GeneratedPluginRegistrant.m",
    "linux/flutter/generated_plugin_registrant.cc",
    "linux/flutter/generated_plugin_registrant.h",
    "linux/flutter/generated_plugins.cmake",
    "macos/Flutter/GeneratedPluginRegistrant.swift",
    "windows/flutter/generated_plugin_registrant.cc",
    "windows/flutter/generated_plugin_registrant.h",
    "windows/flutter/generated_plugins.cmake",
}
LOCKFILES = {
    "pubspec.lock", "package-lock.json", "functions/package-lock.json",
    "tooling/firebase-cli/package-lock.json",
}


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest().upper()


def ignored(rel: str) -> bool:
    parts = set(Path(rel).parts)
    return bool(parts & IGNORED_PARTS) or any(rel.startswith(prefix) for prefix in IGNORED_PREFIXES)


def inventory(root: Path, include_ignored: bool = False) -> dict[str, dict]:
    result: dict[str, dict] = {}
    for path in root.rglob("*"):
        if not path.is_file() or path.is_symlink():
            continue
        rel = path.relative_to(root).as_posix()
        if not include_ignored and ignored(rel):
            continue
        result[rel] = {"sha256": digest(path), "bytes": path.stat().st_size}
    return dict(sorted(result.items()))


def write_json(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def capture(args) -> int:
    root = Path(args.root).resolve()
    data = {
        "schemaVersion": 1,
        "root": str(root),
        "files": inventory(root, include_ignored=args.include_ignored),
    }
    write_json(Path(args.output).resolve(), data)
    print(f"PASS_CAPTURE_WORKSPACE_MANIFEST: files={len(data['files'])}")
    return 0


def verify(args) -> int:
    root = Path(args.root).resolve()
    before = json.loads(Path(args.before).read_text(encoding="utf-8"))["files"]
    after = inventory(root)
    failures: list[dict] = []
    allowed: list[dict] = []
    unchanged = 0

    for rel, expected in before.items():
        found = after.get(rel)
        if found is None:
            failures.append({"path": rel, "reason": "pristine-file-deleted"})
            continue
        if found["sha256"] == expected["sha256"]:
            unchanged += 1
            continue
        if rel.endswith(".g.dart") and rel.startswith("lib/"):
            allowed.append({"path": rel, "change": "generated-binding-modified"})
            continue
        failures.append(
            {
                "path": rel,
                "reason": "handwritten-or-governed-file-modified",
                "before": expected["sha256"],
                "after": found["sha256"],
            }
        )

    for rel, found in after.items():
        if rel in before:
            continue
        if rel in CONTROLLED_ADDITIONS:
            allowed.append({"path": rel, "change": "governed-firebase-input-added"})
        elif rel in FLUTTER_PLATFORM_REGISTRANTS:
            allowed.append(
                {
                    "path": rel,
                    "change": "flutter-platform-registrant-added",
                    "sha256": found["sha256"],
                }
            )
        elif rel.endswith(".g.dart") and rel.startswith("lib/"):
            allowed.append({"path": rel, "change": "generated-binding-added"})
        else:
            failures.append(
                {"path": rel, "reason": "unexpected-non-ephemeral-file-added", "sha256": found["sha256"]}
            )

    lockfile_changes = [
        rel for rel in LOCKFILES
        if rel in before and rel in after and before[rel]["sha256"] != after[rel]["sha256"]
    ]
    for rel in lockfile_changes:
        if not any(f.get("path") == rel for f in failures):
            failures.append({"path": rel, "reason": "lockfile-changed"})

    report = {
        "schemaVersion": 1,
        "root": str(root),
        "beforeFileCount": len(before),
        "afterFileCount": len(after),
        "unchangedCount": unchanged,
        "allowedChanges": allowed,
        "failures": failures,
        "status": "PASS_POST_CODEGEN_CUSTODY" if not failures else "FAIL_POST_CODEGEN_CUSTODY",
    }
    write_json(Path(args.report).resolve(), report)
    if args.after:
        write_json(Path(args.after).resolve(), {"schemaVersion": 1, "root": str(root), "files": after})
    print(
        f"{report['status']}: unchanged={unchanged} allowed={len(allowed)} failures={len(failures)}"
    )
    if failures:
        print(json.dumps(failures, indent=2), file=sys.stderr)
        return 1
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    cap = sub.add_parser("capture")
    cap.add_argument("--root", required=True)
    cap.add_argument("--output", required=True)
    cap.add_argument("--include-ignored", action="store_true")
    cap.set_defaults(func=capture)
    ver = sub.add_parser("verify")
    ver.add_argument("--root", required=True)
    ver.add_argument("--before", required=True)
    ver.add_argument("--report", required=True)
    ver.add_argument("--after")
    ver.set_defaults(func=verify)
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
