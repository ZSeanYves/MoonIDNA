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
        if pos == 0 {         return false
        }
        pos -= 1
      }
      JoiningType::L | JoiningType::D =>
        break
      _ =>
        return false
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
      JoiningType::R | JoiningType::D =>
        return true
      _ =>
        return false
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
