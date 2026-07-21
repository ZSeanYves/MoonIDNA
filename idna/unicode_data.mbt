// Direct, allocation-free access to the versioned Unicode data blob.

///|
priv enum MappingStatus {
  Valid
  Ignored
  Mapped
  Deviation
  Disallowed
  DisallowedStd3Valid
  DisallowedStd3Mapped
}

///|
priv enum BidiClass {
  L
  R
  AL
  EN
  ES
  ET
  AN
  CS
  NSM
  BN
  ON
  LRE
  LRO
  RLE
  RLO
  PDF
  LRI
  RLI
  FSI
  PDI
  S
  WS
  B
}

///|
priv enum JoiningType {
  U
  L
  R
  D
  T
  C
}

///|
fn blob_u16(offset : Int) -> Int {
  (unicode_data_byte_at(offset).to_int() & 0xFF) |
  ((unicode_data_byte_at(offset + 1).to_int() & 0xFF) << 8)
}

///|
fn blob_u24(offset : Int) -> Int {
  (unicode_data_byte_at(offset).to_int() & 0xFF) |
  ((unicode_data_byte_at(offset + 1).to_int() & 0xFF) << 8) |
  ((unicode_data_byte_at(offset + 2).to_int() & 0xFF) << 16)
}

///|
fn blob_u32(offset : Int) -> Int {
  (unicode_data_byte_at(offset).to_int() & 0xFF) |
  ((unicode_data_byte_at(offset + 1).to_int() & 0xFF) << 8) |
  ((unicode_data_byte_at(offset + 2).to_int() & 0xFF) << 16) |
  ((unicode_data_byte_at(offset + 3).to_int() & 0xFF) << 24)
}

///|
let mapping_stage1_offset : Int = blob_u32(16)

///|
let mapping_stage2_offset : Int = blob_u32(20)

///|
let mapping_descriptor_offset : Int = blob_u32(28)

///|
let mapping_scalar_offset : Int = blob_u32(36)

///|
let property_stage1_offset : Int = blob_u32(44)

///|
let property_stage2_offset : Int = blob_u32(48)

///|
let decomposition_stage1_offset : Int = blob_u32(64)

///|
let decomposition_stage2_offset : Int = blob_u32(68)

///|
let decomposition_descriptor_offset : Int = blob_u32(76)

///|
let decomposition_scalar_offset : Int = blob_u32(84)

///|
let composition_offset : Int = blob_u32(92)

///|
let composition_count : Int = blob_u32(96)

///|
let unicode_version_packed : Int = blob_u32(100)

///|
fn mapping_token_of(codepoint : Int) -> Int {
  if codepoint < 0 || codepoint > 0x10FFFF {
    return 4 // Disallowed
  }
  let page = blob_u16(mapping_stage1_offset + (codepoint >> 8) * 2)
  blob_u16(mapping_stage2_offset + (page * 256 + (codepoint & 0xFF)) * 2)
}

///|
fn mapping_status_of(token : Int) -> MappingStatus {
  match token & 0x7 {
    0 => MappingStatus::Valid
    1 => MappingStatus::Ignored
    2 => MappingStatus::Mapped
    3 => MappingStatus::Deviation
    4 => MappingStatus::Disallowed
    5 => MappingStatus::DisallowedStd3Valid
    _ => MappingStatus::DisallowedStd3Mapped
  }
}

///|
fn mapping_descriptor_of(token : Int) -> Int {
  blob_u32(mapping_descriptor_offset + (token >> 3) * 4)
}

///|
fn mapping_length_of(descriptor : Int) -> Int {
  descriptor & 0xFF
}

///|
fn mapping_scalar_at(descriptor : Int, index : Int) -> Int {
  let scalar_index = (descriptor >> 8) + index
  blob_u24(mapping_scalar_offset + scalar_index * 3)
}

///|
fn property_token_of(codepoint : Int) -> Int {
  if codepoint < 0 || codepoint > 0x10FFFF {
    return 0
  }
  let page = blob_u16(property_stage1_offset + (codepoint >> 8) * 2)
  blob_u32(property_stage2_offset + (page * 256 + (codepoint & 0xFF)) * 4)
}

///|
fn decomposition_descriptor_of(codepoint : Int) -> Int {
  if codepoint < 0 || codepoint > 0x10FFFF {
    return 0
  }
  let page = blob_u16(decomposition_stage1_offset + (codepoint >> 8) * 2)
  let sequence = blob_u16(
    decomposition_stage2_offset + (page * 256 + (codepoint & 0xFF)) * 2,
  )
  blob_u32(decomposition_descriptor_offset + sequence * 4)
}

///|
fn decomposition_length_of(descriptor : Int) -> Int {
  descriptor & 0xFF
}

///|
fn decomposition_scalar_at(descriptor : Int, index : Int) -> Int {
  let scalar_index = (descriptor >> 8) + index
  blob_u24(decomposition_scalar_offset + scalar_index * 3)
}

///|
fn canonical_combining_class_of(codepoint : Int) -> Int {
  (property_token_of(codepoint) >> 9) & 0xFF
}

///|
fn canonical_composition_of(starter : Int, combining : Int) -> Int {
  let mut low = 0
  let mut high = composition_count
  while low < high {
    let middle = (low + high) / 2
    let offset = composition_offset + middle * 12
    let candidate_starter = blob_u32(offset)
    let candidate_combining = blob_u32(offset + 4)
    if starter < candidate_starter ||
      (starter == candidate_starter && combining < candidate_combining) {
      high = middle
    } else if starter > candidate_starter ||
      (starter == candidate_starter && combining > candidate_combining) {
      low = middle + 1
    } else {
      return blob_u32(offset + 8)
    }
  }
  -1
}

///|
fn bidi_class_of(codepoint : Int) -> BidiClass {
  match property_token_of(codepoint) & 0x1F {
    0 => BidiClass::L
    1 => BidiClass::R
    2 => BidiClass::AL
    3 => BidiClass::EN
    4 => BidiClass::ES
    5 => BidiClass::ET
    6 => BidiClass::AN
    7 => BidiClass::CS
    8 => BidiClass::NSM
    9 => BidiClass::BN
    10 => BidiClass::ON
    11 => BidiClass::LRE
    12 => BidiClass::LRO
    13 => BidiClass::RLE
    14 => BidiClass::RLO
    15 => BidiClass::PDF
    16 => BidiClass::LRI
    17 => BidiClass::RLI
    18 => BidiClass::FSI
    19 => BidiClass::PDI
    20 => BidiClass::S
    21 => BidiClass::WS
    _ => BidiClass::B
  }
}

///|
fn joining_type_of(codepoint : Int) -> JoiningType {
  match (property_token_of(codepoint) >> 5) & 0x7 {
    1 => JoiningType::L
    2 => JoiningType::R
    3 => JoiningType::D
    4 => JoiningType::T
    5 => JoiningType::C
    _ => JoiningType::U
  }
}

///|
fn is_virama(codepoint : Int) -> Bool {
  (property_token_of(codepoint) & (1 << 8)) != 0
}

///|
fn is_mark(codepoint : Int) -> Bool {
  (property_token_of(codepoint) & (1 << 17)) != 0
}
