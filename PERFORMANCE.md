# Unicode Data Performance

Measurements were taken with MoonBit `0.1.20260713` / `moonc 0.10.4` on the
same machine, using a native release build.

## Lookup Benchmark

The benchmark performs 65,536 mapping-status lookups over codepoints distributed
through the full Unicode range.

| Representation | Mean | Relative |
|---|---:|---:|
| Legacy 8,011-range binary search | 590.47 us | 1.00x |
| Unicode 17 deduplicated page Blob | 146.63 us | 4.03x faster |

Run the retained benchmark with:

```bash
moon bench src/unicode_data_bench.mbt --release --target native --no-parallelize
```

## Build Size

| Artifact | Before | After | Change |
|---|---:|---:|---:|
| Native/wasm release package `.core` | 3,033,556 B | 480,829 B | -84.2% |
| Committed raw Unicode text | about 3.28 MB | 0 B | removed |
| Runtime Unicode binary | object arrays | 351,728 B | direct Blob |

## Embedded Source Size

The binary format and runtime memory did not change. Only the generated MoonBit
source representation was replaced with compact decimal `Bytes` literals.

| Artifact | Default hex embed | Compact byte embed | Change |
|---|---:|---:|---:|
| `src/unicode_blob.mbt` | 2,170,064 B | 835,605 B | -61.5% |
| Mooncakes package zip | 134,520 B | 123,285 B | -8.4% |
| Runtime Unicode Blob | 351,728 B | 351,728 B | unchanged |

Native lookup remained within the existing benchmark range: 145.68 us before
and 143.77 us after. A clean native `moon check` changed from 0.89 s to 0.85 s;
these small timing differences should be treated as noise, not a claimed runtime
speedup.

The logical Unicode range contains 4,352 pages of 256 codepoints. Page
deduplication leaves 156 mapping pages, 161 combined-property pages, and 39
canonical-decomposition pages. Mapping sequences are interned, scalar values use
three bytes, and no full-table decompression or entry-object initialization occurs
at runtime.

The compact embed is split into 64 KiB physical chunks so the `wasm` backend
stays below its text-segment line limit. Chunk selection is a fixed branch and
does not allocate or concatenate data at startup.
