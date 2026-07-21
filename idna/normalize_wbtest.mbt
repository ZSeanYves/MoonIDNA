///|
test "NFC: canonical composition" {
  inspect(normalize_nfc("A\u{030A}"), content="Å")
}

///|
test "NFC: canonical ordering before composition" {
  inspect(normalize_nfc("a\u{0315}\u{0300}"), content="à\u{0315}")
}

///|
test "NFC: algorithmic Hangul composition" {
  inspect(normalize_nfc("\u{1100}\u{1161}\u{11A8}"), content="각")
}
