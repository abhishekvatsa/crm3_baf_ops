#!/usr/bin/env python3
"""Verify a SHA-256 manifest containing '<hash>  <relative path>' lines."""
from __future__ import annotations
import argparse
import hashlib
from pathlib import Path
import sys


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest().upper()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, default=Path.cwd())
    parser.add_argument('--manifest', type=Path, required=True)
    args = parser.parse_args()
    root = args.root.resolve()
    manifest = args.manifest
    if not manifest.is_absolute():
        manifest = (root / manifest).resolve()
    failures: list[str] = []
    checked = 0
    for line_no, raw in enumerate(manifest.read_text(encoding='utf-8').splitlines(), 1):
        line = raw.strip('\n')
        if not line or line.lstrip().startswith('#'):
            continue
        parts = line.split('  ', 1)
        if len(parts) != 2 or len(parts[0].strip()) != 64:
            failures.append(f'line {line_no}: malformed manifest entry')
            continue
        expected, rel = parts[0].strip().upper(), parts[1].strip().replace('\\', '/')
        target = (root / rel).resolve()
        try:
            target.relative_to(root)
        except ValueError:
            failures.append(f'{rel}: path escapes root')
            continue
        if not target.is_file():
            failures.append(f'{rel}: missing')
            continue
        actual = sha256(target)
        checked += 1
        if actual != expected:
            failures.append(f'{rel}: expected {expected}, actual {actual}')
    if failures:
        print(f'FAIL: manifest verification checked={checked} failures={len(failures)}')
        for failure in failures:
            print(f'  {failure}')
        return 1
    print(f'PASS: manifest verification checked={checked} failures=0')
    return 0


if __name__ == '__main__':
    sys.exit(main())
