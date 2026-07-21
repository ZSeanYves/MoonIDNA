import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
DATA_FILE = ROOT / "data" / "DerivedBidiClass.txt"
OUT_FILE = ROOT / "bidi_table.mbt"

BIDI_CLASS_MAP = {
    "L":   "BidiClass::L",
    "R":   "BidiClass::R",
    "AL":  "BidiClass::AL",
    "EN":  "BidiClass::EN",
    "ES":  "BidiClass::ES",
    "ET":  "BidiClass::ET",
    "AN":  "BidiClass::AN",
    "CS":  "BidiClass::CS",
    "NSM": "BidiClass::NSM",
    "BN":  "BidiClass::BN",
    "ON":  "BidiClass::ON",
    "LRE": "BidiClass::LRE",
    "LRO": "BidiClass::LRO",
    "RLE": "BidiClass::RLE",
    "RLO": "BidiClass::RLO",
    "PDF": "BidiClass::PDF",
    "LRI": "BidiClass::LRI",
    "RLI": "BidiClass::RLI",
    "FSI": "BidiClass::FSI",
    "PDI": "BidiClass::PDI",
    "S":   "BidiClass::S",
    "WS":  "BidiClass::WS",
    "B":   "BidiClass::B",
}

def parse_code_point(s: str) -> int:
    return int(s, 16)

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
            if not line:
                continue

            parts = [p.strip() for p in line.split(";")]
            if len(parts) < 2:
                continue

            code_part = parts[0]
            class_str = parts[1]
            if class_str not in BIDI_CLASS_MAP:
                continue

            if ".." in code_part:
                start_s, end_s = code_part.split("..", 1)
                start = parse_code_point(start_s)
                end = parse_code_point(end_s)
            else:
                start = end = parse_code_point(code_part)

            bc = BIDI_CLASS_MAP[class_str]
            entries.append((start, end, bc))
    return entries

def merge_entries(entries):
    if not entries:
        return []

    entries.sort(key=lambda e: e[0])
    merged = []
    cur_start, cur_end, cur_bc = entries[0]

    for start, end, bc in entries[1:]:
        if bc == cur_bc and start == cur_end + 1:
            cur_end = end
        else:
            merged.append((cur_start, cur_end, cur_bc))
            cur_start, cur_end, cur_bc = start, end, bc

    merged.append((cur_start, cur_end, cur_bc))
    return merged

def emit_bidi_table(entries):
    lines = []
    lines.append("/// Unicode Bidi_Class\n")
    lines.append("///|\n")
    lines.append("pub enum BidiClass {\n")
    enum_names = [
        "L","R","AL","EN","ES","ET","AN","CS","NSM","BN","ON",
        "LRE","LRO","RLE","RLO","PDF","LRI","RLI","FSI","PDI",
        "S","WS","B",
    ]
    for name in enum_names:
        lines.append(f"  {name}\n")
    lines.append("}\n\n")
    lines.append("/// Bidi 类区间\n")
    lines.append("///|\n")
    lines.append("pub struct BidiEntry{\n")
    lines.append("  start : Int\n")
    lines.append("  end   : Int\n")
    lines.append("  class : BidiClass\n")
    lines.append("}\n\n")

    # table
    lines.append("/// 按 start 升序的 Bidi 区间表\n")
    lines.append("///|\n")
    lines.append("pub let bidi_table : Array[BidiEntry] = [\n")
    for start, end, bc in entries:
        lines.append(
            f"  {{ start: 0x{start:04X}, end: 0x{end:04X}, class: {bc} }},\n"
        )
    lines.append("]\n")

    return "".join(lines)

def main():
    entries = load_raw_entries()
    merged = merge_entries(entries)
    out_text = emit_bidi_table(merged)
    OUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    OUT_FILE.write_text(out_text, encoding="utf-8")
    print(f"Generated {OUT_FILE} with {len(merged)} entries.")

if __name__ == "__main__":
    main()
