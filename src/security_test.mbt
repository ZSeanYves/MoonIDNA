///|
test "security: malformed Punycode and input budget vectors" {
  let invalid = [
    "-", "abc_", "abc!", "xn--", "55555577", ".example.org", ".xn--", "0ca24w",
  ]
  for payload in invalid {
    let report = to_unicode_report("xn--" + payload)
    assert_true(!report.errors.is_empty())
  }
  let oversized = to_unicode_report("xn--" + "a".repeat(4097))
  assert_true(!oversized.errors.is_empty())
}

///|
test "security: DNS boundary matrix" {
  let empty = to_ascii_report("", verify_dns_length=true)
  assert_true(!empty.errors.is_empty())
  let one = to_ascii_report("a", verify_dns_length=true)
  assert_true(one.errors.is_empty())
  let sixty_three = to_ascii_report("a".repeat(63), verify_dns_length=true)
  assert_true(sixty_three.errors.is_empty())
  let sixty_four = to_ascii_report("a".repeat(64), verify_dns_length=true)
  assert_true(!sixty_four.errors.is_empty())
  let two_fifty_three = "a".repeat(63) +
    "." +
    "b".repeat(63) +
    "." +
    "c".repeat(63) +
    "." +
    "d".repeat(61)
  assert_eq(two_fifty_three.length(), 253)
  assert_true(
    to_ascii_report(two_fifty_three, verify_dns_length=true).errors.is_empty(),
  )
  let two_fifty_four = two_fifty_three + "."
  assert_eq(two_fifty_four.length(), 254)
  assert_true(
    to_ascii_report(two_fifty_four, verify_dns_length=true).errors.is_empty(),
  )
  let two_fifty_five = "a".repeat(63) +
    "." +
    "b".repeat(63) +
    "." +
    "c".repeat(63) +
    "." +
    "d".repeat(63)
  let too_long = to_ascii_report(two_fifty_five, verify_dns_length=true)
  assert_true(!too_long.errors.is_empty())
}
