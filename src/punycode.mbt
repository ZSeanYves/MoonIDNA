// --- Punycode 常量（RFC 3492） ---
const BASE : Int = 36
const TMIN : Int = 1
const TMAX : Int = 26
const SKEW : Int = 38
const DAMP : Int = 700
const INITIAL_BIAS : Int = 72
const INITIAL_N : Int = 0x80        // 128
const DELIMITER : Int = 0x2D        // '-'
const INT_MAX : Int = 0x7fffffff    // 简单的整型上界，用于溢出保护

// === 对外 API ===
// 把一个 Unicode label 编成 punycode label（不加 xn-- 前缀）
///|
pub fn encode(label : StringView) -> Result[String, PunycodeError] raise @buf.Utf8DecodeError {
// 1. UTF-8 -> code points
  let cps_res = utf8_to_codepoints(label)
  let cps = match cps_res {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let res = encode_codepoints(cps)
  res
}
// 把一个 punycode label 解码成 Unicode label（不处理 xn-- 前缀）
///|
pub fn decode(
  label : StringView,
) -> Result[String, PunycodeError] raise @buf.Utf8DecodeError {
  let res = match decode_to_codepoints(label) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let s = codepoints_to_utf8(res)
  s
}

// === 核心：编码 / 解码算法 ===
// 内部使用：编码 code point 数组为 punycode 字符串
///|
fn encode_codepoints(
  cps : Array[Int],
) -> Result[String, PunycodeError] raise @buf.Utf8DecodeError {
  let input_len = cps.length()
  if input_len == 0 {
    return Ok("".to_string())
  }
  let out_bytes : Array[Byte] = []
  let mut b : Int = 0
  let mut i = 0
  while i < input_len {
    let cp = cps[i]
    if cp < 0x80 {
      out_bytes.push(cp.to_byte())
      b += 1
    }
    i += 1
  }
  let mut h = b
  if b > 0 && b < input_len {
    out_bytes.push(DELIMITER.to_byte())
  }
  let mut n : Int = INITIAL_N
  let mut delta : Int = 0
  let mut bias : Int = INITIAL_BIAS
  while h < input_len {
    let mut m : Int = INT_MAX
    let mut j = 0
    while j < input_len {
      let cp = cps[j]
      if cp >= n && cp < m {
        m = cp
      }
      j += 1
    }
    if m == INT_MAX {
      return Err(PunycodeError::InvalidInput)
    }
    if m - n > (INT_MAX - delta) / (h + 1) {
      return Err(PunycodeError::Overflow)
    }
    delta += (m - n) * (h + 1)
    n = m
    j = 0
    while j < input_len {
      let cp = cps[j]
      if cp < n {
        delta += 1
        if delta < 0 {
          return Err(PunycodeError::Overflow)
        }
      } else if cp == n {
        let mut q = delta
        let mut k = BASE
        while true {
          let t = threshold(k, bias)
          if q < t {
            break
          }
          let code = t + (q - t) % (BASE - t)
          let bch = match encode_digit(code) {
            Ok(v) => v
            Err(e) => return Err(e)
          }
          out_bytes.push(bch.to_byte())
          q = (q - t) / (BASE - t)
          k += BASE
        }
        let last = match encode_digit(q) {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        out_bytes.push(last.to_byte())
        bias = adapt(delta, h + 1, h == b)
        delta = 0
        h += 1
      }
      j += 1
    }
    delta += 1
    n += 1
  }
  let s = bytes_to_string(out_bytes)
  s
}

// 内部使用：从 punycode 字符串解码成 code point 数组
///|
fn decode_to_codepoints(
  label : StringView,
) -> Result[Array[Int], PunycodeError] {
  let bytes = string_to_ascii_bytes(label)
  let out : Array[Int] = []
  let mut n : Int = INITIAL_N
  let mut i : Int = 0
  let mut bias : Int = INITIAL_BIAS

  // 处理 basic 部分（直到最后一个 '-'）
  let mut last_delim : Int = -1
  let mut idx = 0
  while idx < bytes.length() {
    if bytes[idx].to_int() == DELIMITER {
      last_delim = idx
    }
    idx += 1
  }
  idx = 0
  if last_delim != -1 {
    while idx < last_delim {
      let bch = bytes[idx].to_int()
      if bch >= 0x80 {
        return Err(PunycodeError::InvalidInput)
      }
      out.push(bch)
      idx += 1
    }
    idx = last_delim + 1
  }
  while idx < bytes.length() {
    let oldi = i
    let mut w : Int = 1
    let mut k : Int = BASE
    while true {
      if idx >= bytes.length() {
        return Err(PunycodeError::InvalidInput)
      }
      let digit = match decode_digit(bytes[idx].to_int()) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      idx += 1
      if digit > (INT_MAX - i) / w {
        return Err(PunycodeError::Overflow)
      }
      i += digit * w
      let t = threshold(k, bias)
      if digit < t {
        break
      }
      if w > INT_MAX / (BASE - t) {
        return Err(PunycodeError::Overflow)
      }
      w *= BASE - t
      k += BASE
    }
    let out_len = out.length() + 1
    bias = adapt(i - oldi, out_len, oldi == 0)
    let q = i / out_len
    if n + q > 0x10FFFF {
      return Err(PunycodeError::Overflow)
    }
    n += q
    let pos = i % out_len
    out.insert(pos, n)
    i = pos
  }
  Ok(out)
}

