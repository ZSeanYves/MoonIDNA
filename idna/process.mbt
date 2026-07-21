///|
fn append_errors(target : IdnaErrorList, source : IdnaErrorList) -> Unit {
  for error in source {
    if !target.contains(error) {
      target.push(error)
    }
  }
}

///|
fn push_error(target : IdnaErrorList, error : IdnaError) -> Unit {
  if !target.contains(error) {
    target.push(error)
  }
}

///|
fn punycode_error_to_idna(error : PunycodeError) -> IdnaError {
  match error {
    PunycodeError::InvalidInput
    | PunycodeError::InvalidUtf8
    | PunycodeError::Overflow => IdnaError::InvalidPunycode
  }
}

///|
fn decode_and_validate_label(
  raw_label : String,
  options : IdnaOptions,
) -> (String, IdnaErrorList) {
  let errors : IdnaErrorList = []
  if !is_punycode_label(raw_label) {
    append_errors(errors, validate_label_all(raw_label, options))
    return (raw_label, errors)
  }
  let decoded = match decode(punycode_payload(raw_label)) {
    Ok(value) => value
    Err(error) => {
      if !options._ignore_invalid_punycode {
        push_error(errors, punycode_error_to_idna(error))
      }
      return (raw_label, errors)
    }
  }
  if is_all_ascii(decoded) || normalize_nfc(decoded) != decoded {
    push_error(errors, IdnaError::InvalidAlabel)
  }
  append_errors(errors, validate_label_all(decoded, options))
  match encode(decoded) {
    Ok(payload) =>
      if "xn--" + payload != raw_label {
        push_error(errors, IdnaError::InvalidAlabel)
      }
    Err(error) => {
      let _ = punycode_error_to_idna(error)
      push_error(errors, IdnaError::InvalidAlabel)
    }
  }
  (decoded, errors)
}

///|
fn process_domain(
  domain : StringView,
  options : IdnaOptions,
  emit_ascii : Bool,
) -> IdnaReport {
  let errors : IdnaErrorList = []
  let mapped = map_label(domain.to_owned(), options)
  append_errors(errors, mapped.errors)
  let normalized = normalize_nfc(mapped.value)
  let trailing_root_dot = has_trailing_dot(normalized)
  let raw_labels = split_labels(normalized)
  let unicode_labels : Array[String] = []
  let output_labels : Array[String] = []

  for raw_label in raw_labels {
    if !emit_ascii && raw_label.length() == 0 {
      push_error(errors, IdnaError::EmptyLabel)
    }
    let (unicode_label, label_errors) = decode_and_validate_label(
      raw_label, options,
    )
    append_errors(errors, label_errors)
    unicode_labels.push(unicode_label)
    if emit_ascii && !is_all_ascii(unicode_label) {
      match encode(unicode_label) {
        Ok(payload) => output_labels.push("xn--" + payload)
        Err(error) => {
          push_error(errors, punycode_error_to_idna(error))
          output_labels.push(unicode_label)
        }
      }
    } else {
      output_labels.push(unicode_label)
    }
  }

  if options._check_bidi {
    append_errors(errors, check_bidi_domain(unicode_labels))
  }
  let mut output = join_labels(output_labels)
  if trailing_root_dot {
    output = output + "."
  }
  if emit_ascii {
    append_errors(errors, validate_domain_all(output, options))
  }
  { output, errors }
}
