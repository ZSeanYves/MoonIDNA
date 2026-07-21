// === 映射结果结构 ===

///|
priv struct MappedLabel {
  value : String
  errors : IdnaErrorList
}

// === 对外：基于 UTS #46 的完整映射 ===

/// 基于 UTS #46 IdnaMappingTable 的 label 映射：
/// Valid       -> 原样保留
/// Ignored     -> 丢弃
/// Mappe       -> 替换为 mapping 序列
/// Deviation   -> transitional=true 时用 mapping，否则当 Valid
/// Disallowed* -> 记录错误，当前实现下保留原字符（后续可收紧）

///|
fn append_mapped_codepoint(
  cp : Int,
  opts : IdnaOptions,
  out_chars : Array[Char],
  errs : IdnaErrorList,
  depth : Int,
) -> Unit {
  if depth > 8 {
    errs.push(IdnaError::InvalidCharacter)
    return
  }
  let token = mapping_token_of(cp)
  let status = mapping_status_of(token)
  let descriptor = mapping_descriptor_of(token)
  match status {
    MappingStatus::Valid => out_chars.push(Int::unsafe_to_char(cp))
    MappingStatus::Ignored => ()
    MappingStatus::Mapped => {
      let mut j = 0
      while j < mapping_length_of(descriptor) {
        let mapped_cp = mapping_scalar_at(descriptor, j)
        append_mapped_codepoint(mapped_cp, opts, out_chars, errs, depth + 1)
        j += 1
      }
    }
    MappingStatus::Deviation =>
      if opts._transitional_processing {
        // transitional 模式：使用 mapping（例如 ß -> ss）
        let mut j = 0
        while j < mapping_length_of(descriptor) {
          let mapped_cp = mapping_scalar_at(descriptor, j)
          append_mapped_codepoint(mapped_cp, opts, out_chars, errs, depth + 1)
          j += 1
        }
      } else {
        out_chars.push(Int::unsafe_to_char(cp))
      }
    MappingStatus::Disallowed => {
      errs.push(IdnaError::InvalidCharacter)
      out_chars.push(Int::unsafe_to_char(cp))
    }
    MappingStatus::DisallowedStd3Valid => {
      // 在 STD3 模式下不允许；否则当 Valid
      if opts._use_std3_ascii_rules {
        errs.push(IdnaError::InvalidCharacter)
      }
      out_chars.push(Int::unsafe_to_char(cp))
    }
    MappingStatus::DisallowedStd3Mapped =>
      // STD3 模式下不允许映射；否则当 Mapped
      if opts._use_std3_ascii_rules {
        errs.push(IdnaError::InvalidCharacter)
        out_chars.push(Int::unsafe_to_char(cp))
      } else {
        let mut j = 0
        while j < mapping_length_of(descriptor) {
          let mapped_cp = mapping_scalar_at(descriptor, j)
          append_mapped_codepoint(mapped_cp, opts, out_chars, errs, depth + 1)
          j += 1
        }
      }
  }
}

///|
fn map_label(label : String, opts : IdnaOptions) -> MappedLabel {
  let out_chars : Array[Char] = []
  let errs : IdnaErrorList = []
  for character in label {
    append_mapped_codepoint(character.to_int(), opts, out_chars, errs, 0)
  }
  let value = String::from_array(out_chars)
  { value, errors: errs }
}
