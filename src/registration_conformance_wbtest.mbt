/// RFC 5892 derived-property corpus validation for the Unicode 17 Blob.
/// The counts cover all 1,114,112 Unicode code points represented by
/// Idna2008.txt, including every CONTEXTO and CONTEXTJ assignment.

///|
test "registration corpus: Unicode 17 IDNA2008 categories" {
  let mut pvalid = 0
  let mut contextj = 0
  let mut contexto = 0
  let mut disallowed = 0
  let mut unassigned = 0
  for cp in 0..<=0x10FFFF {
    match idna2008_category_of(cp) {
      Idna2008Category::Pvalid => pvalid += 1
      Idna2008Category::Contextj => contextj += 1
      Idna2008Category::Contexto => contexto += 1
      Idna2008Category::Disallowed => disallowed += 1
      Idna2008Category::Unassigned => unassigned += 1
    }
  }
  assert_eq(pvalid, 143208)
  assert_eq(contextj, 2)
  assert_eq(contexto, 25)
  assert_eq(disallowed, 156213)
  assert_eq(unassigned, 814664)
}

///|
test "registration corpus: every contextual assignment is represented" {
  let contextj_codepoints = [0x200C, 0x200D]
  for cp in contextj_codepoints {
    assert_true(is_contextj_codepoint(cp))
  }
  let contexto_codepoints = [
    0xB7, 0x375, 0x5F3, 0x5F4, 0x660, 0x661, 0x662, 0x663, 0x664, 0x665, 0x666, 0x667,
    0x668, 0x669, 0x6F0, 0x6F1, 0x6F2, 0x6F3, 0x6F4, 0x6F5, 0x6F6, 0x6F7, 0x6F8,
    0x6F9, 0x30FB,
  ]
  for cp in contexto_codepoints {
    assert_true(is_contexto_codepoint(cp))
  }
}

///|
fn is_contextj_codepoint(cp : Int) -> Bool {
  match idna2008_category_of(cp) {
    Idna2008Category::Contextj => true
    _ => false
  }
}

///|
fn is_contexto_codepoint(cp : Int) -> Bool {
  match idna2008_category_of(cp) {
    Idna2008Category::Contexto => true
    _ => false
  }
}
