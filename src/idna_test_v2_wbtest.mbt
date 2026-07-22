///|
fn idna_test_u32(offset : Int) -> Int {
  (idna_test_byte_at(offset).to_int() & 0xFF) |
  ((idna_test_byte_at(offset + 1).to_int() & 0xFF) << 8) |
  ((idna_test_byte_at(offset + 2).to_int() & 0xFF) << 16) |
  ((idna_test_byte_at(offset + 3).to_int() & 0xFF) << 24)
}

///|
fn idna_test_string(offset : Int) -> (String, Int) {
  let length = idna_test_u32(offset)
  let bytes : Array[Byte] = []
  for index in 0..<length {
    bytes.push(idna_test_byte_at(offset + 4 + index))
  }
  (try! @utf8.decode(Bytes::from_array(bytes)), offset + 4 + length)
}

///|
fn assert_conformance_result(
  operation : String,
  line : Int,
  actual : IdnaReport,
  expected_output : String,
  expected_error : Bool,
) -> Unit raise {
  if actual.output != expected_output {
    fail(
      "IdnaTestV2 line " +
      line.to_string() +
      " " +
      operation +
      " output mismatch: " +
      actual.output +
      " != " +
      expected_output,
    )
  }
  if !actual.errors.is_empty() != expected_error {
    fail(
      "IdnaTestV2 line " +
      line.to_string() +
      " " +
      operation +
      " error-status mismatch",
    )
  }
}

///|
test "Unicode 17 IdnaTestV2 full conformance" {
  let count = idna_test_u32(12)
  let mut offset = 20
  for _ in 0..<count {
    let line = idna_test_u32(offset)
    let flags = idna_test_byte_at(offset + 4).to_int() & 0xFF
    offset += 8
    let (source, after_source) = idna_test_string(offset)
    let (unicode_output, after_unicode) = idna_test_string(after_source)
    let (ascii_n_output, after_ascii_n) = idna_test_string(after_unicode)
    let (ascii_t_output, after_ascii_t) = idna_test_string(after_ascii_n)
    offset = after_ascii_t

    assert_conformance_result(
      "ToUnicode",
      line,
      to_unicode_report(source),
      unicode_output,
      (flags & 1) != 0,
    )
    assert_conformance_result(
      "ToASCII-N",
      line,
      to_ascii_report(source),
      ascii_n_output,
      (flags & 2) != 0,
    )
    assert_conformance_result(
      "ToASCII-T",
      line,
      to_ascii_report(source, transitional_processing=true),
      ascii_t_output,
      (flags & 4) != 0,
    )
  }
}
