/// Internal helpers shared by behavior white-box tests. They intentionally
/// exercise the same option path as the public convenience functions without
/// keeping deprecated public wrappers in the package.

///|
fn test_options_default() -> IdnaOptions {
  make_options(false, false, true, true, false, false, false)
}

///|
fn test_options_transitional() -> IdnaOptions {
  make_options(false, false, true, true, true, false, false)
}

///|
fn test_to_ascii(domain : StringView, options : IdnaOptions) -> String {
  let report = process_domain(domain, options, true)
  if report.errors.is_empty() {
    report.output
  } else {
    domain.to_owned()
  }
}

///|
fn test_to_unicode(domain : StringView, options : IdnaOptions) -> String {
  let report = process_domain(domain, options, false)
  if report.errors.is_empty() {
    report.output
  } else {
    domain.to_owned()
  }
}
