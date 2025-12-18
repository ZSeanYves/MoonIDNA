# ZSeanYves/MoonIDNA
# 🌐 MoonIDNA: IDNA (UTS #46) for MoonBit
[English](#english) | [简体中文](#简体中文)

---

<a name="english"></a>

## 🇬🇧 English

### Overview

**MoonIDNA** is an implementation of **Internationalized Domain Names in Applications (IDNA)** for **MoonBit**, following **UTS #46** mapping rules and **IDNA2008** validation (RFC 5890–5893).

The library provides `ToASCII` and `ToUnicode` operations for domain names. It takes care of:

* Unicode → ASCII conversion via **Punycode** (`xn--` labels)
* UTS #46 **mapping** (case folding, compatibility mappings, ß/deviation handling, etc.)
* **STD3** ASCII rules (optional)
* **Hyphen** and label‑length checks
* **DNS length** checks (label ≤ 63 octets, full domain ≤ 255 octets)
* **Bidi** rules (RFC 5893) using `DerivedBidiClass.txt`
* **ContextJ** rules for `U+200C` / `U+200D` using `DerivedJoiningType.txt` + `UnicodeData.txt`

It is designed to be:

* **Specification‑oriented**: follows UTS #46 and IDNA2008 behavior, including transitional flags.
* **Data‑driven**: Unicode tables are generated from official Unicode data files.
* **Well‑tested**: shipped with black‑box tests covering core scenarios and edge cases.

---

### Installation

Add the dependency via `moon`:

```bash
moon add ZSeanYves/MoonIDNA
```

Or edit `moon.mod.json`:

```json
"import": ["ZSeanYves/MoonIDNA"]
```

Then import the package in your MoonBit code:

```moonbit
use ZSeanYves/MoonIDNA::idna
```

---

### Quick Start

#### 1) Basic ToASCII / ToUnicode

```moonbit
use ZSeanYves/MoonIDNA::idna

fn main() {
  // Unicode → ASCII (IDNA ToASCII)
  let ascii = @idna.to_ascii("bücher.example")
  // => "xn--bcher-kva.example"

  // ASCII / Punycode → Unicode (IDNA ToUnicode)
  let uni = @idna.to_unicode("xn--bcher-kva.example")
  // => "bücher.example"

  println(ascii)
  println(uni)
}
```

#### 2) Using options explicitly

For more control, use the variants that accept an `IdnaOptions` value:

```moonbit
use ZSeanYves/MoonIDNA::idna

fn main() {
  // Default profile (non‑transitional)
  let opts = @idna.options_default()

  let a = @idna.to_ascii_with_options("bücher.example", opts)
  let u = @idna.to_unicode_with_options("xn--bcher-kva.example", opts)

  // Transitional profile (UTS #46 transitional processing)
  let opts_tr = @idna.options_transitional()
  let sharp_default = @idna.to_ascii_with_options("Straße.de", opts)
  let sharp_tr      = @idna.to_ascii_with_options("Straße.de", opts_tr)

  // sharp_default  == "xn--strae-oqa.de" (punycode)
  // sharp_tr       == "strasse.de"      (ß → ss mapping)
}
```

#### 3) Tuning options (example)

You can start from `options_default()` and tweak individual flags when needed, for example to ignore invalid Punycode sequences in input:

```moonbit
use ZSeanYves/MoonIDNA::idna

fn main() {
  let opts = @idna.options_default()
  // Ignore invalid Punycode labels during ToUnicode (example name; see IdnaOptions for the actual field list)
  opts._ignore_invalid_punycode = true

  let host = "xn--abc_"  // intentionally broken punycode
  let out  = @idna.to_unicode_with_options(host, opts)
  println(out)
}
```

---

### Public API

> This section documents the main user‑facing functions and types.

#### Top‑level conversion functions

All functions live in the `idna` package.

```moonbit
pub fn to_ascii(domain : StringView) -> String
pub fn to_unicode(domain : StringView) -> String

pub fn to_ascii_with_options(domain : StringView, opts : IdnaOptions) -> String
pub fn to_unicode_with_options(domain : StringView, opts : IdnaOptions) -> String
```

* `to_ascii` / `to_unicode` are convenience shortcuts that internally use `options_default()`.
* `to_*_with_options` let you explicitly specify the UTS #46 flags via `IdnaOptions`.

#### Options: `IdnaOptions`

`IdnaOptions` collects the boolean switches described in UTS #46 and some IDNA2008 checks. The exact field list is defined in `src/options.mbt`, but conceptually it includes:

* `use_std3_ascii_rules` — enable STD3 restrictions on ASCII labels.
* `check_hyphens` — forbid leading/trailing hyphens and certain hyphen positions (e.g. `"xn--"`).
* `check_bidi` — enforce Bidi rules (RFC 5893) on each label.
* `check_joiners` — enforce ContextJ rules for `U+200C`/`U+200D` (RFC 5892 Appendix A).
* `verify_dns_length` — enforce label ≤ 63 octets, full domain ≤ 255 octets.
* `_transitional_processing` — enable UTS #46 **transitional** mapping (e.g. ß → `ss`).
* `_ignore_invalid_punycode` — ignore Punycode decode errors during `ToUnicode`.

Helper constructors:

```moonbit
pub fn options_default() -> IdnaOptions
pub fn options_transitional() -> IdnaOptions
```

* `options_default()` — recommended profile for most applications; non‑transitional, with checks enabled.
* `options_transitional()` — UTS #46 transitional processing (intended mainly for legacy compatibility).

#### Errors

Internally, conversion and validation uses an `IdnaError` enum and `IdnaErrorList` type to track issues such as:

* `PunycodeError` (invalid input, overflow, invalid UTF‑8)
* `InvalidPunycode` (for `xn--` labels that fail decode)
* `Std3Error` (violations under `use_std3_ascii_rules`)
* `HyphenError`
* `BidiError`
* `JoinerError`
* `DnsLengthError`

At the API level we currently always return a `String` and silently keep or drop labels depending on options. If you need to inspect errors, you can:

* Call internal helpers such as `validate_label_all` / `validate_domain_all`, or
* Wrap `to_*` in your own function that runs custom validation on top.

(Exposing a full `Result[String, IdnaErrorList]` API is left as an optional extension.)

---

### Implementation Notes

MoonIDNA is built as a **data‑driven** implementation using official Unicode data:

* **Mapping table** (UTS #46 IdnaMappingTable)

  * Generated from `IdnaMappingTable.txt`.
  * Encoded into `src/mapping.mbt` as a compact set of ranges + mapping sequences.
  * `map_label` walks this table and applies mapping, deviation, and ignore rules.

* **Bidi table**

  * Generated from `DerivedBidiClass.txt` into `src/bidi_table.mbt`.
  * `bidi.mbt` implements RFC 5893 label rules using these classes.

* **Joining / Virama tables** (ContextJ)

  * Generated from `DerivedJoiningType.txt` + `UnicodeData.txt` into `src/joining_table.mbt`.
  * Used by `check_joiners` to implement U+200C/U+200D contextual rules.

* **Punycode**

  * Implements RFC 3492 bootstring algorithm with constants:

    * `BASE = 36`, `TMIN = 1`, `TMAX = 26`, `SKEW = 38`, `DAMP = 700`, `INITIAL_BIAS = 72`, `INITIAL_N = 0x80`.
  * Basic code points (`< 0x80`) are copied directly; non‑ASCII are encoded as `xn--` labels.

* **Validation pipeline**

  * Label‑level: `check_std3` → `check_hyphens` → `check_bidi` → `check_joiners`.
  * Domain‑level: `check_dns_length` on the final ASCII form.

The Unicode tables are generated by small Python scripts in `tools/` and kept out of hand‑written logic to avoid mistakes.

---

### Tests

MoonIDNA ships with a focused test file (e.g. `MoonIDNA_test.mbt`), including:

* ASCII passthrough (`"example.com"` → `"example.com"`).
* Non‑ASCII roundtrip (`"bücher.example"` ↔ `"xn--bcher-kva.example"`).
* Sharp‑s behavior under default vs transitional processing.
* Invalid Punycode handling with `_ignore_invalid_punycode` on/off.
* Punycode encode/decode correctness for basic examples.
* Smoke tests for Bidi / Joiner paths to ensure they do not panic on edge cases.

Run tests with:

```bash
moon test
```

Or, to focus on this module only:

```bash
moon test -p ZSeanYves/MoonIDNA/src -f MoonIDNA_test.mbt --target wasm-gc
```

---

### Suggested Project Layout

```text
ZSeanYves/MoonIDNA
  ├─ data/
  │   ├─ IdnaMappingTable.txt
  │   ├─ DerivedBidiClass.txt
  │   └─ DerivedJoiningType.txt / UnicodeData.txt
  ├─ tools/
  │   ├─ gen_mapping_table.py
  │   ├─ gen_bidi_table.py
  │   └─ gen_joining_table.py
  └─ src/
      ├─ MoonIDNA.mbt            # public idna package facade
      ├─ mapping.mbt             # generated mapping table
      ├─ bidi_table.mbt          # generated bidi table
      ├─ joining_table.mbt       # generated joining / virama table
      ├─ punycode.mbt            # core Punycode implementation
      ├─ validate.mbt            # STD3, hyphens, bidi, joiners, DNS length
      ├─ options.mbt             # IdnaOptions definition
      └─ MoonIDNA_test.mbt       # tests
```

You can adjust paths to fit your own module layout; the key idea is to keep generated tables clearly separated from hand‑written logic.

---

### License

This project is intended to be released under a permissive open‑source license (e.g. Apache‑2.0). See the repository’s `LICENSE` file for the definitive terms.

---

