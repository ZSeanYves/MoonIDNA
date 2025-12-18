// --- 工具：检测末尾是否有 '.' ---

fn has_trailing_dot(domain : StringView) -> Bool {
  let s_str = domain.to_string()
  let bs = @buf.string_to_utf8_bytes(s_str).to_array()
  if bs.length() == 0 {
    return false
  }
  bs[bs.length() - 1].to_int() == 0x2E // '.'
}

// --- 工具：将域名拆成 labels（忽略末尾的 '.'，方便处理） ---

fn split_labels(domain : StringView) -> Array[String] raise @buf.Utf8DecodeError {
  let s_str = domain.to_string()
  let bs = @buf.string_to_utf8_bytes(s_str).to_array()

  let labels : Array[String] = []
  let mut current : Array[Byte] = []

  let mut limit = bs.length()
  if limit > 0 && bs[limit - 1].to_int() == 0x2E {
    // 去掉末尾 '.'，用 has_trailing_dot 单独记录
    limit = limit - 1
  }

  let mut i = 0
  while i < limit {
    let b = bs[i]
    if b.to_int() == 0x2E {
      // 碰到 '.'，结束一个 label
      let label_str =
        if current.length() == 0 {
          "".to_string()
        } else {
          @buf.utf8_bytes_to_string(Bytes::from_array(current))
        }
      labels.push(label_str)
      current = []
    } else {
      current.push(b)
    }
    i += 1
  }

  // 收尾：如果还有内容，作为最后一个 label
  if current.length() > 0 || limit == 0 {
    let label_str =
      if current.length() == 0 {
        "".to_string()
      } else {
        @buf.utf8_bytes_to_string(Bytes::from_array(current))
      }
    labels.push(label_str)
  }

  labels
}

// --- 工具：判断一个 label 是否全部 ASCII ---

fn is_all_ascii(label : String) -> Bool {
  let bs = @buf.string_to_utf8_bytes(label).to_array()
  let mut i = 0
  while i < bs.length() {
    let b = bs[i].to_int()
    if b < 0 || b > 0x7F {
      return false
    }
    i += 1
  }
  true
}

// --- 工具：用 '.' 把 labels 拼回域名字符串 ---

fn join_labels(labels : Array[String]) -> String {
  let mut out = "".to_string()
  let mut i = 0
  while i < labels.length() {
    if i > 0 {
      out = out + "."
    }
    out = out + labels[i]
    i += 1
  }
  out
}

// --- 工具：判断 label 是否以 xn-- 开头（不区分大小写） ---
fn is_punycode_label(label : String) -> Bool {
  let bs = @buf.string_to_utf8_bytes(label).to_array()
  if bs.length() < 4 {
    return false
  }
  let b0 = bs[0].to_int()
  let b1 = bs[1].to_int()
  let b2 = bs[2].to_int()
  let b3 = bs[3].to_int()

  let lower_x = 0x78  // 'x'
  let upper_x = 0x58  // 'X'
  let lower_n = 0x6E  // 'n'
  let upper_n = 0x4E  // 'N'

  if b0 != lower_x && b0 != upper_x {
    return false
  }
  if b1 != lower_n && b1 != upper_n {
    return false
  }
  if b2 != 0x2D { // '-'
    return false
  }
  if b3 != 0x2D { // '-'
    return false
  }
  true
}


// --- 工具：取掉 xn-- 前缀后的 payload 字符串 ---

fn punycode_payload(label : String) -> String raise @buf.Utf8DecodeError {
  let bs = @buf.string_to_utf8_bytes(label).to_array()
  let payload : Array[Byte] = []
  let mut i = 4
  while i < bs.length() {
    payload.push(bs[i])
    i += 1
  }
  @buf.utf8_bytes_to_string(Bytes::from_array(payload))
}