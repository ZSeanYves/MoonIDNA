// IDNA 行为配置
///|
pub struct IdnaOptions {
  check_hyphens : Bool
  check_bidi : Bool
  check_joiners : Bool
  use_std3_ascii_rules : Bool
  transitional_processing : Bool
  verify_dns_length : Bool
  ignore_invalid_punycode : Bool
}

// 一些方便构造的辅助函数
///|
pub fn options_default() -> IdnaOptions {
  // 对齐 WHATWG URL 解析的大致行为：非过渡模式、校验长度
  let a = {
    check_hyphens: true,
    check_bidi: true,
    check_joiners: true,
    use_std3_ascii_rules: false,
    transitional_processing: false,
    verify_dns_length: true,
    ignore_invalid_punycode: false,
  }
  a
}

// 更严格的“注册场景”配置（未来如果需要）
///|
pub fn options_strict_registration() -> IdnaOptions {
  let a = {
    check_hyphens: true,
    check_bidi: true,
    check_joiners: true,
    use_std3_ascii_rules: true,
    transitional_processing: false,
    verify_dns_length: true,
    ignore_invalid_punycode: false,
  }
  a
}


