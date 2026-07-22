///|
test "policy: reusable profiles and error policy" {
  let url = url_policy()
  let report = to_unicode_with_policy("xn--bcher-kva.example", url)
  assert_true(report.errors.is_empty())
  assert_eq(report.output, "bücher.example")
  let collect = lookup_policy().with_error_policy(ErrorPolicy::Collect)
  let candidate = to_ascii_with_policy("\u{E000}.example", collect)
  assert_true(!candidate.is_empty())
}

///|
test "policy: label sink and display selector" {
  let labels : Array[String] = []
  let (errors, trailing_dot) = process_labels_with_policy(
    "bücher.example.",
    lookup_policy(),
    true,
    fn(label) { labels.push(label) },
  )
  assert_true(errors.is_empty())
  assert_true(trailing_dot)
  assert_eq(labels, ["xn--bcher-kva", "example"])
  let display = to_display_with_policy(
    "xn--bcher-kva.example",
    lookup_policy(),
    fn(unicode, _ascii) {
      if unicode == "bücher" {
        DisplayPreference::Unicode
      } else {
        DisplayPreference::Ascii
      }
    },
  )
  assert_true(display.errors.is_empty())
  assert_eq(display.output, "bücher.example")
}
