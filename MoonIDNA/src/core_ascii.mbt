// === 对外：ToASCII 核心逻辑 ===
///|
pub fn to_ascii_core(
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

    // 先做基础映射（ASCII 大写 -> 小写）
    let mapped = map_label(raw_lbl, opts)
    let lbl = mapped.value
    // 映射阶段产生的错误目前忽略（后续接入 UTS #46 完整表再用）
    // 现在只用 validate 层
    let label_errs = validate_label_all(lbl, opts)
    // 聚合错误
    let mut j = 0
    while j < label_errs.length() {
      all_errs.push(label_errs[j])
      j += 1
    }
    if is_all_ascii(lbl) {
      out_labels.push(lbl)
    } else {
      let ascii_label = match encode(lbl) {
        Ok(v) => {
          let mut s = "xn--".to_string()
          s = s + v
          s
        }
        Err(_) =>
          // 暂时策略：编码失败就保留映射后的 label
          lbl.to_string()
      }
      out_labels.push(ascii_label)
    }
    i += 1
  }
  let mut result = join_labels(out_labels)
  if trailing {
    result = result + "."
  }

  // 域名级别的 DNS 长度检查
  let dns_errs = validate_domain_all(result, opts)
  let mut k = 0
  while k < dns_errs.length() {
    all_errs.push(dns_errs[k])
    k += 1
  }

  // 暂时：无论是否有错误都返回 Ok(result)，错误列表先不对外暴露
  let _ = all_errs
  Ok(result)
}
