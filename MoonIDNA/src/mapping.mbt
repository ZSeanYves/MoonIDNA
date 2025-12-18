/// 简单版映射结果：
/// - value：映射后的 label 文本
/// - errors：目前为空，后续接入 UTS #46 具体错误时再填
///|
pub struct MappedLabel{
  value : String
  errors : IdnaErrorList
}

/// 基础映射：
/// - ASCII 'A'..'Z' → 'a'..'z'
/// - 若 _transitional_processing 打开：
///     U+00DF (ß, UTF-8 C3 9F) → "ss"
/// - 其他字符保持不变
///|
pub fn map_label(label : String, opts : IdnaOptions) -> MappedLabel raise @buf.Utf8DecodeError {
  let bs = @buf.string_to_utf8_bytes(label).to_array()
  let out_bytes : Array[Byte] = []
  let mut i = 0

  while i < bs.length() {
    let b = bs[i].to_int()

    // --- transitional: ß (U+00DF, UTF-8: C3 9F) -> "ss" ---
    if opts._transitional_processing &&
      i + 1 < bs.length() &&
      b == 0xC3 &&
      bs[i + 1].to_int() == 0x9F {
      // 写入 "ss" 两个 ASCII 字节
      out_bytes.push(0x73) // 's'
      out_bytes.push(0x73) // 's'
      i += 2
      continue
    }

    // --- ASCII 大写字母 -> 小写 ---
    if b >= 0x41 && b <= 0x5A { // 'A'..'Z'
      let lower = b + 0x20      // -> 'a'..'z'
      out_bytes.push(lower.to_byte())
    } else {
      out_bytes.push(bs[i])
    }

    i += 1
  }

  let value = @buf.utf8_bytes_to_string(Bytes::from_array(out_bytes))
  let errors : IdnaErrorList = []
  {value : value, errors : errors}
}
