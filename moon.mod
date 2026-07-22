name = "ZSeanYves/MoonIDNA"

version = "0.2.0"

readme = "README.mbt.md"

repository = "https://github.com/ZSeanYves/MoonIDNA"

license = "Apache-2.0"

keywords = [ "idna", "unicode", "punycode", "uts46" ]

preferred_target = "wasm-gc"

description = "Internationalized Domain Names in Applications (IDNA) for MoonBit"

options(
  exclude: [
    "unicode_data/unicode_data.bin",
    "unicode_data/idna_test_v2.bin",
    "src/idna_test_blob_wbtest.mbt",
    "src/idna_test_v2_wbtest.mbt",
    "tools/__pycache__/**",
  ],
)
