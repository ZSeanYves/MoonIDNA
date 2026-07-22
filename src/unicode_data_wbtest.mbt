///|
test "unicode blob: Bidi @missing defaults and properties" {
  // U+0590 is not explicit in DerivedBidiClass but its @missing range is R.
  let missing_default_is_r = match bidi_class_of(0x0590) {
    BidiClass::R => true
    _ => false
  }
  inspect(missing_default_is_r, content="true")
  inspect(is_mark(0x0308), content="true")
  inspect(is_virama(0x094D), content="true")
}

///|
test "unicode blob: Persian ContextJ joining types" {
  match joining_type_of(0x0647) {
    JoiningType::D => ()
    _ => fail("U+0647 must be Dual_Joining")
  }
  match joining_type_of(0x0627) {
    JoiningType::R => ()
    _ => fail("U+0627 must be Right_Joining")
  }
}
