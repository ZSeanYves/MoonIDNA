// --- STD3 规则检查（只在 _use_std3_ascii_rules == true 时启用） ---
///|
pub fn check_std3(label : String, opts : IdnaOptions) -> IdnaErrorList {
  let errs : IdnaErrorList = []
  if !opts._use_std3_ascii_rules {
    return errs
  }

  let bs = @buf.string_to_utf8_bytes(label).to_array()
  let mut i = 0
  while i < bs.length() {
    let b = bs[i].to_int()
    // 必须是 ASCII
    if b < 0 || b > 0x7F {
      errs.push(IdnaError::InvalidCharacter)
    } else {
      // STD3: 只允许 a-z, 0-9, '-'（我们已在 mapping 中做了大小写折叠）
      let is_digit = (b >= 0x30 && b <= 0x39)
      let is_lower = (b >= 0x61 && b <= 0x7A)
      let is_hyphen = (b == 0x2D)
      if !is_digit && !is_lower && !is_hyphen {
        errs.push(IdnaError::InvalidCharacter)
      }
    }
    i += 1
  }

  errs
}

// --- 连字符规则检查（_check_hyphens） ---
///|
pub fn check_hyphens(label : String, opts : IdnaOptions) -> IdnaErrorList {
  let errs : IdnaErrorList = []
  if !opts._check_hyphens {
    return errs
  }

  let bs = @buf.string_to_utf8_bytes(label).to_array()
  let len = bs.length()
  if len == 0 {
    return errs
  }

  // 1. 不允许首尾为 '-'
  if bs[0].to_int() == 0x2D || bs[len - 1].to_int() == 0x2D {
    errs.push(IdnaError::InvalidHyphenPosition)
  }

  // 2. 不允许位置 3、4 为 "--"，除非 label 以 "xn--"/"XN--" 开头
  if len >= 4 {
    let b0 = bs[0].to_int()
    let b1 = bs[1].to_int()
    let b2 = bs[2].to_int()
    let b3 = bs[3].to_int()

    let lower_x = 0x78  // 'x'
    let upper_x = 0x58  // 'X'
    let lower_n = 0x6E  // 'n'
    let upper_n = 0x4E  // 'N'

    let is_xn_prefix =
      (b0 == lower_x || b0 == upper_x) &&
      (b1 == lower_n || b1 == upper_n) &&
      b2 == 0x2D &&
      b3 == 0x2D

    if !is_xn_prefix && b2 == 0x2D && b3 == 0x2D {
      errs.push(IdnaError::InvalidHyphenPosition)
    }
  }

  errs
}

// --- DNS 长度检查（_verify_dns_length） ---
///|
pub fn check_dns_length(domain : String, opts : IdnaOptions) -> IdnaErrorList {
  let errs : IdnaErrorList = []
  if !opts._verify_dns_length {
    return errs
  }

  let bs = @buf.string_to_utf8_bytes(domain).to_array()
  let total_len = bs.length()
  if total_len > 255 {
    errs.push(IdnaError::DomainTooLong)
  }

  // 按 '.' 拆 label，检查每个 label 长度 <= 63
  let mut current_len : Int = 0
  let mut i = 0
  while i < bs.length() {
    let b = bs[i].to_int()
    if b == 0x2E { // '.'
      if current_len > 63 {
        errs.push(IdnaError::LabelTooLong)
      }
      current_len = 0
    } else {
      current_len += 1
    }
    i += 1
  }
  // 最后一个 label
  if current_len > 63 {
    errs.push(IdnaError::LabelTooLong)
  }

  errs
}
// --- 单个 label 的 Bidi 检查封装 ---
///|
fn check_bidi(label : String, opts : IdnaOptions) -> IdnaErrorList {
  let errs : IdnaErrorList = []
  if !opts._check_bidi {
    return errs
  }

  // 空 label（前导/连续点）不参与 Bidi 规则
  if label.length() == 0 {
    return errs
  }

  let ok = check_bidi_label(label)
  if !ok {
    errs.push(IdnaError::BidiError)
  }
  errs
}

// --- 单个 joiners 的 Bidi 检查封装 ---
///|
fn check_joiners(label : String, opts : IdnaOptions) -> IdnaErrorList {
  let errs : IdnaErrorList = []

  if !opts._check_joiners {
    return errs
  }

  if label.length() == 0 {
    return errs
  }

  let chars = label.to_array()
  let cps : Array[Int] = []
  let mut i = 0
  while i < chars.length() {
    cps.push(chars[i].to_int())
    i += 1
  }

  if !contextj_valid(cps) {
    errs.push(IdnaError::JoinerError)
  }
  errs
}

///|
pub fn validate_label_all(label : String, opts : IdnaOptions) -> IdnaErrorList {
  let all : IdnaErrorList = []

  let e1 = check_std3(label, opts)
  let mut i = 0
  while i < e1.length() {
    all.push(e1[i])
    i += 1
  }

  let e2 = check_hyphens(label, opts)
  let mut j = 0
  while j < e2.length() {
    all.push(e2[j])
    j += 1
  }

  let e3 = check_bidi(label, opts)
  let mut k = 0
  while k < e3.length() {
    all.push(e3[k])
    k += 1
  }

  let e4 = check_joiners(label, opts)
  let mut m = 0
  while m < e4.length() {
    all.push(e4[m])
    m += 1
  }

  all
}

///|
pub fn validate_domain_all(domain : String, opts : IdnaOptions) -> IdnaErrorList {
  let all : IdnaErrorList = []

  let e = check_dns_length(domain, opts)
  let mut i = 0
  while i < e.length() {
    all.push(e[i])
    i += 1
  }

  all
}

