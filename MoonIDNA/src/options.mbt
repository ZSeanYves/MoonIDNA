// IDNA 行为配置
///|
pub(all) struct IdnaOptions {
  mut _check_hyphens : Bool
  mut _check_bidi : Bool
  mut _check_joiners : Bool
  mut _use_std3_ascii_rules : Bool
  mut _transitional_processing : Bool
  mut _verify_dns_length : Bool
  mut _ignore_invalid_punycode : Bool
}

// 一些方便构造的辅助函数
///|
pub fn options_default() -> IdnaOptions {
  // 对齐 WHATWG URL 解析的大致行为：非过渡模式、校验长度
  let a = {
    _check_hyphens: true,
    _check_bidi: true,
    _check_joiners: true,
    _use_std3_ascii_rules: false,
    _transitional_processing: false,
    _verify_dns_length: true,
    _ignore_invalid_punycode: false,
  }
  a
}

// 更严格的“注册场景”配置（未来如果需要）
///|
pub fn options_strict_registration() -> IdnaOptions {
  let a = {
    _check_hyphens: true,
    _check_bidi: true,
    _check_joiners: true,
    _use_std3_ascii_rules: true,
    _transitional_processing: false,
    _verify_dns_length: true,
    _ignore_invalid_punycode: false,
  }
  a
}

///|
pub fn options_transitional() -> IdnaOptions {
  // 过渡模式：主要用在老数据兼容场景，打开 _transitional_processing
  let a = {
    _check_hyphens: true,
    _check_bidi: true,
    _check_joiners: true,
    _use_std3_ascii_rules: false,
    _transitional_processing: true,
    _verify_dns_length: true,
    _ignore_invalid_punycode: false,
  }
  a
}


