///|
pub enum IdnaError {
  InvalidCharacter
  InvalidHyphenPosition
  InvalidPunycode
  BidiError
  JoinerError
  LabelTooLong
  DomainTooLong
}

///|
pub enum PunycodeError {
  InvalidInput
  Overflow
  InvalidUtf8
}

pub type IdnaErrorList = Array[IdnaError]