#!/usr/bin/env python3
"""Build the compact Unicode lookup blob used by MoonIDNA.

Normal package builds consume the committed MoonBit embed output. Maintainers run
this tool only when updating Unicode data or changing the binary format.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
import tempfile
import urllib.request
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CODEPOINT_COUNT = 0x110000
PAGE_SHIFT = 8
PAGE_SIZE = 1 << PAGE_SHIFT
STAGE1_COUNT = CODEPOINT_COUNT // PAGE_SIZE
HEADER_SIZE = 104
EMBED_CHUNK_SIZE = 64 * 1024
EMBED_BYTES_PER_LINE = 32

MAPPING_STATUS = {
    "valid": 0,
    "ignored": 1,
    "mapped": 2,
    "deviation": 3,
    "disallowed": 4,
    "disallowed_STD3_valid": 5,
    "disallowed_STD3_mapped": 6,
}

BIDI_CLASS = {
    "L": 0,
    "R": 1,
    "AL": 2,
    "EN": 3,
    "ES": 4,
    "ET": 5,
    "AN": 6,
    "CS": 7,
    "NSM": 8,
    "BN": 9,
    "ON": 10,
    "LRE": 11,
    "LRO": 12,
    "RLE": 13,
    "RLO": 14,
    "PDF": 15,
    "LRI": 16,
    "RLI": 17,
    "FSI": 18,
    "PDI": 19,
    "S": 20,
    "WS": 21,
    "B": 22,
    "Left_To_Right": 0,
    "Right_To_Left": 1,
    "Arabic_Letter": 2,
    "European_Number": 3,
    "European_Separator": 4,
    "European_Terminator": 5,
    "Arabic_Number": 6,
    "Common_Separator": 7,
    "Nonspacing_Mark": 8,
    "Boundary_Neutral": 9,
    "Other_Neutral": 10,
    "Left_To_Right_Embedding": 11,
    "Left_To_Right_Override": 12,
    "Right_To_Left_Embedding": 13,
    "Right_To_Left_Override": 14,
    "Pop_Directional_Format": 15,
    "Left_To_Right_Isolate": 16,
    "Right_To_Left_Isolate": 17,
    "First_Strong_Isolate": 18,
    "Pop_Directional_Isolate": 19,
    "Segment_Separator": 20,
    "White_Space": 21,
    "Paragraph_Separator": 22,
}

JOINING_TYPE = {
    "U": 0,
    "L": 1,
    "R": 2,
    "D": 3,
    "T": 4,
    "C": 5,
    "Non_Joining": 0,
    "Left_Joining": 1,
    "Right_Joining": 2,
    "Dual_Joining": 3,
    "Transparent": 4,
    "Join_Causing": 5,
}

IDNA2008_CATEGORY = {
    "PVALID": 0,
    "CONTEXTJ": 1,
    "CONTEXTO": 2,
    "DISALLOWED": 3,
    "UNASSIGNED": 4,
}

def parse_range(text: str) -> tuple[int, int]:
    if ".." in text:
        first, last = text.split("..", 1)
        return int(first, 16), int(last, 16)
    value = int(text, 16)
    return value, value


def version_of(path: Path, version_hint: str | None = None) -> str:
    prefix = path.read_text(encoding="utf-8", errors="replace")[:4096]
    patterns = (
        r"(?im)^#\s*Version:\s*([0-9]+\.[0-9]+\.[0-9]+)",
        r"(?im)^#.*?-([0-9]+\.[0-9]+\.[0-9]+)\.txt",
    )
    for pattern in patterns:
        match = re.search(pattern, prefix)
        if match:
            return match.group(1)
    # UnicodeData.txt intentionally has no version header. Its sibling extracted
    # UCD files provide the version for a synchronized source directory.
    if path.name == "UnicodeData.txt" and version_hint is not None:
        return version_hint
    return "unknown"


def source_url(name: str, version: str) -> str:
    if name in ("IdnaMappingTable.txt", "IdnaTestV2.txt", "Idna2008.txt"):
        if version.startswith("17.") or int(version.split(".", 1)[0]) >= 17:
            return f"https://www.unicode.org/Public/{version}/idna/{name}"
        return f"https://www.unicode.org/Public/idna/{version}/{name}"
    if name in ("DerivedBidiClass.txt", "DerivedJoiningType.txt"):
        return f"https://www.unicode.org/Public/{version}/ucd/extracted/{name}"
    return f"https://www.unicode.org/Public/{version}/ucd/{name}"


def file_record(path: Path, source_dir: Path, version_hint: str | None = None) -> dict[str, str | int]:
    content = path.read_bytes()
    version = version_of(path, version_hint)
    return {
        "path": str(path.relative_to(source_dir)),
        "version": version,
        "sha256": hashlib.sha256(content).hexdigest(),
        "bytes": len(content),
        "url": source_url(path.name, version),
    }


def download_sources(source_dir: Path, lock: Path) -> None:
    if not lock.is_file():
        raise FileNotFoundError(f"cannot download without an existing lock file: {lock}")
    manifest = json.loads(lock.read_text(encoding="utf-8"))
    source_dir.mkdir(parents=True, exist_ok=True)
    for record in manifest["sources"]:
        destination = source_dir / record["path"]
        if not destination.is_file():
            with urllib.request.urlopen(record["url"], timeout=60) as response:
                destination.write_bytes(response.read())
        digest = hashlib.sha256(destination.read_bytes()).hexdigest()
        if digest != record["sha256"]:
            raise ValueError(f"source checksum mismatch: {destination}")


def verify_locked_sources(source_dir: Path, lock: Path) -> None:
    if not lock.is_file():
        return
    manifest = json.loads(lock.read_text(encoding="utf-8"))
    for record in manifest["sources"]:
        source = source_dir / record["path"]
        if not source.is_file():
            raise FileNotFoundError(f"missing {source}; rerun with --download")
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        if digest != record["sha256"]:
            raise ValueError(
                f"source checksum mismatch: {source}; "
                "use --update-lock for an intentional Unicode update"
            )


def deduplicate_pages(values: list[int], width: int) -> tuple[bytes, bytes, int]:
    page_ids: dict[tuple[int, ...], int] = {}
    stage1: list[int] = []
    pages: list[tuple[int, ...]] = []
    for offset in range(0, CODEPOINT_COUNT, PAGE_SIZE):
        page = tuple(values[offset : offset + PAGE_SIZE])
        page_id = page_ids.get(page)
        if page_id is None:
            page_id = len(pages)
            if page_id > 0xFFFF:
                raise ValueError("too many unique pages for a 16-bit stage-one index")
            page_ids[page] = page_id
            pages.append(page)
        stage1.append(page_id)
    stage1_bytes = struct.pack(f"<{len(stage1)}H", *stage1)
    flat = [value for page in pages for value in page]
    suffix = "H" if width == 2 else "I"
    stage2_bytes = struct.pack(f"<{len(flat)}{suffix}", *flat)
    return stage1_bytes, stage2_bytes, len(pages)


def load_mapping(path: Path) -> tuple[list[int], list[tuple[int, ...]]]:
    sequences: list[tuple[int, ...]] = [()]
    sequence_ids: dict[tuple[int, ...], int] = {(): 0}
    tokens = [MAPPING_STATUS["disallowed"]] * CODEPOINT_COUNT
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.split("#", 1)[0].strip()
        if not line:
            continue
        fields = [field.strip() for field in line.split(";")]
        first, last = parse_range(fields[0])
        status = MAPPING_STATUS[fields[1]]
        sequence = tuple(int(value, 16) for value in fields[2].split()) if len(fields) > 2 else ()
        sequence_id = sequence_ids.get(sequence)
        if sequence_id is None:
            sequence_id = len(sequences)
            if sequence_id >= (1 << 13):
                raise ValueError("mapping sequence id no longer fits in 13 bits")
            sequence_ids[sequence] = sequence_id
            sequences.append(sequence)
        token = (sequence_id << 3) | status
        tokens[first : last + 1] = [token] * (last - first + 1)
    return tokens, sequences


def apply_bidi_defaults(path: Path, values: list[int]) -> None:
    missing = re.compile(r"@missing:\s*([0-9A-F]+(?:\.\.[0-9A-F]+)?)\s*;\s*([A-Za-z_]+)")
    lines = path.read_text(encoding="utf-8").splitlines()
    for raw_line in lines:
        match = missing.search(raw_line)
        if match:
            first, last = parse_range(match.group(1))
            values[first : last + 1] = [BIDI_CLASS[match.group(2)]] * (last - first + 1)
    for raw_line in lines:
        line = raw_line.split("#", 1)[0].strip()
        if not line:
            continue
        fields = [field.strip() for field in line.split(";")]
        first, last = parse_range(fields[0])
        values[first : last + 1] = [BIDI_CLASS[fields[1]]] * (last - first + 1)


def apply_joining(path: Path, values: list[int]) -> None:
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.split("#", 1)[0].strip()
        if not line:
            continue
        fields = [field.strip() for field in line.split(";")]
        first, last = parse_range(fields[0])
        joining = JOINING_TYPE[fields[1]]
        for codepoint in range(first, last + 1):
            values[codepoint] = (values[codepoint] & ~(0x7 << 5)) | (joining << 5)


def apply_unicode_data(path: Path, values: list[int]) -> dict[int, tuple[int, ...]]:
    pending_range: tuple[int, int, bool] | None = None
    decompositions: dict[int, tuple[int, ...]] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        fields = raw_line.split(";")
        if len(fields) < 4:
            continue
        codepoint = int(fields[0], 16)
        name = fields[1]
        category = fields[2]
        ccc = int(fields[3])
        decomposition = fields[5].strip() if len(fields) > 5 else ""
        mark = category.startswith("M")
        if name.endswith(", First>"):
            pending_range = (codepoint, ccc, mark)
            continue
        if name.endswith(", Last>") and pending_range is not None:
            first, range_ccc, range_mark = pending_range
            for current in range(first, codepoint + 1):
                values[current] = (values[current] & ~((0xFF << 9) | (1 << 17))) | (range_ccc << 9) | (int(range_mark) << 17)
            pending_range = None
            continue
        values[codepoint] = (values[codepoint] & ~((0xFF << 9) | (1 << 17))) | (ccc << 9) | (int(mark) << 17)
        if ccc == 9:
            values[codepoint] |= 1 << 8
        if decomposition and not decomposition.startswith("<"):
            decompositions[codepoint] = tuple(int(value, 16) for value in decomposition.split())
    return decompositions


def load_composition_exclusions(*paths: Path) -> set[int]:
    exclusions: set[int] = set()
    for path in paths:
        for raw_line in path.read_text(encoding="utf-8").splitlines():
            line = raw_line.split("#", 1)[0].strip()
            if not line:
                continue
            fields = [field.strip() for field in line.split(";")]
            if path.name == "DerivedNormalizationProps.txt" and (len(fields) < 2 or fields[1] != "Full_Composition_Exclusion"):
                continue
            first, last = parse_range(fields[0])
            exclusions.update(range(first, last + 1))
    return exclusions


def apply_idna2008(path: Path, values: list[int]) -> None:
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.split("#", 1)[0].strip()
        if not line:
            continue
        fields = [field.strip() for field in line.split(";")]
        first, last = parse_range(fields[0])
        category = IDNA2008_CATEGORY[fields[1]]
        for codepoint in range(first, last + 1):
            values[codepoint] = (values[codepoint] & ~(0x7 << 18)) | (category << 18)


def build_decomposition_data(
    decompositions: dict[int, tuple[int, ...]],
    composition_exclusions: set[int],
) -> tuple[bytes, bytes, int, bytes, bytes, list[tuple[int, int, int]]]:
    sequences: list[tuple[int, ...]] = [()]
    sequence_ids: dict[tuple[int, ...], int] = {(): 0}
    tokens = [0] * CODEPOINT_COUNT
    for codepoint, sequence in decompositions.items():
        sequence_id = sequence_ids.get(sequence)
        if sequence_id is None:
            sequence_id = len(sequences)
            if sequence_id > 0xFFFF:
                raise ValueError("decomposition sequence id no longer fits in 16 bits")
            sequence_ids[sequence] = sequence_id
            sequences.append(sequence)
        tokens[codepoint] = sequence_id
    stage1, stage2, pages = deduplicate_pages(tokens, 2)
    descriptors, scalars = serialize_mapping_sequences(sequences)

    compositions: list[tuple[int, int, int]] = []
    for composite, sequence in decompositions.items():
        if len(sequence) != 2 or composite in composition_exclusions:
            continue
        compositions.append((sequence[0], sequence[1], composite))
    compositions.sort()
    return stage1, stage2, pages, descriptors, scalars, compositions


def serialize_mapping_sequences(sequences: list[tuple[int, ...]]) -> tuple[bytes, bytes]:
    descriptors: list[int] = []
    scalars: list[int] = []
    for sequence in sequences:
        if len(sequence) > 0xFF:
            raise ValueError("mapping sequence is too long")
        descriptors.append((len(scalars) << 8) | len(sequence))
        scalars.extend(sequence)
    descriptor_bytes = struct.pack(f"<{len(descriptors)}I", *descriptors)
    scalar_bytes = bytearray()
    for scalar in scalars:
        scalar_bytes.extend((scalar & 0xFF, (scalar >> 8) & 0xFF, (scalar >> 16) & 0xFF))
    return descriptor_bytes, bytes(scalar_bytes)


def align(output: bytearray, alignment: int = 4) -> None:
    output.extend(b"\0" * (-len(output) % alignment))


def build_blob(source_dir: Path) -> tuple[bytes, dict[str, object]]:
    mapping_path = source_dir / "IdnaMappingTable.txt"
    bidi_path = source_dir / "DerivedBidiClass.txt"
    joining_path = source_dir / "DerivedJoiningType.txt"
    unicode_path = source_dir / "UnicodeData.txt"
    normalization_path = source_dir / "DerivedNormalizationProps.txt"
    composition_exclusions_path = source_dir / "CompositionExclusions.txt"
    idna2008_path = source_dir / "Idna2008.txt"
    idna_test_path = source_dir / "IdnaTestV2.txt"
    source_paths = [
        mapping_path,
        bidi_path,
        joining_path,
        unicode_path,
        normalization_path,
        composition_exclusions_path,
        idna2008_path,
        idna_test_path,
    ]
    for path in source_paths:
        if not path.is_file():
            raise FileNotFoundError(path)

    unicode_data_version = version_of(joining_path)
    source_records = [
        file_record(path, source_dir, unicode_data_version if path == unicode_path else None)
        for path in source_paths
    ]
    source_versions = {record["version"] for record in source_records}
    if "unknown" in source_versions or len(source_versions) != 1:
        versions = ", ".join(sorted(str(version) for version in source_versions))
        raise ValueError(f"Unicode inputs must use one explicit version; found: {versions}")
    unicode_version = str(next(iter(source_versions)))
    version_parts = [int(part) for part in unicode_version.split(".")]
    if len(version_parts) != 3 or any(part < 0 or part > 0xFF for part in version_parts):
        raise ValueError(f"Unicode version cannot be packed into the Blob header: {unicode_version}")
    unicode_version_packed = (version_parts[0] << 16) | (version_parts[1] << 8) | version_parts[2]

    mapping_tokens, sequences = load_mapping(mapping_path)
    mapping_stage1, mapping_stage2, mapping_pages = deduplicate_pages(mapping_tokens, 2)
    descriptors, scalars = serialize_mapping_sequences(sequences)

    properties = [BIDI_CLASS["L"] | (IDNA2008_CATEGORY["UNASSIGNED"] << 18)] * CODEPOINT_COUNT
    apply_bidi_defaults(bidi_path, properties)
    apply_joining(joining_path, properties)
    decompositions = apply_unicode_data(unicode_path, properties)
    apply_idna2008(idna2008_path, properties)
    property_stage1, property_stage2, property_pages = deduplicate_pages(properties, 4)
    composition_exclusions = load_composition_exclusions(normalization_path, composition_exclusions_path)
    decomp_stage1, decomp_stage2, decomp_pages, decomp_descriptors, decomp_scalars, compositions = build_decomposition_data(
        decompositions,
        composition_exclusions,
    )
    composition_bytes = b"".join(struct.pack("<III", *entry) for entry in compositions)

    blob = bytearray(b"\0" * HEADER_SIZE)
    offsets: list[int] = []
    for section in (
        mapping_stage1,
        mapping_stage2,
        descriptors,
        scalars,
        property_stage1,
        property_stage2,
        decomp_stage1,
        decomp_stage2,
        decomp_descriptors,
        decomp_scalars,
        composition_bytes,
    ):
        align(blob)
        offsets.append(len(blob))
        blob.extend(section)
    align(blob)

    header = struct.pack(
        "<8sHH23I",
        b"MIDNADAT",
        1,
        PAGE_SHIFT,
        CODEPOINT_COUNT - 1,
        offsets[0],
        offsets[1],
        mapping_pages,
        offsets[2],
        len(sequences),
        offsets[3],
        len(scalars) // 3,
        offsets[4],
        offsets[5],
        property_pages,
        len(blob),
        0,
        offsets[6],
        offsets[7],
        decomp_pages,
        offsets[8],
        len(decomp_descriptors) // 4,
        offsets[9],
        len(decomp_scalars) // 3,
        offsets[10],
        len(compositions),
        unicode_version_packed,
    )
    blob[:HEADER_SIZE] = header
    checksum = zlib.crc32(blob[HEADER_SIZE:]) & 0xFFFFFFFF
    struct.pack_into("<I", blob, 60, checksum)

    manifest: dict[str, object] = {
        "format": 1,
        "page_shift": PAGE_SHIFT,
        "unicode_version": unicode_version,
        "sources": source_records,
        "blob": {
            "bytes": len(blob),
            "sha256": hashlib.sha256(blob).hexdigest(),
            "crc32": f"{checksum:08x}",
            "mapping_pages": mapping_pages,
            "mapping_sequences": len(sequences),
            "mapping_scalars": len(scalars) // 3,
            "property_pages": property_pages,
            "decomposition_pages": decomp_pages,
            "decomposition_sequences": len(decomp_descriptors) // 4,
            "composition_pairs": len(compositions),
            "composition_exclusions": len(composition_exclusions),
        },
    }
    return bytes(blob), manifest


def write_outputs(blob: bytes, manifest: dict[str, object], binary: Path, embed: Path, lock: Path) -> None:
    binary.parent.mkdir(parents=True, exist_ok=True)
    embed.parent.mkdir(parents=True, exist_ok=True)
    lock.parent.mkdir(parents=True, exist_ok=True)
    binary.write_bytes(blob)
    chunks = [blob[offset : offset + EMBED_CHUNK_SIZE] for offset in range(0, len(blob), EMBED_CHUNK_SIZE)]
    generated_parts = ["// Generated by tools/build_unicode_blob.py; do not edit.\n"]
    for index, chunk in enumerate(chunks):
        generated_parts.extend(
            [
                "\n///|\n",
                f"let unicode_data_blob_{index} : Bytes = [\n",
            ]
        )
        for offset in range(0, len(chunk), EMBED_BYTES_PER_LINE):
            line = ",".join(
                str(value) for value in chunk[offset : offset + EMBED_BYTES_PER_LINE]
            )
            generated_parts.append(f"  {line},\n")
        generated_parts.append("]\n")
    accessor = [
        "\n///|\n",
        "fn unicode_data_byte_at(offset : Int) -> Byte {\n",
    ]
    for index in range(len(chunks) - 1):
        upper = (index + 1) * EMBED_CHUNK_SIZE
        accessor.append(f"  if offset < {upper} {{\n")
        accessor.append(
            f"    return unicode_data_blob_{index}[offset - {index * EMBED_CHUNK_SIZE}]\n"
        )
        accessor.append("  }\n")
    last = len(chunks) - 1
    accessor.append(
        f"  unicode_data_blob_{last}[offset - {last * EMBED_CHUNK_SIZE}]\n"
    )
    accessor.append("}\n")
    embed.write_text("".join(generated_parts + accessor), encoding="utf-8")
    lock.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path, default=ROOT / ".unicode-cache" / "17.0.0")
    parser.add_argument("--binary", type=Path, default=ROOT / "unicode_data" / "unicode_data.bin")
    parser.add_argument("--embed", type=Path, default=ROOT / "src" / "unicode_blob.mbt")
    parser.add_argument("--lock", type=Path, default=ROOT / "unicode_data" / "unicode.lock.json")
    parser.add_argument("--check", action="store_true", help="fail if committed outputs are not reproducible")
    parser.add_argument("--download", action="store_true", help="download missing inputs using the pinned lock file")
    parser.add_argument(
        "--update-lock",
        action="store_true",
        help="accept synchronized source changes and rewrite the lock",
    )
    args = parser.parse_args()

    if args.download:
        download_sources(args.source_dir, args.lock)
    if not args.update_lock:
        verify_locked_sources(args.source_dir, args.lock)
    blob, manifest = build_blob(args.source_dir)
    if args.check:
        with tempfile.TemporaryDirectory(prefix="moonidna-unicode-") as temporary:
            temporary_path = Path(temporary)
            binary = temporary_path / "unicode_data.bin"
            embed = temporary_path / "unicode_blob.mbt"
            lock = temporary_path / "unicode.lock.json"
            write_outputs(blob, manifest, binary, embed, lock)
            expected = ((binary, args.binary), (embed, args.embed), (lock, args.lock))
            stale = [str(target) for generated, target in expected if not target.is_file() or generated.read_bytes() != target.read_bytes()]
            if stale:
                raise SystemExit("stale Unicode outputs: " + ", ".join(stale))
    else:
        write_outputs(blob, manifest, args.binary, args.embed, args.lock)
        print(json.dumps(manifest["blob"], sort_keys=True))


if __name__ == "__main__":
    main()
