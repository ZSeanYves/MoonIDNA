///|
test "unicode mapping lookup: deduplicated page blob" (bench : @bench.T) {
  bench.bench(fn() {
    let mut checksum = 0
    for index in 0..<65536 {
      let codepoint = index * 104729 % 0x110000
      checksum += mapping_token_of(codepoint) & 0x7
    }
    bench.keep(checksum)
  })
}
