# Responsibility and overlap audit

Checked 2026-10-08. No mature MoonBit package with the same CARv1 archive-layer core
was identified in the checked public results. This is a bounded search finding,
not proof that no unpublished or unindexed project exists.

| Project | Existing responsibility | MoonCAR boundary |
| --- | --- | --- |
| [MoonLoom](https://github.com/ggbond44439/moonloom) | CID, multihash, varint and hash providers | Reused at 0.1.6; not original contributions here |
| [2515050242/cbor](https://github.com/2515050242/moonbit-cbor-RFC-8949-CBOR-Concise-Binary-Object-Representation) | General CBOR codecs | Reused at 0.1.2 with CAR-only bounded schema preflight |
| [mizchi/cbor.mbt](https://github.com/mizchi/cbor.mbt) | General CBOR | 0.1.1 uses removed suberror syntax, so not selected |
| [atproto-mb](https://github.com/marianoguerra/atproto-mb) | ATProto ecosystem | Source explicitly omits CAR, no implementation found |
| [Yingqingxue/mooncas](https://mooncakes.io/docs/Yingqingxue/mooncas) | Content-addressed storage/chunking/GC | Registry README checked only; no store or chunker implemented here |
| [MoonCollate](https://github.com/CaptainK-65/moon-collate) | Unicode collation | Separate repository and problem domain |

Registry queries: `car archive`, `cid`, `dag-cbor`, `multiformats`, `cbor`, `ipld`.
GitHub repository queries: `CARv1 language:MoonBit`, `CARv2 language:MoonBit`,
`"content addressable archive" MoonBit`. These metadata searches are not exhaustive
global code searches. Source snapshots: MoonLoom
`fc019160d3117b3bc35deeddbc85fc0aa3321069`; atproto-mb
`a609a2ba61c3b9772755f0bde12912948fc96f89`.

Original implementation: archive state machine, framing, CAR header policies,
transactional section writer, diagnostics, exact offset index, duplicate handling
and verification orchestration. Generic codecs, cryptography, CID and file I/O are
dependency responsibilities. No existing CAR core was copied.
