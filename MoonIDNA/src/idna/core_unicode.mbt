// ToUnicode 的核心实现：后续真正逻辑都放这里
///|
pub fn to_unicode_core(
  domain : StringView,
  opts : IdnaOptions,
) -> Result[String, IdnaErrorList] {

  // TODO: 在这里实现 UTS #46 ToUnicode 逻辑
  Ok(domain.to_string())
}