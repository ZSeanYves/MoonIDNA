// --- 基础用例：纯 ASCII 域名应该原样通过 ---

///|
test "api: ascii passthrough" {
  let input = "example.com"
  let opts = test_options_default()

  let out_ascii = test_to_ascii(input, opts)
  let out_unicode = test_to_unicode(input, opts)

  assert_eq(out_ascii, "example.com")
  assert_eq(out_unicode, "example.com")
}

// --- 非 ASCII 域名：应被 punycode 到 ASCII，并能正确回转 ---

///|
test "api: non-ascii punycode roundtrip" {
  let input = "bücher.example"
  let opts = test_options_default()

  let out_ascii = test_to_ascii(input, opts)
  let out_unicode = test_to_unicode(out_ascii, opts)

  // bücher -> xn--bcher-kva
  assert_eq(out_ascii, "xn--bcher-kva.example")
  assert_eq(out_unicode, input.to_string())
}

// --- Punycode 基本测试 ---

///|
test "punycode: encode buecher" {
  let s = "bücher"
  let enc = match encode(s) {
    Ok(v) => v
    Err(_) => {
      let a = true
      assert_eq(a, false)
      "".to_string()
    }
  }
  // RFC 3492 / 各种资料中的标准结果：bücher -> bcher-kva
  assert_eq(enc, "bcher-kva")
}

///|
test "punycode: decode bcher-kva" {
  let enc = "bcher-kva"
  let dec = match decode(enc) {
    Ok(v) => v
    Err(_) => {
      let a = true
      assert_eq(a, false)
      "".to_string()
    }
  }
  assert_eq(dec, "bücher")
}

///|
test "api: ascii case fold" {
  let opts = test_options_default()
  let input = "EXAMPLE.Com"
  let out_ascii = test_to_ascii(input, opts)
  let out_unicode = test_to_unicode(input, opts)
  assert_eq(out_ascii, "example.com")
  assert_eq(out_unicode, "example.com")
}

///|
test "api: transitional sharp s mapping" {
  let input = "Straße.de"

  let opts_default = test_options_default()
  let out_default = test_to_ascii(input, opts_default)

  let opts_tr = test_options_transitional()
  let out_tr = test_to_ascii(input, opts_tr)

  // 默认模式：含非 ASCII，走 punycode
  assert_eq(out_default, "xn--strae-oqa.de")

  // transitional 模式：ß 被映射为 ss，不再 punycode
  assert_eq(out_tr, "strasse.de")
}

///|
test "api: ignore invalid punycode" {
  // payload = "abc_"，下划线不是 punycode 允许的字符，会触发 decode 失败
  let input = "xn--abc_"

  let opts_strict = test_options_default()
  let strict_res = test_to_unicode(input, opts_strict)
  // 严格模式：解析失败，记录错误，但输出按我们当前实现仍保持原 label
  assert_eq(strict_res, input.to_string())

  let opts_ignore = test_options_default()
  opts_ignore._ignore_invalid_punycode = true
  let ignore_res = test_to_unicode(input, opts_ignore)
  // 忽略模式：同样返回原字符串，只是不会记录 InvalidPunycode
  assert_eq(ignore_res, input.to_string())
}

///|
test "api: top-level api basic" {
  let ascii = to_ascii("bücher.example")
  let uni = to_unicode("xn--bcher-kva.example")

  assert_eq(ascii, "xn--bcher-kva.example")
  assert_eq(uni, "bücher.example")
}

///|
test "api: ascii trailing dot preserved" {
  let input = "example.com."
  let opts = test_options_default()

  let out_ascii = test_to_ascii(input, opts)
  let out_unicode = test_to_unicode(out_ascii, opts)

  assert_eq(out_ascii, "example.com.")
  assert_eq(out_unicode, "example.com.")
}

///|
test "api: non-ascii trailing dot preserved" {
  let input = "bücher.example."
  let opts = test_options_default()

  let out_ascii = test_to_ascii(input, opts)
  let out_unicode = test_to_unicode(out_ascii, opts)

  assert_eq(out_ascii, "xn--bcher-kva.example.")
  assert_eq(out_unicode, "bücher.example.")
}

///|
test "api: leading dot preserved ascii" {
  let input = ".example.com"
  let opts = test_options_default()

  let out_ascii = test_to_ascii(input, opts)
  let out_unicode = test_to_unicode(out_ascii, opts)

  assert_eq(out_ascii, ".example.com")
  assert_eq(out_unicode, ".example.com")
}

///|
test "api: leading empty label with DNS verification disabled" {
  let input = ".bücher.example"
  let opts = test_options_default()

  let out_ascii = test_to_ascii(input, opts)
  let out_unicode = test_to_unicode(out_ascii, opts)

  assert_eq(out_ascii, ".xn--bcher-kva.example")
  assert_eq(out_unicode, ".xn--bcher-kva.example")
}

///|
test "api: mixed labels roundtrip" {
  let input = "www.bücher.example"
  let opts = test_options_default()

  let out_ascii = test_to_ascii(input, opts)
  let out_unicode = test_to_unicode(out_ascii, opts)

  assert_eq(out_unicode, input.to_string())
}

///|
test "api: punycode prefix case-insensitive" {
  let opts = test_options_default()

  let lower = test_to_unicode("xn--bcher-kva.example", opts)
  let upper = test_to_unicode("XN--BCHER-KVA.EXAMPLE", opts)

  assert_eq(lower, "bücher.example")
  // ASCII 部分会被统一小写，punycode 前缀大小写不敏感
  assert_eq(upper, "bücher.example")
}

///|
test "punycode: encode ascii-only label unchanged" {
  let s = "example"
  let enc = match encode(s) {
    Ok(v) => v
    Err(_) => {
      let a = true
      assert_eq(a, false)
      "".to_string()
    }
  }
  assert_eq(enc, "example")
}

///|
test "punycode: encode empty label" {
  let s = ""
  let enc = match encode(s) {
    Ok(v) => v
    Err(_) => {
      let a = true
      assert_eq(a, false)
      "".to_string()
    }
  }
  assert_eq(enc, "")
}

///|
test "punycode: decode empty label" {
  let enc = ""
  let dec = match decode(enc) {
    Ok(v) => v
    Err(_) => {
      let a = true
      assert_eq(a, false)
      "".to_string()
    }
  }
  assert_eq(dec, "")
}

///|
test "punycode: supplementary-plane roundtrip" {
  let input = "😀"
  let encoded = match encode(input) {
    Ok(value) => value
    Err(_) => fail("supplementary-plane Punycode encoding failed")
  }
  assert_eq(encoded, "e28h")
  let decoded = match decode(encoded) {
    Ok(value) => value
    Err(_) => fail("supplementary-plane Punycode decoding failed")
  }
  assert_eq(decoded, input)
}
