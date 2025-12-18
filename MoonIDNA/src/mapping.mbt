// === 映射结果结构 ===
///|
pub struct MappedLabel {
  value : String
  errors : IdnaErrorList
}

// === 内部：查表 ===
/// 在 mapping_table 中查找给定 codepoint 的映射区间。
/// 返回 (status, mapping_seq)，若未命中则视为 Valid 无映射。
fn lookup_mapping(cp : Int) -> (MappingStatus, Array[Int]) {
  if mapping_table.length() == 0 {
    let empty : Array[Int] = []
    return (MappingStatus::Valid, empty)
  }
  let mut left = 0
  let mut right = mapping_table.length() - 1
  while left <= right {
    let mid = (left + right) / 2
    let ent = mapping_table[mid]
    if cp < ent.start {
      if mid == 0 {
        break
      }
      right = mid - 1
    } else if cp > ent.end {
      left = mid + 1
    } else {
      // 命中区间
      let empty : Array[Int] = []
      if ent.mapping.length() == 0 {
        return (ent.status, empty)
      } else {
        return (ent.status, ent.mapping)
      }
    }
  }
  let empty2 : Array[Int] = []
  (MappingStatus::Valid, empty2)
}

// === 对外：基于 UTS #46 的完整映射 ===

/// 基于 UTS #46 IdnaMappingTable 的 label 映射：
/// Valid       -> 原样保留
/// Ignored     -> 丢弃
/// Mappe       -> 替换为 mapping 序列
/// Deviation   -> transitional=true 时用 mapping，否则当 Valid
/// Disallowed* -> 记录错误，当前实现下保留原字符（后续可收紧）
///|
pub fn map_label(label : String, opts : IdnaOptions) -> MappedLabel {
  let chars = label.to_array()
  let out_chars : Array[Char] = []
  let errs : IdnaErrorList = []
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    let cp = c.to_int()
    let (status, mapping) = lookup_mapping(cp)
    match status {
      MappingStatus::Valid => out_chars.push(c)
      MappingStatus::Ignored => ()
      MappingStatus::Mapped => {
        let mut j = 0
        while j < mapping.length() {
          let mapped_cp = mapping[j]
          out_chars.push(Int::unsafe_to_char(mapped_cp))
          j += 1
        }
      }
      MappingStatus::Deviation =>
        if opts._transitional_processing {
          // transitional 模式：使用 mapping（例如 ß -> ss）
          let mut j = 0
          while j < mapping.length() {
            let mapped_cp = mapping[j]
            out_chars.push(Int::unsafe_to_char(mapped_cp))
            j += 1
          }
        } else {
          out_chars.push(c)
        }
      MappingStatus::Disallowed => {
        errs.push(IdnaError::InvalidCharacter)
        // 当前策略：仍然保留原字符，以避免改变现有行为
        out_chars.push(c)
      }
      MappingStatus::DisallowedStd3Valid => {
        // 在 STD3 模式下不允许；否则当 Valid
        if opts._use_std3_ascii_rules {
          errs.push(IdnaError::InvalidCharacter)
        }
        out_chars.push(c)
      }
      MappingStatus::DisallowedStd3Mapped =>
        // STD3 模式下不允许映射；否则当 Mapped
        if opts._use_std3_ascii_rules {
          errs.push(IdnaError::InvalidCharacter)
          out_chars.push(c)
        } else {
          let mut j = 0
          while j < mapping.length() {
            let mapped_cp = mapping[j]
            out_chars.push(Int::unsafe_to_char(mapped_cp))
            j += 1
          }
        }
    }
    i += 1
  }
  let value = String::from_array(out_chars)
  { value, errors: errs }
}
