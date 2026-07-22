/// Errors reported by UTS #46 and the strict registration profile.

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
  ContextOError
  UnassignedCodePoint
  RegistrationError
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

/// Candidate output and de-duplicated validation errors.

///|
pub(all) struct IdnaReport {
  output : String
  errors : IdnaErrorList
} derive(Eq, Debug)
