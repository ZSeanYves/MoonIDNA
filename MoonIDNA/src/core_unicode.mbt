// === 对外：ToUnicode 核心逻辑 ===
///|
pub fn to_unicode_core(
  domain : StringView,
  opts : IdnaOptions,
) -> Result[String, IdnaErrorList] raise @buf.Utf8DecodeError {
  let labels = split_labels(domain)
  let trailing = has_trailing_dot(domain)
  let out_labels : Array[String] = []
  let all_errs : IdnaErrorList = []
  let mut i = 0
  while i < labels.length() {
    let raw_lbl = labels[i]
    if raw_lbl.length() == 0 {
      out_labels.push(raw_lbl)
      i += 1
      continue
    }
    if is_punycode_label(raw_lbl) {
      let payload = punycode_payload(raw_lbl)
      let mut decoded = raw_lbl
      let mut had_puny_err = false
      match decode(payload) {
        Ok(v) => decoded = v
        Err(_) =>
          // 解析失败：根据 _ignore_invalid_punycode 决定是否记录错误
          had_puny_err = true
        // decoded 保持 raw_lbl，不按 punycode 解释
      }
      if had_puny_err && !opts._ignore_invalid_punycode {
        all_errs.push(IdnaError::InvalidPunycode)
      }

      // 解码后（或失败时的原始 label）统一走映射 + 校验
      let mapped = map_label(decoded, opts)
      let lbl = mapped.value
      let label_errs = validate_label_all(lbl, opts)
      let mut j = 0
      while j < label_errs.length() {
        all_errs.push(label_errs[j])
        j += 1
      }
      out_labels.push(lbl)
    } else {
      // 非 punycode label：同样跑映射 + 校验
      let mapped = map_label(raw_lbl, opts)
      let lbl = mapped.value
      let label_errs = validate_label_all(lbl, opts)
      let mut j = 0
      while j < label_errs.length() {
        all_errs.push(label_errs[j])
        j += 1
      }
      out_labels.push(lbl)
    }
    i += 1
  }
  let mut result = join_labels(out_labels)
  if trailing {
    result = result + "."
  }
  let _ = all_errs
  Ok(result)
}
