#!/usr/bin/env python3
"""Fail closed unless every APK native library is 16 KB compatible."""

from __future__ import annotations

import argparse
import json
import struct
import sys
import zipfile
from pathlib import Path

PAGE_SIZE = 16 * 1024
PT_LOAD = 1
ZIP_LOCAL_HEADER = struct.Struct("<IHHHHHIIIHH")
ZIP_LOCAL_HEADER_SIGNATURE = 0x04034B50


class AlignmentError(RuntimeError):
    """Raised when an APK cannot prove 16 KB native compatibility."""


def _read_int(data: bytes, offset: int, size: int, endian: str) -> int:
    end = offset + size
    if end > len(data):
        raise AlignmentError("ELF header or program table is truncated")
    return int.from_bytes(data[offset:end], endian)


def _elf_load_alignments(data: bytes, entry: str) -> list[int]:
    if len(data) < 64 or data[:4] != b"\x7fELF":
        raise AlignmentError(f"Native entry is not a complete ELF file: {entry}")

    elf_class = data[4]
    data_encoding = data[5]
    if data_encoding == 1:
        endian = "little"
    elif data_encoding == 2:
        endian = "big"
    else:
        raise AlignmentError(f"Unsupported ELF byte order in {entry}")

    if elf_class == 1:
        program_offset = _read_int(data, 28, 4, endian)
        entry_size = _read_int(data, 42, 2, endian)
        entry_count = _read_int(data, 44, 2, endian)
        align_offset = 28
        align_size = 4
    elif elf_class == 2:
        program_offset = _read_int(data, 32, 8, endian)
        entry_size = _read_int(data, 54, 2, endian)
        entry_count = _read_int(data, 56, 2, endian)
        align_offset = 48
        align_size = 8
    else:
        raise AlignmentError(f"Unsupported ELF class in {entry}: {elf_class}")

    minimum_entry_size = align_offset + align_size
    if entry_count <= 0 or entry_size < minimum_entry_size:
        raise AlignmentError(f"Invalid ELF program table in {entry}")

    alignments: list[int] = []
    for index in range(entry_count):
        offset = program_offset + index * entry_size
        program_type = _read_int(data, offset, 4, endian)
        if program_type == PT_LOAD:
            alignments.append(
                _read_int(data, offset + align_offset, align_size, endian)
            )

    if not alignments:
        raise AlignmentError(f"ELF file has no loadable segments: {entry}")
    return alignments


def _zip_data_offset(apk: Path, info: zipfile.ZipInfo) -> int:
    with apk.open("rb") as handle:
        handle.seek(info.header_offset)
        header = handle.read(ZIP_LOCAL_HEADER.size)
    if len(header) != ZIP_LOCAL_HEADER.size:
        raise AlignmentError(f"Truncated ZIP local header: {info.filename}")
    values = ZIP_LOCAL_HEADER.unpack(header)
    if values[0] != ZIP_LOCAL_HEADER_SIGNATURE:
        raise AlignmentError(f"Invalid ZIP local header: {info.filename}")
    name_length = values[-2]
    extra_length = values[-1]
    return info.header_offset + ZIP_LOCAL_HEADER.size + name_length + extra_length


def verify_apk(apk: Path) -> dict[str, object]:
    if not apk.is_file() or apk.stat().st_size <= 0:
        raise AlignmentError(f"APK is missing or empty: {apk}")

    records: list[dict[str, object]] = []
    with zipfile.ZipFile(apk, "r") as archive:
        corrupt = archive.testzip()
        if corrupt is not None:
            raise AlignmentError(f"APK ZIP integrity failure at {corrupt}")

        native_entries = sorted(
            (
                info
                for info in archive.infolist()
                if info.filename.startswith("lib/") and info.filename.endswith(".so")
            ),
            key=lambda info: info.filename,
        )
        if not native_entries:
            raise AlignmentError("APK contains no native shared libraries")
        names = [info.filename for info in native_entries]
        if len(names) != len(set(names)):
            raise AlignmentError("APK contains duplicate native-library entries")

        for info in native_entries:
            if info.compress_type != zipfile.ZIP_STORED:
                raise AlignmentError(
                    f"Native library is compressed instead of page aligned: {info.filename}"
                )
            data_offset = _zip_data_offset(apk, info)
            if data_offset % PAGE_SIZE != 0:
                raise AlignmentError(
                    f"Native ZIP entry is not 16 KB aligned: {info.filename}; "
                    f"offset={data_offset}"
                )
            load_alignments = _elf_load_alignments(
                archive.read(info),
                info.filename,
            )
            invalid = [value for value in load_alignments if value < PAGE_SIZE]
            if invalid:
                rendered = ",".join(f"0x{value:X}" for value in load_alignments)
                raise AlignmentError(
                    f"ELF load segment is not 16 KB aligned: {info.filename}; "
                    f"alignments={rendered}"
                )
            records.append(
                {
                    "entry": info.filename,
                    "zipDataOffset": data_offset,
                    "zipAlignment": PAGE_SIZE,
                    "elfLoadAlignments": [
                        f"0x{value:X}" for value in load_alignments
                    ],
                    "uncompressedBytes": info.file_size,
                }
            )

    return {
        "status": "PASS_ANDROID_16KB_NATIVE_ALIGNMENT",
        "apk": str(apk.resolve()),
        "pageSizeBytes": PAGE_SIZE,
        "nativeLibraryCount": len(records),
        "nativeLibraries": records,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apk", required=True, type=Path)
    parser.add_argument("--json-output", type=Path)
    args = parser.parse_args()

    try:
        result = verify_apk(args.apk.resolve())
        rendered = json.dumps(result, indent=2, sort_keys=True) + "\n"
        if args.json_output is not None:
            args.json_output.parent.mkdir(parents=True, exist_ok=True)
            args.json_output.write_text(rendered, encoding="utf-8", newline="\n")
        print(result["status"])
        print(f"nativeLibraryCount={result['nativeLibraryCount']}")
        return 0
    except (AlignmentError, OSError, zipfile.BadZipFile) as exc:
        print(f"FAIL_ANDROID_16KB_NATIVE_ALIGNMENT: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
