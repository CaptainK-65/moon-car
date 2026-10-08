///|
test "published dependencies can encode a CID and CBOR header" {
  let cid = @cid.cid_from_content(
    @cid.RAW_CODEC, @cid.Sha2_256, b"hello", @cid.sha2_provider(), @cid.Limits::default(),
  ).unwrap()
  assert_eq(cid.to_bytes().length(), 36)
  let encoded = @cbor.encode(@cbor.Unsigned(1UL))
  assert_eq(encoded, b"\x01")
}
