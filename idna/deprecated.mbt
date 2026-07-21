///|
fn to_ascii_with_options(domain : StringView, options : IdnaOptions) -> String {
  let report = process_domain(domain, options, true)
  if report.errors.is_empty() {
    report.output
  } else {
    domain.to_owned()
  }
}

///|
fn to_unicode_with_options(
  domain : StringView,
  options : IdnaOptions,
) -> String {
  let report = process_domain(domain, options, false)
  if report.errors.is_empty() {
    report.output
  } else {
    domain.to_owned()
  }
}

///|
#deprecated("Pass transitional_processing=true to to_ascii")
pub fn to_ascii_transitional(domain : StringView) -> String {
  let options = options_default()
  options._transitional_processing = true
  to_ascii_with_options(domain, options)
}

///|
#deprecated("Pass transitional_processing=true to to_unicode")
pub fn to_unicode_transitional(domain : StringView) -> String {
  to_unicode_with_options(domain, options_transitional())
}
