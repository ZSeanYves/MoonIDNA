/// The policy API must remain behaviorally identical to the compatibility
/// wrappers for the default lookup profile. These vectors are shared with the
/// Rust idna/WHATWG conformance review and protect the public API boundary.

///|
test "policy: lookup API compatibility vectors" {
  let domains = [
    "example.com", "bücher.example", "Straße.de", "xn--bcher-kva.example", "a\u{0308}.example",
    "例え.テスト", "example.com.",
  ]
  for domain in domains {
    assert_eq(
      to_ascii_report(domain),
      process_domain_with_policy(domain, lookup_policy(), true),
    )
    assert_eq(
      to_unicode_report(domain),
      process_domain_with_policy(domain, lookup_policy(), false),
    )
  }
}
