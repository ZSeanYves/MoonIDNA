///|
pub fn to_ascii_core(
  domain : StringView,
  opts : IdnaOptions,
) -> Result[String, IdnaErrorList] {

  // TODO: 后续在这里实现完整的 UTS #46 ToASCII 逻辑
  // 目前先留一个最简单的占位实现：直接返回原始字符串
  Ok(domain.to_string())
}