///|
test "uts46: mapped separator splits labels before punycode" {
  inspect(try! to_ascii("bücher。example"), content="xn--bcher-kva.example")
}

///|
test "uts46: NFC composes mapped domain" {
  inspect(
    try! to_ascii("bu\u{0308}cher.example"),
    content="xn--bcher-kva.example",
  )
  inspect(to_unicode("xn--bcher-kva.example"), content="bücher.example")
}

///|
test "uts46: disallowed codepoint is observable" {
  let report = to_ascii_report("\u{E000}.example")
  @debug.debug_inspect(report.errors, content="[InvalidCharacter]")
  try to_ascii("\u{E000}.example") catch {
    error => @debug.debug_inspect(error, content="InvalidCharacter")
  } noraise {
    _ => fail("expected ToASCII to reject a disallowed codepoint")
  }
}

///|
test "uts46: empty and leading-mark labels are observable" {
  let empty = to_ascii_report(".example")
  @debug.debug_inspect(empty.errors, content="[]")
  let leading_mark = to_ascii_report("\u{0308}a.example")
  @debug.debug_inspect(leading_mark.errors, content="[LeadingMark]")
}

///|
test "uts46: invalid A-label roundtrip is rejected" {
  let report = to_unicode_report("xn--example-")
  @debug.debug_inspect(report.errors, content="[InvalidAlabel]")
  inspect(to_unicode("xn--example-"), content="xn--example-")
}

///|
test "uts46: Bidi checks are conditional at domain level" {
  inspect(try! to_ascii("123.example"), content="123.example")
  let report = to_ascii_report("aא.example")
  @debug.debug_inspect(report.errors, content="[BidiError]")
}

///|
test "uts46: strict hyphen and DNS length checks" {
  let hyphen = to_ascii_report("ab--cd.example", check_hyphens=true)
  @debug.debug_inspect(hyphen.errors, content="[InvalidHyphenPosition]")
  let long_label = "a".repeat(64)
  let length = to_ascii_report(long_label + ".example", verify_dns_length=true)
  @debug.debug_inspect(length.errors, content="[LabelTooLong]")
}

///|
test "uts46: Persian ZWNJ satisfies ContextJ" {
  let report = to_unicode_report(
    "\u{0646}\u{0627}\u{0645}\u{0647}\u{200C}\u{0627}\u{06CC}",
  )
  @debug.debug_inspect(report.errors, content="[]")
}

///|
test "unicode data exposes its pinned version" {
  inspect(unicode_version(), content="17.0.0")
}
