from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "data"
OUT_FILE = ROOT / "joining_table.mbt"

JT_FILE = DATA_DIR / "DerivedJoiningType.txt"
UCD_FILE = DATA_DIR / "UnicodeData.txt"

jt_re = re.compile(
    r"^([0-9A-F]{4,6})(?:\.\.([0-9A-F]{4,6}))?\s*;\s*([A-Za-z_]+)"
)

JT_MAP = {
    "U": "JoiningType::U",  
    "L": "JoiningType::L", 
    "R": "JoiningType::R",  
    "D": "JoiningType::D",  
    "T": "JoiningType::T",  
    "C": "JoiningType::C",  

    "Non_Joining":   "JoiningType::U",
    "Left_Joining":  "JoiningType::L",
    "Right_Joining": "JoiningType::R",
    "Dual_Joining":  "JoiningType::D",
    "Transparent":   "JoiningType::T",
    "Join_Causing":  "JoiningType::C",
}



entries = []  

with JT_FILE.open("r", encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith("#"):
            continue

        m = jt_re.match(line)
        if not m:
            continue

        start_hex, end_hex, cls = m.groups()
        start = int(start_hex, 16)
        end = int(end_hex, 16) if end_hex else start

        if cls not in JT_MAP:
            continue

        moon_cls = JT_MAP[cls]

        if moon_cls == "JoiningType::U":
            continue

        entries.append((start, end, moon_cls))

entries.sort(key=lambda x: x[0])


viramas = []  

with UCD_FILE.open("r", encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split(";")
        if len(parts) < 4:
            continue
        cp_hex = parts[0]
        ccc = parts[3].strip()
        try:
            ccc_val = int(ccc)
        except ValueError:
            continue
        if ccc_val == 9:  # Virama
            viramas.append(int(cp_hex, 16))

viramas.sort()


with OUT_FILE.open("w", encoding="utf-8") as out:
    out.write("""pub enum JoiningType {
    U // Non_Joining or unknown
    L // Left_Joining
    R // Right_Joining
    D // Dual_Joining
    T // Transparent
    C // Join_Causing
}

///|
pub struct JoiningEntry {
    start : Int
    end : Int
    class : JoiningType
}

///|
pub let joining_table : Array[JoiningEntry] = [
""")

    for start, end, cls in entries:
        out.write(f"  {{ start: 0x{start:X}, end: 0x{end:X}, class: {cls} }},\n")

    out.write("]\n\n")

    out.write("///|\n")
    out.write("pub let virama_table : Array[Int] = [\n")
    for cp in viramas:
        out.write(f"  0x{cp:X},\n")
    out.write("]\n\n")

    out.write("""///|
pub fn joining_type_of(cp : Int) -> JoiningType {
  let mut lo = 0
  let mut hi = joining_table.length()
  while lo < hi {
    let mid = (lo + hi) / 2
    let e = joining_table[mid]
    if cp < e.start {
      hi = mid
    } else if cp > e.end {
      lo = mid + 1
    } else {
      return e.class
    }
  }
  JoiningType::U
}

///|
pub fn is_virama(cp : Int) -> Bool {
  let mut lo = 0
  let mut hi = virama_table.length()
  while lo < hi {
    let mid = (lo + hi) / 2
    let v = virama_table[mid]
    if cp < v {
      hi = mid
    } else if cp > v {
      lo = mid + 1
    } else {
      return true
    }
  }
  false
}
""")

print("Generated", OUT_FILE, "with", len(entries), "joining ranges and", len(viramas), "viramas.")
