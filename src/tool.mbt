// --- 工具：检测末尾是否有 '.' ---
///|
fn has_trailing_dot(domain : StringView) -> Bool {
  let s_str = domain.to_string()
  let bs = @buf.string_to_utf8_bytes(s_str).to_array()
  if bs.length() == 0 {
    return false
  }
  bs[bs.length() - 1].to_int() == 0x2E // '.'
}

// --- 工具：将域名拆成 labels（忽略末尾的 '.'，方便处理） ---
///|
fn split_labels(
  domain : StringView,
) -> Array[String] raise @buf.Utf8DecodeError {
  let s_str = domain.to_string()
  let bs = @buf.string_to_utf8_bytes(s_str).to_array()
  let labels : Array[String] = []
  let mut current : Array[Byte] = []
  let mut limit = bs.length()
  if limit > 0 && bs[limit - 1].to_int() == 0x2E {
    // 去掉末尾 '.'，用 has_trailing_dot 单独记录
    limit = limit - 1
  }
  let mut i = 0
  while i < limit {
    let b = bs[i]
    if b.to_int() == 0x2E {
      // 碰到 '.'，结束一个 label
      let label_str = if current.length() == 0 {
        "".to_string()
      } else {
        @buf.utf8_bytes_to_string(Bytes::from_array(current))
      }
      labels.push(label_str)
      current = []
    } else {
      current.push(b)
    }
    i += 1
  }

  // 收尾：如果还有内容，作为最后一个 label
  if current.length() > 0 || limit == 0 {
    let label_str = if current.length() == 0 {
      "".to_string()
    } else {
      @buf.utf8_bytes_to_string(Bytes::from_array(current))
    }
    labels.push(label_str)
  }
  labels
}
// --- 工具：判断一个 label 是否全部 ASCII ---
///|
fn is_all_ascii(label : String) -> Bool {
  let bs = @buf.string_to_utf8_bytes(label).to_array()
  let mut i = 0
  while i < bs.length() {
    let b = bs[i].to_int()
    if b < 0 || b > 0x7F {
      return false
    }
    i += 1
  }
  true
}

// --- 工具：用 '.' 把 labels 拼回域名字符串 ---
fn join_labels(labels : Array[String]) -> String {
  let mut out = "".to_string()
  let mut i = 0
  while i < labels.length() {
    if i > 0 {
      out = out + "."
    }
    out = out + labels[i]
    i += 1
  }
  out
}
// --- 工具：判断 label 是否以 xn-- 开头（不区分大小写） ---
///|
fn is_punycode_label(label : String) -> Bool {
  let bs = @buf.string_to_utf8_bytes(label).to_array()
  if bs.length() < 4 {
    return false
  }
  let b0 = bs[0].to_int()
  let b1 = bs[1].to_int()
  let b2 = bs[2].to_int()
  let b3 = bs[3].to_int()
  let lower_x = 0x78 // 'x'
  let upper_x = 0x58 // 'X'
  let lower_n = 0x6E // 'n'
  let upper_n = 0x4E // 'N'
  if b0 != lower_x && b0 != upper_x {
    return false
  }
  if b1 != lower_n && b1 != upper_n {
    return false
  }
  if b2 != 0x2D { // '-'
    return false
  }
  if b3 != 0x2D { // '-'
    return false
  }
  true
}


// --- 工具：取掉 xn-- 前缀后的 payload 字符串 ---
///|
fn punycode_payload(label : String) -> String raise @buf.Utf8DecodeError {
  let bs = @buf.string_to_utf8_bytes(label).to_array()
  let payload : Array[Byte] = []
  let mut i = 4
  while i < bs.length() {
    payload.push(bs[i])
    i += 1
  }
  @buf.utf8_bytes_to_string(Bytes::from_array(payload))
}

// === Bootstring 辅助函数 ===
///|
fn threshold(k : Int, bias : Int) -> Int {
  if k <= bias + TMIN {
    TMIN
  } else if k >= bias + TMAX {
    TMAX
  } else {
    k - bias
  }
}

///|
fn adapt(delta : Int, numpoints : Int, first_time : Bool) -> Int {
  // 简化版：不做额外溢出检查，按 RFC 3492 公式实现
  let mut d = delta
  if first_time {
    d = d / DAMP
  } else {
    d = d / 2
  }

  d = d + d / numpoints
  let mut k : Int = 0
  while d > ((BASE - TMIN) * TMAX) / 2 {
    d = d / (BASE - TMIN)
    k += BASE
  }
  k + (((BASE - TMIN + 1) * d) / (d + SKEW))
}

///|
fn encode_digit(d : Int) -> Result[Int, PunycodeError] {
  if d >= 0 && d < 26 {
    Ok(0x61 + d)         // 'a'..'z'
  } else if d >= 26 && d < 36 {
    Ok(0x30 + (d - 26))  // '0'..'9'
  } else {
    Err(PunycodeError::InvalidInput)
  }
}

///|
fn decode_digit(c : Int) -> Result[Int, PunycodeError] {
  if c >= 0x30 && c <= 0x39 {
    Ok(c - 0x30 + 26)          // '0'..'9'
  } else if c >= 0x41 && c <= 0x5A {
    Ok(c - 0x41)               // 'A'..'Z'
  } else if c >= 0x61 && c <= 0x7A {
    Ok(c - 0x61)               // 'a'..'z'
  } else {
    Err(PunycodeError::InvalidInput)
  }
}

// === UTF-8 与 code point 转换 ===
///|
fn utf8_to_codepoints(s : StringView) -> Result[Array[Int], PunycodeError] {
  let s_str = s.to_string()
  let bs = @buf.string_to_utf8_bytes(s_str).to_array()
  let cps : Array[Int] = []
  let mut i = 0
  while i < bs.length() {
    let b0 = bs[i].to_int() & 0xFF
    i += 1
    if b0 < 0x80 {
      cps.push(b0)
    } else if (b0 & 0xE0) == 0xC0 {
      if i >= bs.length() {
        return Err(PunycodeError::InvalidUtf8)
      }
      let b1 = bs[i].to_int() & 0xFF
      i += 1
      if (b1 & 0xC0) != 0x80 {
        return Err(PunycodeError::InvalidUtf8)
      }
      let cp = ((b0 & 0x1F) << 6) | (b1 & 0x3F)
      if cp < 0x80 {
        return Err(PunycodeError::InvalidUtf8) // overlong
      }
      cps.push(cp)
    } else if (b0 & 0xF0) == 0xE0 {
      if i + 1 >= bs.length() {
        return Err(PunycodeError::InvalidUtf8)
      }
      let b1 = bs[i].to_int() & 0xFF
      let b2 = bs[i + 1].to_int() & 0xFF
      i += 2
      if (b1 & 0xC0) != 0x80 || (b2 & 0xC0) != 0x80 {
        return Err(PunycodeError::InvalidUtf8)
      }
      let cp = ((b0 & 0x0F) << 12) | ((b1 & 0x3F) << 6) | (b2 & 0x3F)
      if cp < 0x800 {
        return Err(PunycodeError::InvalidUtf8)
      }
      if cp >= 0xD800 && cp <= 0xDFFF {
        return Err(PunycodeError::InvalidUtf8)
      }
      cps.push(cp)
    } else if (b0 & 0xF8) == 0xF0 {
      if i + 2 >= bs.length() {
        return Err(PunycodeError::InvalidUtf8)
      }
      let b1 = bs[i].to_int() & 0xFF
      let b2 = bs[i + 1].to_int() & 0xFF
      let b3 = bs[i + 2].to_int() & 0xFF
      i += 3
      if (b1 & 0xC0) != 0x80 || (b2 & 0xC0) != 0x80 || (b3 & 0xC0) != 0x80 {
        return Err(PunycodeError::InvalidUtf8)
      }
      let cp = ((b0 & 0x07) << 18) |
        ((b1 & 0x3F) << 12) |
        ((b2 & 0x3F) << 6) |
        (b3 & 0x3F)
      if cp < 0x10000 || cp > 0x10FFFF {
        return Err(PunycodeError::InvalidUtf8)
      }
      cps.push(cp)
    } else {
      return Err(PunycodeError::InvalidUtf8)
    }
  }
  Ok(cps)
}

///|
fn codepoints_to_utf8(cps : Array[Int]) -> Result[String, PunycodeError] raise @buf.Utf8DecodeError{
  let bs : Array[Byte] = []

  let mut i = 0
  while i < cps.length() {
    let cp = cps[i]
    if cp < 0 || cp > 0x10FFFF {
      return Err(PunycodeError::InvalidInput)
    }

    if cp < 0x80 {
      bs.push(cp.to_byte())
    } else if cp < 0x800 {
      bs.push((0xC0 | (cp >> 6)).to_byte())
      bs.push((0x80 | (cp & 0x3F)).to_byte())
    } else if cp < 0x10000 {
      if cp >= 0xD800 && cp <= 0xDFFF {
        return Err(PunycodeError::InvalidInput)
      }
      bs.push((0xE0 | (cp >> 12)).to_byte())
      bs.push((0x80 | ((cp >> 6) & 0x3F)).to_byte())
      bs.push((0x80 | (cp & 0x3F)).to_byte())
    } else {
      bs.push((0xF0 | (cp >> 18)).to_byte())
      bs.push((0x80 | ((cp >> 12) & 0x3F)).to_byte())
      bs.push((0x80 | ((cp >> 6) & 0x3F)).to_byte())
      bs.push((0x80 | (cp & 0x3F)).to_byte())
    }
    i += 1
  }

  let s = bytes_to_string(bs)
  s
}

// 把 ASCII/UTF-8 字符串直接转为 bytes（UTF-8）
///|
fn string_to_ascii_bytes(s : StringView) -> Array[Byte] {
  let s_str = s.to_string()
  @buf.string_to_utf8_bytes(s_str).to_array()
}


// bytes -> String（假设是合法 UTF-8）
///|
fn bytes_to_string(bs : Array[Byte]) -> Result[String, PunycodeError] raise @buf.Utf8DecodeError {
  let s = @buf.utf8_bytes_to_string(Bytes::from_array(bs))
  Ok(s)
}

// === 工具：查某个 codepoint 的 BidiClass ===
///|
fn bidi_class_of(cp : Int) -> BidiClass {
  if bidi_table.length() == 0 {
    // 没有表时，保守视为 ON
    return BidiClass::ON
  }

  let mut left = 0
  let mut right = bidi_table.length() - 1

  while left <= right {
    let mid = (left + right) / 2
    let ent = bidi_table[mid]
    if cp < ent.start {
      if mid == 0 {
        break
      }
      right = mid - 1
    } else if cp > ent.end {
      left = mid + 1
    } else {
      return ent.class
    }
  }

  // 未命中的 codepoint，默认为 ON
  BidiClass::ON
}