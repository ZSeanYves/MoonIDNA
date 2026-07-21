# MoonIDNA

MoonIDNA implements UTS #46 ToASCII and ToUnicode for MoonBit, including NFC,
Punycode, Bidi, ContextJ, STD3, hyphen, and DNS length checks.

The maintained package uses only official MoonBit core libraries. The former
`ZSeanYves/bufferutils` dependency and the generated object tables have been
removed.

## Installation

```bash
moon add ZSeanYves/MoonIDNA
```

```moonbit
import {
  "ZSeanYves/MoonIDNA/idna" @idna,
}
```

`ZSeanYves/MoonIDNA/src` remains as a deprecated compatibility package for one
release. New code should import `/idna`.

## Usage

```mbt nocheck
fn main {
  let ascii = try! @idna.to_ascii("bücher.example")
  let unicode = @idna.to_unicode("xn--bcher-kva.example")
  println(ascii)   // xn--bcher-kva.example
  println(unicode) // bücher.example
}
```

`to_ascii` raises `IdnaError` when validation fails. `to_unicode` is a total
function and returns the input unchanged on failure. Use the report APIs when a
candidate output and all validation errors are both required:

```mbt nocheck
fn inspect_domain(domain : StringView) {
  let report = @idna.to_unicode_report(domain)
  println(report.output)
  println(report.errors)
}
```

Both conversions accept the UTS #46 flags as optional named parameters:

```mbt nocheck
let strict = try! @idna.to_ascii(
  "example.com",
  use_std3_ascii_rules=true,
  check_hyphens=true,
  check_bidi=true,
  check_joiners=true,
  transitional_processing=false,
  verify_dns_length=true,
  ignore_invalid_punycode=false,
)
```

Defaults follow WHATWG lookup behavior: nontransitional processing, Bidi and
ContextJ enabled, and STD3, hyphen, and DNS length checks disabled.

## Unicode Data

Runtime lookup uses a 351,728-byte Unicode 17 versioned binary Blob with
deduplicated 256-codepoint pages. It contains UTS #46 mappings,
Bidi/Joining/CCC/Mark/Virama properties, canonical decompositions, and NFC
composition pairs. Lookups do not construct entry objects or decompress the
entire table at startup.

The data version is embedded in the Blob and available as
`@idna.unicode_version()`. Generation fails if any input belongs to a different
or unidentified Unicode version.

Raw Unicode text files are not committed. Sources, versions, URLs, and SHA-256
digests are pinned in `unicode_data/unicode.lock.json`. Maintainers can verify or
regenerate the committed data with:

```bash
python3 tools/build_unicode_blob.py --download
python3 tools/build_unicode_blob.py --check
python3 tools/build_idna_test_blob.py --check
```

During an intentional Unicode upgrade, stage a complete same-version source set
and run `build_unicode_blob.py --update-lock`. Mixed or unidentified source
versions are rejected before any committed output is replaced.

All mapping, Bidi, Joining, normalization, IDNA2008, and conformance sources are
pinned to Unicode 17.0.0. The full `IdnaTestV2.txt` suite is compiled into a
test-only Blob: 6,389 representable cases run on every backend, while the two
unpaired-surrogate cases are skipped because MoonBit `String` cannot represent
ill-formed Unicode.

## Development

```bash
moon check --target all
moon test --target wasm-gc
moon test --target wasm
moon test --target js
moon test --target native
moon bench idna/unicode_data_bench.mbt --release --target native
moon info && moon fmt
moon package --list
```

See `PERFORMANCE.md` for the measured table migration results.

## References

- [Unicode UTS #46](https://www.unicode.org/reports/tr46/)
- [Unicode 17 IDNA data](https://www.unicode.org/Public/17.0.0/idna/)
- [WHATWG URL Standard: IDNA](https://url.spec.whatwg.org/#idna)
- [RFC 3492: Punycode](https://datatracker.ietf.org/doc/html/rfc3492)
- [RFC 5891: IDNA2008 Protocol](https://datatracker.ietf.org/doc/html/rfc5891)
- [RFC 5893: Bidi Rules](https://datatracker.ietf.org/doc/html/rfc5893)

## License

Apache-2.0
