/// Return the Unicode version embedded in the runtime Blob.

///|
pub fn unicode_version() -> String {
  let version = unicode_version_packed
  ((version >> 16) & 0xFF).to_string() +
  "." +
  ((version >> 8) & 0xFF).to_string() +
  "." +
  (version & 0xFF).to_string()
}

/// Convert a domain to ASCII using UTS #46 lookup processing.
/// Raises the first validation error.

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

/// Convert a domain to ASCII and retain candidate output plus all errors.

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

/// Convert a domain to Unicode using UTS #46 lookup processing.
/// Invalid input is returned unchanged.

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

/// Convert a domain to Unicode and retain candidate output plus all errors.

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

///|
/// Process a domain with an explicit reusable profile. Set `emit_ascii` to
/// `true` for ToASCII and `false` for ToUnicode.
pub fn process_domain_with_policy(
  domain : StringView,
  policy : IdnaPolicy,
  emit_ascii : Bool,
) -> IdnaReport {
  let options = make_options(
    policy.profile == IdnaProfile::Std3 ||
    policy.profile == IdnaProfile::Registration,
    policy.profile == IdnaProfile::Std3 ||
    policy.profile == IdnaProfile::Registration,
    policy.check_bidi,
    policy.check_joiners,
    policy.transitional_processing,
    policy.verify_dns_length || policy.profile == IdnaProfile::Registration,
    policy.ignore_invalid_punycode,
  )
  options._profile = policy.profile
  options._error_policy = policy.error_policy
  process_domain(domain, options, emit_ascii)
}

///|
/// ToASCII using a reusable profile. `FailFast` raises the first error;
/// `Collect` returns the candidate output and leaves full diagnostics available
/// through `process_domain_with_policy`.
pub fn to_ascii_with_policy(
  domain : StringView,
  policy : IdnaPolicy,
) -> String raise IdnaError {
  let report = process_domain_with_policy(domain, policy, true)
  if !report.errors.is_empty() && policy.error_policy == ErrorPolicy::FailFast {
    raise report.errors[0]
  }
  report.output
}

///|
/// ToUnicode using an explicit reusable profile and error policy.
pub fn to_unicode_with_policy(
  domain : StringView,
  policy : IdnaPolicy,
) -> IdnaReport {
  process_domain_with_policy(domain, policy, false)
}

///|
/// Strict RFC 5891 registration conversion.
pub fn registration_to_ascii(domain : StringView) -> String raise IdnaError {
  to_ascii_with_policy(
    domain,
    registration_policy().with_error_policy(ErrorPolicy::FailFast),
  )
}

///|
/// Registration conversion retaining candidate output and all errors.
pub fn registration_to_ascii_report(domain : StringView) -> IdnaReport {
  process_domain_with_policy(domain, registration_policy(), true)
}

///|
/// Emit converted labels in order without building the final domain string.
/// A trailing root dot is reported separately through the returned boolean.
pub fn process_labels_with_policy(
  domain : StringView,
  policy : IdnaPolicy,
  emit_ascii : Bool,
  sink : (String) -> Unit,
) -> (Array[IdnaError], Bool) {
  let options = make_options(
    policy.profile == IdnaProfile::Std3 ||
    policy.profile == IdnaProfile::Registration,
    policy.profile == IdnaProfile::Std3 ||
    policy.profile == IdnaProfile::Registration,
    policy.check_bidi,
    policy.check_joiners,
    policy.transitional_processing,
    policy.verify_dns_length || policy.profile == IdnaProfile::Registration,
    policy.ignore_invalid_punycode,
  )
  options._profile = policy.profile
  options._error_policy = policy.error_policy
  process_domain_to_sink(domain, options, emit_ascii, sink)
}

///|
/// Produce a user-facing domain while selecting Unicode or ASCII per label.
pub fn to_display_with_policy(
  domain : StringView,
  policy : IdnaPolicy,
  select : (String, String) -> DisplayPreference,
) -> IdnaReport {
  let unicode = process_domain_with_policy(domain, policy, false)
  let ascii = process_domain_with_policy(domain, policy, true)
  let errors : Array[IdnaError] = []
  append_errors(errors, unicode.errors)
  append_errors(errors, ascii.errors)
  let unicode_labels = split_labels(unicode.output)
  let ascii_labels = split_labels(ascii.output)
  let output_labels : Array[String] = []
  let count = if unicode_labels.length() < ascii_labels.length() {
    unicode_labels.length()
  } else {
    ascii_labels.length()
  }
  for i in 0..<count {
    match select(unicode_labels[i], ascii_labels[i]) {
      DisplayPreference::Unicode => output_labels.push(unicode_labels[i])
      DisplayPreference::Ascii => output_labels.push(ascii_labels[i])
    }
  }
  let mut output = join_labels(output_labels)
  if has_trailing_dot(unicode.output) {
    output = output + "."
  }
  { output, errors }
}
