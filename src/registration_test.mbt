///|
test "registration: ContextO middle dot" {
  let valid = registration_to_ascii_report("l·l")
  assert_true(valid.errors.is_empty())
  let invalid = registration_to_ascii_report("·ll")
  assert_true(!invalid.errors.is_empty())
}

///|
test "registration: ContextO script and digit rules" {
  let katakana = registration_to_ascii_report("カ・ナ")
  assert_true(katakana.errors.is_empty())
  let greek = registration_to_ascii_report("α\u{0375}")
  assert_true(greek.errors.is_empty())
  let hebrew = registration_to_ascii_report("א\u{05F3}")
  assert_true(hebrew.errors.is_empty())
  let arabic_digits = registration_to_ascii_report("ا\u{0661}\u{0662}")
  assert_true(arabic_digits.errors.is_empty())
  let invalid_katakana = registration_to_ascii_report("a·b")
  assert_true(!invalid_katakana.errors.is_empty())
  let mixed_digits = registration_to_ascii_report("\u{0661}\u{06F1}")
  assert_true(!mixed_digits.errors.is_empty())
}

///|
test "registration: ContextJ requires RFC 5892 context" {
  let valid = registration_to_ascii_report(
    "\u{0646}\u{0627}\u{0645}\u{0647}\u{200C}\u{0627}\u{06CC}",
  )
  assert_true(valid.errors.is_empty())
  let invalid = registration_to_ascii_report("a\u{200C}b")
  assert_true(!invalid.errors.is_empty())
}

///|
test "registration: rejects unassigned code points" {
  let report = registration_to_ascii_report("a\u{0378}")
  assert_true(!report.errors.is_empty())
}

///|
test "registration: no compatibility mapping and NFC is required" {
  let compatibility = registration_to_ascii_report("ａ.example")
  assert_true(!compatibility.errors.is_empty())
  let non_nfc = registration_to_ascii_report("a\u{0308}.example")
  assert_true(!non_nfc.errors.is_empty())
}
