# Version 0.1 acceptance evidence

Local validation recorded 2026-10-08 on Windows. Isolated official stable toolchain:
`moon 0.1.20260920 (914d7da)`, `moonc v0.10.14+7d59c7ec9`.
Toolchain archive SHA-256:
`faae225a8287d0ce69e44b5b3f754af988e97f4446056d8f32ceb3ddb998fce7`.
The existing global toolchain was preserved.

## Verified

- `moon check --target all --deny-warn`: passed, zero MoonBit warnings/errors.
- `moon build --target all`: passed (Windows async dependency emits one upstream
  C macro redefinition warning; core has no C/JS FFI).
- `moon test --target all`: 35 tests passed on each of wasm, wasm-gc, JS and native.
  Generated tests include 50 binary size/chunk combinations and every two-part split
  position for a sample archive; test-function counts do not count each combination.
- Three executable examples ran successfully.
- Official IPLD fixture: 715 bytes, eight blocks, two roots; every known section/data
  offset matches its independent JSON description, every hash and root presence passes.
- Rewriting the official fixture reproduces all 715 bytes.
- `ipfs-car@3.1.0` CLI read and unpacked a MoonCAR-generated raw-block archive;
  extracted payload SHA-256 matched the input.
- MoonCAR read and verified an `ipfs-car@3.1.0` archive, rewrote identical bytes;
  the reference CLI unpacked the rewritten archive with identical payload.

## Reproduce interoperability

Install `ipfs-car@3.1.0` into a disposable directory. It is only a reference tool,
not a runtime dependency of the library. Use its existing CLI:

```text
moon run cmd/mooncar --target native -- pack moon.car README.md
ipfs-car blocks moon.car
ipfs-car unpack moon.car --output extracted.md
ipfs-car pack README.md --no-wrap --output reference.car
moon run cmd/mooncar --target native -- verify reference.car
moon run cmd/mooncar --target native -- rewrite reference.car rewritten.car
ipfs-car unpack rewritten.car --output rewritten.md
```

Compare input and both extracted payloads, and compare reference and rewritten CAR
bytes. Reference: https://github.com/storacha/ipfs-car, wrapping `@ipld/car`.

## Published dependency provenance

| Module/version | Registry archive SHA-256 |
| --- | --- |
| ggbond44439/moonloom 0.1.6 | 53760fa57dbb83daf4cb569cbb978c8cddc2d2576a685805c048c846c5f3086a |
| 2515050242/cbor 0.1.2 | 28c0e2550ec0f891daf42e7e6867a2de98751358db5ddcd68171aa1b3eae3dbf |
| moonbitlang/async 0.22.4 | 2ffdb85cb229cfe9219161a7f2b959215a79a0d75b7e642cb346713f168a1457 |

Independent fixture source/license/checksum: [fixtures/README.md](../fixtures/README.md).
Generate its portable test literal with `moon run tools/embed_fixture.mbtx`, then
`moon fmt`; there should be no fixture test diff.

## Remaining external gates

Public GitHub CI, mooncakes publication/clean consumer install, competition enrollment
and final acceptance must have actual evidence recorded before being marked complete.
No performance or peak-memory claims have been made. CARv2 is not promised in v0.1.
The charter requires the participant to write the one-page proposal manually.

Initial public CI: Linux, macOS and Windows validation all passed at
https://github.com/CaptainK-65/moon-car/actions/runs/37731131481 . The separate
fixture job exposed a missing registry-update step; it was fixed before release.
