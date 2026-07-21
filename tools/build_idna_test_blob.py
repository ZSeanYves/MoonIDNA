#!/usr/bin/env python3
"""Compile Unicode IdnaTestV2.txt into the cross-backend MoonBit test blob."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CHUNK_SIZE = 64 * 1024
IGNORED_WITH_DEFAULT_FLAGS = {"U1", "V2", "V3", "A4_1", "A4_2"}


def decode_field(field: str) -> str | None:
    field = field.strip()
    if field == '""':
        return ""
    codepoints: list[int] = []
    index = 0
    while index < len(field):
        if field.startswith("\\u", index) and index + 6 <= len(field):
            codepoints.append(int(field[index + 2 : index + 6], 16))
            index += 6
        elif field.startswith("\\x{", index):
            end = field.index("}", index + 3)
            codepoints.append(int(field[index + 3 : end], 16))
            index = end + 1
        else:
            codepoints.append(ord(field[index]))
            index += 1

    scalars: list[int] = []
    index = 0
    while index < len(codepoints):
        codepoint = codepoints[index]
        if 0xD800 <= codepoint <= 0xDBFF:
            if index + 1 >= len(codepoints) or not 0xDC00 <= codepoints[index + 1] <= 0xDFFF:
                return None
            low = codepoints[index + 1]
            scalars.append(0x10000 + ((codepoint - 0xD800) << 10) + (low - 0xDC00))
            index += 2
            continue
        if 0xDC00 <= codepoint <= 0xDFFF:
            return None
        scalars.append(codepoint)
        index += 1
    return "".join(chr(codepoint) for codepoint in scalars)


def status_codes(field: str) -> set[str]:
    field = field.strip()
    if not field or field == "[]":
        return set()
    if not field.startswith("[") or not field.endswith("]"):
        raise ValueError(f"invalid status field: {field}")
    return {value.strip() for value in field[1:-1].split(",") if value.strip()}


def has_default_error(codes: set[str]) -> bool:
    return bool(codes - IGNORED_WITH_DEFAULT_FLAGS)


def parse_cases(path: Path) -> tuple[list[tuple[int, int, str, str, str, str]], int]:
    cases: list[tuple[int, int, str, str, str, str]] = []
    skipped = 0
    for line_number, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw_line.split("#", 1)[0].strip()
        if not line:
            continue
        fields = [field.strip() for field in line.split(";")]
        if len(fields) < 7:
            fields.extend([""] * (7 - len(fields)))
        source = decode_field(fields[0])
        if source is None:
            skipped += 1
            continue
        unicode_output = source if fields[1] == "" else decode_field(fields[1])
        ascii_n_output = unicode_output if fields[3] == "" else decode_field(fields[3])
        ascii_t_output = ascii_n_output if fields[5] == "" else decode_field(fields[5])
        if unicode_output is None or ascii_n_output is None or ascii_t_output is None:
            skipped += 1
            continue

        unicode_status = status_codes(fields[2])
        ascii_n_status = unicode_status if fields[4] == "" else status_codes(fields[4])
        ascii_t_status = ascii_n_status if fields[6] == "" else status_codes(fields[6])
        flags = int(has_default_error(unicode_status))
        flags |= int(has_default_error(ascii_n_status)) << 1
        flags |= int(has_default_error(ascii_t_status)) << 2
        cases.append((line_number, flags, source, unicode_output, ascii_n_output, ascii_t_output))
    return cases, skipped


def build_binary(cases: list[tuple[int, int, str, str, str, str]], skipped: int) -> bytes:
    output = bytearray(struct.pack("<8sIII", b"IDNATV2\0", 1, len(cases), skipped))
    for line_number, flags, *strings in cases:
        output.extend(struct.pack("<IB3x", line_number, flags))
        for value in strings:
            encoded = value.encode("utf-8")
            output.extend(struct.pack("<I", len(encoded)))
            output.extend(encoded)
    return bytes(output)


def write_embed(binary: bytes, output: Path) -> None:
    parts: list[str] = []
    with tempfile.TemporaryDirectory(prefix="moonidna-test-embed-") as temporary:
        directory = Path(temporary)
        chunks = [binary[offset : offset + CHUNK_SIZE] for offset in range(0, len(binary), CHUNK_SIZE)]
        for index, chunk in enumerate(chunks):
            chunk_binary = directory / f"idna_test_{index}.bin"
            chunk_source = directory / f"idna_test_{index}.mbt"
            chunk_binary.write_bytes(chunk)
            subprocess.run(
                [
                    "moon", "tool", "embed", "--binary",
                    "--input", str(chunk_binary), "--output", str(chunk_source),
                    "--name", f"idna_test_blob_{index}",
                ],
                cwd=ROOT,
                check=True,
            )
            generated = chunk_source.read_text(encoding="utf-8")
            parts.append("\n".join(line.rstrip() for line in generated.splitlines()))
    accessor = ["\n///|\n", "fn idna_test_byte_at(offset : Int) -> Byte {\n"]
    for index in range(len(chunks) - 1):
        upper = (index + 1) * CHUNK_SIZE
        accessor.extend(
            [
                f"  if offset < {upper} {{\n",
                f"    return idna_test_blob_{index}[offset - {index * CHUNK_SIZE}]\n",
                "  }\n",
            ]
        )
    last = len(chunks) - 1
    accessor.extend([f"  idna_test_blob_{last}[offset - {last * CHUNK_SIZE}]\n", "}\n"])
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(parts) + "".join(accessor), encoding="utf-8")


def generate(source: Path, binary_output: Path, embed_output: Path, metadata_output: Path) -> None:
    cases, skipped = parse_cases(source)
    binary = build_binary(cases, skipped)
    binary_output.parent.mkdir(parents=True, exist_ok=True)
    binary_output.write_bytes(binary)
    write_embed(binary, embed_output)
    metadata = {
        "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "binary_sha256": hashlib.sha256(binary).hexdigest(),
        "bytes": len(binary),
        "cases": len(cases),
        "skipped_ill_formed": skipped,
    }
    metadata_output.write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=ROOT / ".unicode-cache" / "17.0.0" / "IdnaTestV2.txt")
    parser.add_argument("--binary", type=Path, default=ROOT / "unicode_data" / "idna_test_v2.bin")
    parser.add_argument("--embed", type=Path, default=ROOT / "idna" / "idna_test_blob_wbtest.mbt")
    parser.add_argument("--metadata", type=Path, default=ROOT / "unicode_data" / "idna_test_v2.json")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.check:
        with tempfile.TemporaryDirectory(prefix="moonidna-test-check-") as temporary:
            directory = Path(temporary)
            generated = (
                directory / "idna_test_v2.bin",
                directory / "idna_test_blob_wbtest.mbt",
                directory / "idna_test_v2.json",
            )
            generate(args.source, *generated)
            committed = (args.binary, args.embed, args.metadata)
            stale = [str(target) for candidate, target in zip(generated, committed) if not target.is_file() or candidate.read_bytes() != target.read_bytes()]
            if stale:
                raise SystemExit("stale IDNA test outputs: " + ", ".join(stale))
    else:
        generate(args.source, args.binary, args.embed, args.metadata)
        print(args.metadata.read_text(encoding="utf-8").strip())


if __name__ == "__main__":
    main()
