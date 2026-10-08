# MoonCAR

Pure MoonBit CARv1 archive streaming, block integrity verification and offset indexing.

Under active development for the October 2026 MoonBit ecosystem competition.
The archive layer is original implementation; CID, multihash and hashing are
provided by MoonLoom, and CBOR values by 2515050242/cbor.

## Development

MoonBit compiler v0.10.14 or newer. Run `moon update`, `moon check --target all`,
`moon test --target all`, `moon build --target all`, `moon fmt`, and `moon info`.

## Scope

CARv1 framing and DAG-CBOR headers, incremental bounded parsing, ordered writing,
explicit content verification, root presence checks, and in-memory offset indexes.
CARv2, persistent storage and DAG closure traversal are outside version 0.1.
