# MoonIDNA Maintenance Status

This document records the current implementation status and release gates.

## Completed

- Migrated old `moon.mod.json` / `moon.pkg.json` files to current MoonBit
  manifests and set the breaking release version to 0.2.0 (Mooncakes currently
  requires pre-1.0 versions).
- Removed `ZSeanYves/bufferutils` and `moonbitlang/x`; UTF-8 conversion now uses
  `moonbitlang/core/encoding/utf8`.
- Added a shared UTS #46 pipeline: whole-domain mapping, NFC, label splitting,
  A-label decoding without remapping, validation, domain-level Bidi, and output.
- Made mapping, Punycode, Bidi, ContextJ, hyphen, and DNS errors observable.
  `to_ascii` raises `IdnaError`; report APIs retain candidate output and all
  errors; `to_unicode` remains total.
- Added NFC canonical decomposition/reordering/composition, including algorithmic
  Hangul handling.
- Corrected mapped separators, A-label roundtrip validation, leading Mark and
  empty-label checks, conditional Bidi application, `@missing` Bidi defaults,
  and textual DNS limits.
- The supported API is located at `ZSeanYves/MoonIDNA/src`, matching the
  canonical MoonBit package layout.
- Removed public mapping/Bidi/Joining tables, options internals, Punycode helpers,
  and validators from the generated interface.
- Deleted committed `src/data` inputs and `src/tools` table emitters. The new
  maintainer tool creates a versioned, checksummed Blob using two-stage
  deduplicated page tables and official `moon tool embed` output.
- Added functional, error, NFC, property, and performance tests. All supported
  backends are part of the final validation matrix.
- Synchronized every Unicode input to 17.0.0: mapping, Bidi, Joining, UCD,
  normalization exclusions, IDNA2008 categories, and `IdnaTestV2`.
- Compiled the official suite into a test-only Blob. All 6,389 representable
  cases pass; the two unpaired-surrogate cases are skipped as permitted for
  implementations whose string type cannot represent ill-formed Unicode.
- Removed the generator's dependency on Python `unicodedata`; NFC composition
  pairs now come deterministically from `UnicodeData.txt` and
  `Full_Composition_Exclusion`.
- Completed pre-release hardening: RFC-style malformed Punycode and DNS
  boundary regressions, a separate strict registration profile with ContextO,
  and reusable policy, error, label-sink, display, and differential APIs.

## Data Format

`unicode_data/unicode_data.bin` is a little-endian, versioned format. The header
contains section offsets, lengths, format version, and CRC32. The lock file also
records a SHA-256 for the complete Blob.

- Mapping: 16-bit page tokens containing status and interned mapping-sequence ID.
- Properties: one 32-bit token containing Bidi class, Joining type, Virama,
  canonical combining class, and Mark state.
- NFC: interned canonical decomposition sequences plus sorted composition pairs;
  Hangul is handled algorithmically.
- Stage one has 4,352 page IDs; stage-two pages are deduplicated at 256-codepoint
  granularity. Runtime reads are direct and allocation-free.

Normal dependency builds do not run generators. Both the binary and generated
MoonBit embed are committed; the binary is excluded from Mooncakes publication
because the embed is sufficient at runtime.

## Current Scope

The public flags implement the UTS #46 application processing surface. The
separate `IdnaProfile::Registration` API applies the complete Unicode 17
`Idna2008.txt` derived-property corpus, NFC enforcement, ContextJ, ContextO,
STD3, Bidi, and DNS limits without changing WHATWG lookup defaults. The
registration white-box corpus test covers all 1,114,112 Unicode code points,
all 25 CONTEXTO assignments, and both CONTEXTJ assignments.

The RFC 3492 implementation remains private and is covered by malformed-input,
overflow, supplementary-plane, and full `IdnaTestV2` tests. The package no
longer exposes deprecated transitional wrapper functions; callers use the
named policy API instead.

## Rust Comparison

The design now follows the useful boundaries from Rust `idna` 1.1.0: one shared
processor, output/error separation, explicit policy flags, domain-level Bidi,
and compact direct Unicode lookup. It intentionally does not copy Rust's ICU4X
backend because MoonBit does not currently expose an equivalent portable Unicode
provider across wasm-gc, wasm, JS, and native.

The public policy API includes reusable profiles, fail-fast/collect error
behavior, a label sink, a display selector, and compatibility vectors that
compare the policy path with the convenience API. The compact Blob backend is
kept deliberately portable across wasm-gc, wasm, JS, and native targets.

## Release Gate

The current build satisfies all release gates, including the complete
registration corpus scan and DNS boundary matrix.

1. Mapping, Bidi, Joining, UCD, normalization, and tests all pinned to Unicode
   17.0.0.
2. Full Unicode 17 `IdnaTestV2.txt` passing on all supported backends.
3. RFC 3492 invalid/overflow vectors and DNS 0/1/63/64/253/254/255 boundaries.
4. `moon check --target all` and tests on wasm-gc, wasm, JS, and native.
5. Both `build_unicode_blob.py --check` and `build_idna_test_blob.py --check`,
   with reviewed lock hashes.
6. `moon info && moon fmt` with only the intended public API in `.mbti`.
7. Unicode 17 `Idna2008.txt` category counts and all contextual assignments
   validated by the registration corpus tests.

## References

- [UTS #46 Revision 35](https://www.unicode.org/reports/tr46/)
- [Unicode 17 IDNA data](https://www.unicode.org/Public/17.0.0/idna/)
- [WHATWG URL IDNA](https://url.spec.whatwg.org/#idna)
- [RFC 3492](https://datatracker.ietf.org/doc/html/rfc3492)
- [RFC 5891](https://datatracker.ietf.org/doc/html/rfc5891)
- [RFC 5893](https://datatracker.ietf.org/doc/html/rfc5893)
- [Rust idna](https://docs.rs/idna/latest/idna/)
