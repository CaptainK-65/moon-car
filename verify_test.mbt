///|
test "all occurrences are verified and corruption reports its section offset" {
  let valid = sample_block(b"correct")
  let corrupt = @moon_car.Block::new(valid.cid(), b"corrupt")
  let archive = @moon_car.Archive::decode(
    @moon_car.encode(@moon_car.Header::new([valid.cid()]), [valid, corrupt]),
  )
  let offset = archive.entries()[1].location().section_offset
  let rejected = try {
    archive.verify()
    false
  } catch {
    @moon_car.Integrity(actual, _) => actual == offset
    _ => false
  }
  assert_true(rejected)
  assert_eq(archive.get(valid.cid()).data(), b"correct")
}

///|
test "identity and sha2 blocks verify with optional root presence" {
  let hash = @cid.Multihash::identity(b"identity", @cid.Limits::default()).unwrap()
  let cid = @cid.Cid::v1(@cid.RAW_CODEC, hash, @cid.Limits::default()).unwrap()
  let block = @moon_car.Block::new(cid, b"identity")
  block.verify()
  let other = sample_block(b"sha2")
  let archive = @moon_car.Archive::decode(
    @moon_car.encode(@moon_car.Header::new([cid]), [block, other]),
  )
  archive.verify(require_roots=true)
}
