import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
DATA_FILE = ROOT / "data" / "IdnaMappingTable.txt"
OUT_FILE = ROOT / "mapping_tables.mbt"

STATUS_MAP = {
    "valid": "MappingStatus::Valid",
    "ignored": "MappingStatus::Ignored",
    "mapped": "MappingStatus::Mapped",
    "deviation": "MappingStatus::Deviation",
    "disallowed": "MappingStatus::Disallowed",
    "disallowed_STD3_valid": "MappingStatus::DisallowedStd3Valid",
    "disallowed_STD3_mapped": "MappingStatus::DisallowedStd3Mapped",
}

def parse_code_point(s: str) -> int:
    return int(s, 16)

def parse_mapping_field(field: str):
    field = field.strip()
    if not field:
        return []
    return [parse_code_point(x) for x in field.split()]

def load_raw_entries():
    entries = []
    with DATA_FILE.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "#" in line:
                line, _ = line.split("#", 1)
                line = line.strip()
            parts = [p.strip() for p in line.split(";")]
            if len(parts) < 2:
                continue
            code_part = parts[0]
            status_str = parts[1]
            mapping_field = parts[2] if len(parts) >= 3 else ""

            if ".." in code_part:
                start_s, end_s = code_part.split("..", 1)
                start = parse_code_point(start_s)
                end = parse_code_point(end_s)
            else:
                start = end = parse_code_point(code_part)

            status = STATUS_MAP[status_str]
            mapping_seq = parse_mapping_field(mapping_field)

            entries.append((start, end, status, tuple(mapping_seq)))
    return entries

def merge_entries(entries):
    if not entries:
        return []

    entries.sort(key=lambda e: e[0])  
    merged = []
    cur_start, cur_end, cur_status, cur_map = entries[0]

    for start, end, status, mapping in entries[1:]:
        if status == cur_status and mapping == cur_map and start == cur_end + 1:
            cur_end = end
        else:
            merged.append((cur_start, cur_end, cur_status, cur_map))
            cur_start, cur_end, cur_status, cur_map = start, end, status, mapping

    merged.append((cur_start, cur_end, cur_status, cur_map))
    return merged

def emit_tables_mbt(entries):
    lines = []
    lines.append('/// UTS #46 映射状态\n')
    lines.append('///|\n')
    lines.append('pub enum MappingStatus {\n')
    lines.append('  Valid\n')
    lines.append('  Ignored\n')
    lines.append('  Mapped\n')
    lines.append('  Deviation\n')
    lines.append('  Disallowed\n')
    lines.append('  DisallowedStd3Valid\n')
    lines.append('  DisallowedStd3Mapped\n')
    lines.append('}\n\n')
    lines.append('/// 单条映射区间\n')
    lines.append('///|\n')
    lines.append('pub struct MappingEntry{\n')
    lines.append('  start : Int\n')
    lines.append('  end : Int\n')
    lines.append('  status : MappingStatus\n')
    lines.append('  mapping : Array[Int]\n')
    lines.append('}\n\n')
    lines.append('pub let mapping_table : Array[MappingEntry] = [\n')

    for start, end, status, mapping in entries:
        if mapping:
            mapping_elems = ", ".join(f"0x{cp:04X}" for cp in mapping)
            mapping_str = f"[{mapping_elems}]"
        else:
            mapping_str = "[]"

        lines.append(
            f'  {{start : 0x{start:04X}, end : 0x{end:04X}, '
            f'status : {status}, mapping : {mapping_str}}},\n'
        )

    lines.append(']\n')
    return "".join(lines)

def main():
    entries = load_raw_entries()
    merged = merge_entries(entries)
    out_text = emit_tables_mbt(merged)
    OUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    OUT_FILE.write_text(out_text, encoding="utf-8")
    print(f"Generated {OUT_FILE} with {len(merged)} entries.")

if __name__ == "__main__":
    main()
