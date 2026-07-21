///|
pub suberror IdnaError {
  InvalidCharacter
  InvalidHyphenPosition
  InvalidPunycode
  InvalidAlabel
  EmptyLabel
  LeadingMark
  DotInLabel
  BidiError
  JoinerError
  LabelTooLong
  DomainTooLong
} derive(Eq, Debug)

///|
priv enum PunycodeError {
  InvalidInput
  Overflow
  InvalidUtf8
}

///|
type IdnaErrorList = Array[IdnaError]

///|
pub(all) struct IdnaReport {
  output : String
  errors : IdnaErrorList
} derive(Eq, Debug)
