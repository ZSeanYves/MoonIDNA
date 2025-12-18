// 题目要求的两个函数：不带配置，走默认配置
///|
pub fn to_ascii(domain : StringView) -> String {
  to_ascii_with_options(domain, options_default())
}

///|
pub fn to_unicode(domain : StringView) -> String {
  to_unicode_with_options(domain, options_default())
}

// 带配置版本（推荐在库内部和测试里使用）
///|
pub fn to_ascii_with_options(domain : StringView, opts : IdnaOptions) -> String {
  // 先用 Result 版本，方便后面扩展错误处理
  match to_ascii_core(domain, opts) {
    Ok(s) => s
    Err(_) =>
      // UTS #46 ToASCII 允许实现选择抛错或返回原字符串；
      // 这里先简单返回原字符串，之后我们可以再细化策略。
      domain.to_string()
  }
}

///|
pub fn to_unicode_with_options(
  domain : StringView,
  opts : IdnaOptions,
) -> String {
  match to_unicode_core(domain, opts) {
    Ok(s) => s
    Err(_) =>
      // ToUnicode 保证总是返回字符串，出错时原样返回比较安全
      domain.to_string()
  }
}
