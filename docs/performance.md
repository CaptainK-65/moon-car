# Initial reproducible timing record

2026-10-08, Windows, Intel Core Ultra 9 285H, official `moonc v0.10.14`, native
release backend, published `CaptainK-65/moon-car@0.1.0`. This is an initial local
measurement, not a speed guarantee or a comparison against other libraries.

Reproduce after `moon update`:

```text
moon run tools/benchmark.mbtx --target native --release
```

The script imports the published package, warms up each operation once, takes five
wall-clock millisecond samples using `@env.now`, and reports their median. Encode,
index and streaming samples each perform eight rounds; hash construction is outside
the timed region. Streaming feeds 4096-byte chunks and discards completed events.
Lookup timing includes locating, validating CID framing and copying payload bytes.

| Profile | Archive bytes | Encode / 8 rounds | Index / 8 rounds | Stream / 8 rounds |
| --- | ---: | ---: | ---: | ---: |
| 4096 distinct blocks, each 128 bytes | 679995 | 140 ms | 272 ms | 117 ms |
| 2 distinct blocks, each 4 MiB | 8388747 | 127 ms | 506 ms | 535 ms |

10,000 indexed lookups of small blocks: median 55 ms. Twenty large-block lookups:
median 83 ms. Requests follow deterministic `(i * 73) % count` positions; these are
in-memory indexed reads, not disk seeks. Payload checksums/length sums are printed
to keep observed work visible. Background machine load and millisecond clock
resolution affect results.

Peak process memory has not been measured. Decoder buffer bounds are a structural
contract, not a measured claim about total runtime/GC memory. Index memory grows
with archive bytes and section count; returned blocks/events own payloads. Further
memory profiling and larger sustained-stream experiments remain future work.
