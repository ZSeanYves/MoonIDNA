///|
const HANGUL_S_BASE = 0xAC00

///|
const HANGUL_L_BASE = 0x1100

///|
const HANGUL_V_BASE = 0x1161

///|
const HANGUL_T_BASE = 0x11A7

///|
const HANGUL_L_COUNT = 19

///|
const HANGUL_V_COUNT = 21

///|
const HANGUL_T_COUNT = 28

///|
const HANGUL_N_COUNT : Int = HANGUL_V_COUNT * HANGUL_T_COUNT

///|
const HANGUL_S_COUNT : Int = HANGUL_L_COUNT * HANGUL_N_COUNT

///|
fn canonical_decompose(codepoint : Int, output : Array[Int]) -> Unit {
  let syllable_index = codepoint - HANGUL_S_BASE
  if syllable_index >= 0 && syllable_index < HANGUL_S_COUNT {
    output.push(HANGUL_L_BASE + syllable_index / HANGUL_N_COUNT)
    output.push(
      HANGUL_V_BASE + syllable_index % HANGUL_N_COUNT / HANGUL_T_COUNT,
    )
    let trailing = syllable_index % HANGUL_T_COUNT
    if trailing != 0 {
      output.push(HANGUL_T_BASE + trailing)
    }
    return
  }
  let descriptor = decomposition_descriptor_of(codepoint)
  let length = decomposition_length_of(descriptor)
  if length == 0 {
    output.push(codepoint)
    return
  }
  for index in 0..<length {
    canonical_decompose(decomposition_scalar_at(descriptor, index), output)
  }
}

///|
fn canonical_order(codepoints : Array[Int]) -> Array[Int] {
  let output : Array[Int] = []
  for codepoint in codepoints {
    let combining_class = canonical_combining_class_of(codepoint)
    output.push(codepoint)
    if combining_class != 0 {
      let mut position = output.length() - 1
      while position > 0 {
        let previous_class = canonical_combining_class_of(output[position - 1])
        if previous_class == 0 || previous_class <= combining_class {
          break
        }
        let previous = output[position - 1]
        output[position - 1] = output[position]
        output[position] = previous
        position -= 1
      }
    }
  }
  output
}

///|
fn hangul_composition(starter : Int, codepoint : Int) -> Int {
  let leading = starter - HANGUL_L_BASE
  if leading >= 0 && leading < HANGUL_L_COUNT {
    let vowel = codepoint - HANGUL_V_BASE
    if vowel >= 0 && vowel < HANGUL_V_COUNT {
      return HANGUL_S_BASE + (leading * HANGUL_V_COUNT + vowel) * HANGUL_T_COUNT
    }
  }
  let syllable = starter - HANGUL_S_BASE
  if syllable >= 0 &&
    syllable < HANGUL_S_COUNT &&
    syllable % HANGUL_T_COUNT == 0 {
    let trailing = codepoint - HANGUL_T_BASE
    if trailing > 0 && trailing < HANGUL_T_COUNT {
      return starter + trailing
    }
  }
  -1
}

///|
fn compose_pair(starter : Int, codepoint : Int) -> Int {
  let hangul = hangul_composition(starter, codepoint)
  if hangul >= 0 {
    return hangul
  }
  canonical_composition_of(starter, codepoint)
}

///|
fn normalize_nfc(input : String) -> String {
  let decomposed : Array[Int] = []
  for character in input {
    canonical_decompose(character.to_int(), decomposed)
  }
  let ordered = canonical_order(decomposed)
  let composed : Array[Int] = []
  let mut starter_position = -1
  let mut starter = -1
  let mut previous_class = 0
  for codepoint in ordered {
    let combining_class = canonical_combining_class_of(codepoint)
    let composite = if starter_position >= 0 &&
      (previous_class == 0 || previous_class < combining_class) {
      compose_pair(starter, codepoint)
    } else {
      -1
    }
    if composite >= 0 {
      composed[starter_position] = composite
      starter = composite
    } else {
      if combining_class == 0 {
        starter_position = composed.length()
        starter = codepoint
      }
      composed.push(codepoint)
      previous_class = combining_class
    }
  }
  let characters : Array[Char] = []
  for codepoint in composed {
    characters.push(Int::unsafe_to_char(codepoint))
  }
  String::from_array(characters)
}
