/// RFC 5892 Appendix A：ContextJ 规则总入口。

///|
fn contextj_valid(cps : Array[Int]) -> Bool {
  let len = cps.length()
  if len == 0 {
    return true
  }

  // 快速路径：没有 ZWNJ/ZWJ 则直接合法
  let mut i = 0
  let mut has_joiner : Bool = false
  while i < len {
    let cp = cps[i]
    if cp == 0x200C || cp == 0x200D {
      has_joiner = true
      break
    }
    i += 1
  }
  if !has_joiner {
    return true
  }

  i = 0
  while i < len {
    let cp = cps[i]
    if cp == 0x200C {
      if !valid_zwnj(cps, i) {
        return false
      }
    } else if cp == 0x200D {
      if !valid_zwj(cps, i) {
        return false
      }
    }
    i += 1
  }
  true
}

/// U+200C ZERO WIDTH NON-JOINER 的上下文检查：
/// 允许两种情况：前一个字符是 Virama；匹配 (L/D) T* ZWNJ T* (R/D)。

///|
fn valid_zwnj(cps : Array[Int], idx : Int) -> Bool {
  if cps[idx] != 0x200C {
    return true
  }

  if idx > 0 {
    let prev = cps[idx - 1]
    if is_virama(prev) {
      return true
    }
  }

  let len = cps.length()

  if idx == 0 {
    return false
  }

  let mut pos = idx - 1
  while true {
    let jt = joining_type_of(cps[pos])
    match jt {
      JoiningType::T => {
        if pos == 0 {
          return false
        }
        pos -= 1
      }
      JoiningType::L | JoiningType::D => break
      JoiningType::U | JoiningType::R | JoiningType::C => return false
    }
  }

  let mut pos2 = idx + 1
  if pos2 >= len {
    return false
  }

  while pos2 < len {
    let jt2 = joining_type_of(cps[pos2])
    match jt2 {
      JoiningType::T => pos2 += 1
      JoiningType::R | JoiningType::D => return true
      JoiningType::U | JoiningType::L | JoiningType::C => return false
    }
  }

  false
}

/// U+200D ZERO WIDTH JOINER 的上下文检查：
/// 仅允许前一个字符是 Virama。

///|
fn valid_zwj(cps : Array[Int], idx : Int) -> Bool {
  if cps[idx] != 0x200D {
    return true
  }
  if idx == 0 {
    return false
  }
  let prev = cps[idx - 1]
  is_virama(prev)
}

///|
/// RFC 5892 CONTEXTO rules for the code points assigned that category.
fn contexto_valid(cps : Array[Int]) -> Bool {
  let mut has_arabic_indic = false
  let mut has_extended_arabic_indic = false
  for cp in cps {
    if cp >= 0x660 && cp <= 0x669 {
      has_arabic_indic = true
    }
    if cp >= 0x6F0 && cp <= 0x6F9 {
      has_extended_arabic_indic = true
    }
  }
  if has_arabic_indic && has_extended_arabic_indic {
    return false
  }
  for i in 0..<cps.length() {
    let cp = cps[i]
    if cp == 0xB7 {
      if i == 0 ||
        i + 1 >= cps.length() ||
        cps[i - 1] != 0x6C ||
        cps[i + 1] != 0x6C {
        return false
      }
    } else if cp == 0x375 {
      if i == 0 || !is_greek(cps[i - 1]) {
        return false
      }
    } else if cp == 0x5F3 || cp == 0x5F4 {
      if i == 0 || !is_hebrew(cps[i - 1]) {
        return false
      }
    } else if cp == 0x30FB {
      let mut has_script = false
      for other in cps {
        if is_han(other) || is_hiragana(other) || is_katakana(other) {
          has_script = true
        }
      }
      if !has_script {
        return false
      }
    }
  }
  true
}

///|
fn is_greek(cp : Int) -> Bool {
  (cp >= 0x370 && cp <= 0x3FF) || (cp >= 0x1F00 && cp <= 0x1FFF)
}

///|
fn is_hebrew(cp : Int) -> Bool {
  (cp >= 0x590 && cp <= 0x5FF) || (cp >= 0xFB1D && cp <= 0xFB4F)
}

///|
fn is_han(cp : Int) -> Bool {
  (cp >= 0x3400 && cp <= 0x4DBF) ||
  (cp >= 0x4E00 && cp <= 0x9FFF) ||
  (cp >= 0x20000 && cp <= 0x323AF)
}

///|
fn is_hiragana(cp : Int) -> Bool {
  cp >= 0x3040 && cp <= 0x309F
}

///|
fn is_katakana(cp : Int) -> Bool {
  (cp >= 0x30A0 && cp <= 0x30FF) || (cp >= 0x31F0 && cp <= 0x31FF)
}
