// IDNA 行为配置

///|
priv struct IdnaOptions {
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
fn make_options(
  use_std3_ascii_rules : Bool,
  check_hyphens : Bool,
  check_bidi : Bool,
  check_joiners : Bool,
  transitional_processing : Bool,
  verify_dns_length : Bool,
  ignore_invalid_punycode : Bool,
) -> IdnaOptions {
  {
    _check_hyphens: check_hyphens,
    _check_bidi: check_bidi,
    _check_joiners: check_joiners,
    _use_std3_ascii_rules: use_std3_ascii_rules,
    _transitional_processing: transitional_processing,
    _verify_dns_length: verify_dns_length,
    _ignore_invalid_punycode: ignore_invalid_punycode,
  }
}

///|
fn options_default() -> IdnaOptions {
  make_options(false, false, true, true, false, false, false)
}

// 更严格的“注册场景”配置（未来如果需要）

///|
fn options_transitional() -> IdnaOptions {
  make_options(false, false, true, true, true, false, false)
}
