# CARv1 contract

References: https://ipld.io/specs/transport/car/carv1/ (Final),
https://ipld.io/specs/codecs/dag-cbor/spec/ and https://specs.ipfs.tech/cid/.

Decoder transitions `Prefix -> Body(n) -> Prefix`, starting with a header. MoonLoom
validates complete varints and CIDs. Declared section, archive and count budgets
are enforced before retaining payloads. Completed bodies become events. Errors
poison the decoder; `finish` closes it and rejects an incomplete prefix/body.
Completed events in a failing feed call are discarded. The caller must release
returned events and provide bounded chunks for bounded streaming memory.

The header adapter validates the exact two-key CARv1 schema without recursion.
Every length and root count is bounded, links use tag 42 with the identity prefix,
and only then is the general CBOR decoder invoked. Additional fields, indefinite
lengths, nonminimal integers and noncanonical map order are rejected in version 0.1.

Writer operations emit immutable sections without owning a sink. Failed operations
leave the offset/count unchanged. Same ordered roots and blocks yield same bytes.
There is no universal canonical DAG traversal order.

The index maps complete serialized CID bytes to ordered occurrence lists. Hash-map
collisions use exact key equality; identical digests with different codecs remain
distinct. `get` selects the first occurrence; `get_all` and `block_at` expose all.
Reading an entry re-parses framing and checks its CID against the index entry.
Locations are absolute CARv1 offsets, including header and section length prefixes.

Parsing validates structure, not content hashes. Verification checks every occurrence
and reports the corrupt section offset, including later duplicates. Root presence
is optional and independent. Opaque blocks do not establish transitive DAG closure.

Parsing/writing are linear in bytes and sections. Index lookup is expected constant
time after one scan. The index retains original bytes plus CID/location metadata;
requested payloads are materialized. Completed sections/payloads are copied: this is
bounded, not zero-copy. No speed claims are made without benchmarks. CARv2, persistent
indexes, content stores, UnixFS and DAG traversal are outside v0.1.
