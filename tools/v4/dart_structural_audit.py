#!/usr/bin/env python3
"""Lexical/structural Dart checks for environments without the pinned Dart SDK.

This is deliberately not a parser and must never be reported as `flutter analyze`.
It catches truncated edits, unbalanced delimiters, missing part files and duplicate
Isar property/index ids in generated bindings.
"""
from __future__ import annotations

import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def dart_files() -> list[Path]:
    return sorted((ROOT / 'lib').rglob('*.dart')) + sorted((ROOT / 'test').rglob('*.dart'))


def strip_strings_and_comments(text: str) -> str:
    """Blank comments/string text while retaining real Dart code delimiters.

    `${...}` interpolation bodies are recursively lexed as Dart code, including
    strings/comments nested inside the interpolation.
    """
    chars = list(text)
    n = len(chars)

    def blank(a: int, b: int) -> None:
        for j in range(a, min(b, n)):
            if chars[j] != '\n':
                chars[j] = ' '

    def parse_string(i: int, raw: bool, quote_pos: int) -> int:
        quote = text[quote_pos]
        triple = text[quote_pos:quote_pos + 3] == quote * 3
        open_end = quote_pos + (3 if triple else 1)
        blank(i, open_end)
        j = open_end
        while j < n:
            if not raw and text[j] == '$' and j + 1 < n and text[j + 1] == '{':
                blank(j, j + 2)
                j = parse_code(j + 2, stop_on_interpolation_close=True)
                continue
            if not raw and text[j] == '\\':
                blank(j, j + 2)
                j += 2
                continue
            if triple:
                if text[j:j + 3] == quote * 3:
                    blank(j, j + 3)
                    return j + 3
            elif text[j] == quote:
                blank(j, j + 1)
                return j + 1
            blank(j, j + 1)
            j += 1
        raise ValueError('unterminated string')

    def parse_code(i: int, stop_on_interpolation_close: bool = False) -> int:
        nested_braces = 0
        while i < n:
            ch = text[i]
            nxt = text[i + 1] if i + 1 < n else ''
            if ch == '/' and nxt == '/':
                j = text.find('\n', i + 2)
                if j < 0: j = n
                blank(i, j)
                i = j
                continue
            if ch == '/' and nxt == '*':
                depth = 1
                j = i + 2
                while j < n and depth:
                    if text[j:j + 2] == '/*': depth += 1; j += 2; continue
                    if text[j:j + 2] == '*/': depth -= 1; j += 2; continue
                    j += 1
                if depth: raise ValueError('unterminated block_comment')
                blank(i, j)
                i = j
                continue
            prev = text[i - 1] if i > 0 else ''
            if ch in 'rR' and nxt in "'\"" and not (prev.isalnum() or prev in '_$'):
                i = parse_string(i, True, i + 1)
                continue
            if ch in "'\"":
                i = parse_string(i, False, i)
                continue
            if stop_on_interpolation_close:
                if ch == '{':
                    nested_braces += 1
                elif ch == '}':
                    if nested_braces == 0:
                        blank(i, i + 1)
                        return i + 1
                    nested_braces -= 1
            i += 1
        if stop_on_interpolation_close:
            raise ValueError('unterminated interpolation')
        return i

    parse_code(0)
    return ''.join(chars)


def delimiter_error(path: Path, cleaned: str) -> str | None:
    pairs = {')': '(', ']': '[', '}': '{'}
    stack: list[tuple[str, int]] = []
    for idx, ch in enumerate(cleaned):
        if ch in '([{': stack.append((ch, idx))
        elif ch in pairs:
            if not stack or stack[-1][0] != pairs[ch]:
                line = cleaned.count('\n', 0, idx) + 1
                return f'unexpected {ch!r} at line {line}'
            stack.pop()
    if stack:
        ch, idx = stack[-1]
        line = cleaned.count('\n', 0, idx) + 1
        return f'unclosed {ch!r} opened at line {line}'
    return None


def check_parts(path: Path, text: str) -> list[str]:
    problems: list[str] = []
    for part in re.findall(r"(?m)^\s*part\s+['\"]([^'\"]+)['\"]\s*;", text):
        target = (path.parent / part).resolve()
        if not target.is_file():
            problems.append(f'missing part target {part}')
    return problems


def schema_block(text: str) -> str:
    start = text.find('properties: {')
    if start < 0: return ''
    end = text.find('\n  },\n  estimateSize:', start)
    if end < 0: end = text.find('\n  },\n  serialize:', start)
    return text[start:end if end >= 0 else len(text)]


def duplicate_ids(path: Path, text: str) -> list[str]:
    if not path.name.endswith('.g.dart') or 'CollectionSchema(' not in text:
        return []
    problems: list[str] = []
    props = schema_block(text)
    prop_ids = [int(x) for x in re.findall(r'PropertySchema\(\s*\n?\s*id:\s*(-?\d+)', props)]
    dup_props = sorted({x for x in prop_ids if prop_ids.count(x) > 1})
    if dup_props: problems.append(f'duplicate property ids {dup_props}')
    # Index ids are globally unique within the declared indexes map.
    index_pos = text.find('indexes: {')
    if index_pos >= 0:
        index_end = text.find('\n  },\n  links:', index_pos)
        indexes = text[index_pos:index_end if index_end >= 0 else len(text)]
        idx_ids = [int(x) for x in re.findall(r'IndexSchema\(\s*\n?\s*id:\s*(-?\d+)', indexes)]
        dup_idx = sorted({x for x in idx_ids if idx_ids.count(x) > 1})
        if dup_idx: problems.append(f'duplicate index ids {dup_idx}')
    return problems


def main() -> int:
    files = dart_files()
    failures: list[str] = []
    provisional = 0
    for path in files:
        rel = path.relative_to(ROOT)
        text = path.read_text(encoding='utf-8')
        if 'PROVISIONAL_V4_ISAR_CODEGEN' in text: provisional += 1
        try:
            cleaned = strip_strings_and_comments(text)
        except ValueError as exc:
            failures.append(f'{rel}: {exc}')
            continue
        err = delimiter_error(path, cleaned)
        if err: failures.append(f'{rel}: {err}')
        failures.extend(f'{rel}: {p}' for p in check_parts(path, text))
        failures.extend(f'{rel}: {p}' for p in duplicate_ids(path, text))
    git_probe = subprocess.run(
        ['git', 'rev-parse', '--is-inside-work-tree'],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )
    git_checked = git_probe.returncode == 0 and git_probe.stdout.strip() == 'true'
    if git_checked:
        diff = subprocess.run(['git', 'diff', '--check'], cwd=ROOT, text=True, capture_output=True)
        if diff.returncode != 0:
            failures.append('git diff --check failed:\n' + diff.stdout + diff.stderr)
    if failures:
        print('CRM3 v4 — DART STRUCTURAL AUDIT')
        for failure in failures: print('FAIL | ' + failure)
        print(f'SUMMARY | files={len(files)} fail={len(failures)} provisional_isar={provisional}')
        return 1
    print('CRM3 v4 — DART STRUCTURAL AUDIT')
    print(f'PASS | lexical delimiter balance across {len(files)} Dart files')
    print('PASS | every declared part file exists')
    print('PASS | generated Isar property/index ids contain no duplicates')
    print('PASS | git diff --check' if git_checked else 'SKIP | git diff --check (not a Git worktree)')
    print(f'SUMMARY | files={len(files)} fail=0 provisional_isar={provisional} flutter_analyze=NOT_RUN')
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
