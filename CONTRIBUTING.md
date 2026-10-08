# Contributing to MoonCAR

Start with an [issue](https://github.com/CaptainK-65/moon-car/issues) containing a
reproduction or a concrete use case. Use the bug/feature forms and search existing
issues first. Include `moon version --all`, OS, backend and the package version.
Attach a minimal public fixture or byte sequence when possible; record its source
and expected behavior. Make clear whether a failure concerns structure, content
hashes, root presence, or the file adapter.

## Local validation

From the repository root, with the stable MoonBit toolchain and a native C compiler:

```text
moon update
moon check --target all --deny-warn
moon test --target all
moon build --target all
moon fmt --check
moon info
git diff -- pkg.generated.mbti
moon run cmd/mooncar --target native -- verify fixtures/carv1-basic.car
```

Review public interface changes and explain any intended API change in the PR.
Add regression tests for changed behavior, particularly malformed inputs, section
boundaries and resource budgets. Documentation and image changes need rendering
or link inspection; do not add tests that merely repeat their text.

## Scope and source provenance

Keep the reusable core portable and pure MoonBit. Reuse MoonLoom for CID, varints
and hashes and the CBOR dependency for generic codecs. File I/O remains in the
native CLI. Explain changes to the documented CARv1 profile rather than implying
support for CARv2, UnixFS or transitive graph closure.

Keep the independent fixture unmodified unless its source/version is intentionally
changed with a reviewed checksum and license notice. First run
`moon run tools/verify_fixture.mbtx --target native` to check provenance and
exercise rejection of modified copies. Regenerate its test literal
with `moon run tools/embed_fixture.mbtx`, then run `moon fmt` and inspect the diff.
Agent-authored automation belongs in `.mbtx` files; see [AGENTS.md](AGENTS.md).

## Review and evidence

Reference the issue in the commit/PR. A completed issue should link its implementing
commit and a successful Actions run, with the exact behavior validated. Mark roadmap
work as pending until implemented and verified. Never use empty commits or repeated
runs of the same commit to represent separate changes.
