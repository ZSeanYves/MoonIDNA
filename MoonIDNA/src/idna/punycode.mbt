///|
pub enum PunycodeError {
  Overflow
  InvalidInput
}

// 暂时占位：后续会实现 RFC 3492 算法
///|
pub fn encode(label : StringView) -> Result[String, PunycodeError] {
  Err(PunycodeError::InvalidInput)
}

///|
pub fn decode(label : StringView) -> Result[String, PunycodeError] {
  Err(PunycodeError::InvalidInput)
}