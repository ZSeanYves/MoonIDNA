// 不带配置，走默认配置
///|
pub fn to_ascii(domain : StringView) -> String raise @buf.Utf8DecodeError {
  to_ascii_with_options(domain, options_default())
}

///|
pub fn to_unicode(domain : StringView) -> String raise @buf.Utf8DecodeError {
  to_unicode_with_options(domain, options_default())
}

///|
/// ToASCII（transitional 模式），用于老数据兼容：
/// - 打开 transitional_processing（例如 ß -> ss）
/// - 其他选项使用 options_transitional 的默认配置
pub fn to_ascii_transitional(domain : StringView) -> String raise @buf.Utf8DecodeError {
  let opts = options_transitional()
  to_ascii_with_options(domain, opts)
}

///|
/// ToUnicode（transitional 模式），语义与 to_ascii_transitional 对应。
pub fn to_unicode_transitional(domain : StringView) -> String raise @buf.Utf8DecodeError {
  let opts = options_transitional()
  to_unicode_with_options(domain, opts)
}

// 带配置版本（推荐在库内部和测试里使用）
///|
pub fn to_ascii_with_options(domain : StringView, opts : IdnaOptions) -> String raise @buf.Utf8DecodeError {
  // 先用 Result 版本，方便后面扩展错误处理
  match to_ascii_core(domain, opts) {
    Ok(s) => s
    Err(_) =>
      // UTS #46 ToASCII 允许实现选择抛错或返回原字符串；
      domain.to_string()
  }
}

///|
pub fn to_unicode_with_options(
  domain : StringView,
  opts : IdnaOptions,
) -> String raise @buf.Utf8DecodeError {
  match to_unicode_core(domain, opts) {
    Ok(s) => s
    Err(_) =>
      // ToUnicode 保证总是返回字符串，出错时原样返回比较安全
      domain.to_string()
  }
}

