// === 主检查逻辑（基于 RFC 5893 简化实现） ===
/// 检查单个 label 是否满足 IDNA Bidi 规则。
/// 返回 true 表示通过，false 表示违反规则。
///|
fn check_bidi_label(label : String) -> Bool {
  let chars = label.to_array()
  let len = chars.length()
  if len == 0 {
    return true
  }
  let classes : Array[BidiClass] = []
  let mut i = 0
  while i < len {
    let cp = chars[i].to_int()
    let bc = bidi_class_of(cp)
    classes.push(bc)
    i += 1
  }
  let mut first_idx = 0
  while first_idx < classes.length() {
    match classes[first_idx] {
      BidiClass::NSM | BidiClass::BN => first_idx += 1
      _ => break
    }
  }
  if first_idx >= classes.length() {
    // 全是 NSM/BN，视为通过（极端情况）
    return true
  }
  let first = classes[first_idx]
  let is_ltr = match first {
    BidiClass::L => true
    _ => false
  }
  let is_rtl = match first {
    BidiClass::R | BidiClass::AL => true
    _ => false
  }
  if !is_ltr && !is_rtl {
    return false
  }
  let mut last_strong_idx = classes.length() - 1
  while last_strong_idx >= 0 {
    match classes[last_strong_idx] {
      BidiClass::NSM => {
        if last_strong_idx == 0 {
          break
        }
        last_strong_idx -= 1
      }
      _ => break
    }
  }
  let last = classes[last_strong_idx]
  let mut has_en : Bool = false
  let mut has_an : Bool = false
  i = 0
  while i < classes.length() {
    match classes[i] {
      BidiClass::EN => has_en = true
      BidiClass::AN => has_an = true
      _ => ()
    }
    i += 1
  }

  // === LTR label 规则 ===
  if is_ltr {
    let mut j = 0
    while j < classes.length() {
      match classes[j] {
        BidiClass::L
        | BidiClass::EN
        | BidiClass::ES
        | BidiClass::CS
        | BidiClass::ET
        | BidiClass::ON
        | BidiClass::NSM => ()
        _ => return false
      }
      j += 1
    }

    // 2) 最后一个非 NSM 字符必须是 L 或 EN
    match last {
      BidiClass::L | BidiClass::EN => ()
      _ => return false
    }
    return true
  }

  // === RTL label 规则 ===
  if is_rtl {
    let mut j = 0
    while j < classes.length() {
      match classes[j] {
        BidiClass::R
        | BidiClass::AL
        | BidiClass::EN
        | BidiClass::AN
        | BidiClass::ES
        | BidiClass::CS
        | BidiClass::ET
        | BidiClass::ON
        | BidiClass::NSM => ()
        _ => return false
      }
      j += 1
    }
    match last {
      BidiClass::R | BidiClass::AL | BidiClass::EN | BidiClass::AN => ()
      _ => return false
    }
    if has_en && has_an {
      return false
    }
    return true
  }
  false
}

/// 针对整个域名（按 label 拆分）做 Bidi 检查：
/// 目前策略：只要任何一个非空 label 违反规则，就认为整个域名有错误。
///|
pub fn check_bidi_domain(labels : Array[String]) -> IdnaErrorList {
  let errs : IdnaErrorList = []
  let mut i = 0
  while i < labels.length() {
    let lbl = labels[i]
    if lbl.length() == 0 {
      i += 1
      continue
    }
    if !check_bidi_label(lbl) {
      errs.push(IdnaError::BidiError)
      // 当前策略：发现一个错误就够了
      return errs
    }
    i += 1
  }
  errs
}
