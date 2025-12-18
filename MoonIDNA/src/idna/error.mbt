// 统一的错误类型（先只定义基本的，后面可以再加）
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
pub type IdnaErrorList = Array[IdnaError]