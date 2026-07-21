///|
pub fn unicode_version() -> String {
  let version = unicode_version_packed
  ((version >> 16) & 0xFF).to_string() +
  "." +
  ((version >> 8) & 0xFF).to_string() +
  "." +
  (version & 0xFF).to_string()
}

///|
pub fn to_ascii(
  domain : StringView,
  use_std3_ascii_rules? : Bool = false,
  check_hyphens? : Bool = false,
  check_bidi? : Bool = true,
  check_joiners? : Bool = true,
  transitional_processing? : Bool = false,
  verify_dns_length? : Bool = false,
  ignore_invalid_punycode? : Bool = false,
) -> String raise IdnaError {
  let report = to_ascii_report(
    domain,
    use_std3_ascii_rules~,
    check_hyphens~,
    check_bidi~,
    check_joiners~,
    transitional_processing~,
    verify_dns_length~,
    ignore_invalid_punycode~,
  )
  if !report.errors.is_empty() {
    raise report.errors[0]
  }
  report.output
}

///|
pub fn to_ascii_report(
  domain : StringView,
  use_std3_ascii_rules? : Bool = false,
  check_hyphens? : Bool = false,
  check_bidi? : Bool = true,
  check_joiners? : Bool = true,
  transitional_processing? : Bool = false,
  verify_dns_length? : Bool = false,
  ignore_invalid_punycode? : Bool = false,
) -> IdnaReport {
  process_domain(
    domain,
    make_options(
      use_std3_ascii_rules, check_hyphens, check_bidi, check_joiners, transitional_processing,
      verify_dns_length, ignore_invalid_punycode,
    ),
    true,
  )
}

///|
pub fn to_unicode(
  domain : StringView,
  use_std3_ascii_rules? : Bool = false,
  check_hyphens? : Bool = false,
  check_bidi? : Bool = true,
  check_joiners? : Bool = true,
  transitional_processing? : Bool = false,
  ignore_invalid_punycode? : Bool = false,
) -> String {
  let report = to_unicode_report(
    domain,
    use_std3_ascii_rules~,
    check_hyphens~,
    check_bidi~,
    check_joiners~,
    transitional_processing~,
    ignore_invalid_punycode~,
  )
  if report.errors.is_empty() {
    report.output
  } else {
    domain.to_owned()
  }
}

///|
pub fn to_unicode_report(
  domain : StringView,
  use_std3_ascii_rules? : Bool = false,
  check_hyphens? : Bool = false,
  check_bidi? : Bool = true,
  check_joiners? : Bool = true,
  transitional_processing? : Bool = false,
  ignore_invalid_punycode? : Bool = false,
) -> IdnaReport {
  process_domain(
    domain,
    make_options(
      use_std3_ascii_rules, check_hyphens, check_bidi, check_joiners, transitional_processing,
      false, ignore_invalid_punycode,
    ),
    false,
  )
}
