///|
/// IDNA processing profile.
pub(all) enum IdnaProfile {
  Lookup
  Url
  Std3
  Registration
} derive(Eq, Debug)

///|
/// Error handling for policy-based processing.
pub(all) enum ErrorPolicy {
  FailFast
  Collect
} derive(Eq, Debug)

///|
/// Per-label display decision for `to_display_with_policy`.
pub(all) enum DisplayPreference {
  Unicode
  Ascii
} derive(Eq, Debug)

///|
/// Reusable processing policy. The convenience conversion functions use the
/// `Lookup` profile; named profiles are available for stricter workflows.
pub(all) struct IdnaPolicy {
  profile : IdnaProfile
  error_policy : ErrorPolicy
  transitional_processing : Bool
  check_bidi : Bool
  check_joiners : Bool
  verify_dns_length : Bool
  ignore_invalid_punycode : Bool
} derive(Eq, Debug)

///|
/// WHATWG-compatible lookup policy.
pub fn lookup_policy() -> IdnaPolicy {
  {
    profile: IdnaProfile::Lookup,
    error_policy: ErrorPolicy::FailFast,
    transitional_processing: false,
    check_bidi: true,
    check_joiners: true,
    verify_dns_length: false,
    ignore_invalid_punycode: false,
  }
}

///|
/// WHATWG URL policy with DNS length verification enabled.
pub fn url_policy() -> IdnaPolicy {
  let policy = lookup_policy()
  { ..policy, profile: IdnaProfile::Url, verify_dns_length: true }
}

///|
/// Strict STD3 URL policy.
pub fn std3_policy() -> IdnaPolicy {
  let policy = lookup_policy()
  { ..policy, profile: IdnaProfile::Std3 }
}

///|
/// RFC 5891 registration policy. This is deliberately separate from lookup.
pub fn registration_policy() -> IdnaPolicy {
  let policy = lookup_policy()
  { ..policy, profile: IdnaProfile::Registration, verify_dns_length: true }
}

///|
/// Change how a policy reports invalid Unicode labels.
pub fn IdnaPolicy::with_error_policy(
  self : IdnaPolicy,
  policy : ErrorPolicy,
) -> IdnaPolicy {
  { ..self, error_policy: policy }
}

// Internal IDNA behavior configuration.

///|
priv struct IdnaOptions {
  mut _check_hyphens : Bool
  mut _check_bidi : Bool
  mut _check_joiners : Bool
  mut _use_std3_ascii_rules : Bool
  mut _transitional_processing : Bool
  mut _verify_dns_length : Bool
  mut _ignore_invalid_punycode : Bool
  mut _profile : IdnaProfile
  mut _error_policy : ErrorPolicy
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
    _profile: IdnaProfile::Lookup,
    _error_policy: ErrorPolicy::Collect,
  }
}
