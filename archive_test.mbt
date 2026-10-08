///|
test "exact CID index separates codecs with the same digest" {
  let raw = sample_block(b"shared digest")
  let other_cid = @cid.Cid::v1(
    @cid.DAG_PB_CODEC,
    raw.cid().hash,
    @cid.Limits::default(),
  ).unwrap()
  let other = @moon_car.Block::new(other_cid, raw.data())
  let archive = @moon_car.Archive::decode(
    @moon_car.encode(@moon_car.Header::new([raw.cid()]), [raw, other, raw]),
  )
  assert_eq(archive.length(), 3)
  assert_eq(archive.locations(raw.cid()).length(), 2)
  assert_eq(archive.locations(other_cid).length(), 1)
  assert_eq(archive.get(other_cid).cid(), other_cid)
  assert_eq(archive.get_all(raw.cid()).length(), 2)
  assert_eq(archive.block_at(1).cid(), other_cid)
  archive.require_roots()
}

///|
test "source-order reads reject out of bounds indexes" {
  let archive = @moon_car.Archive::decode(
    @moon_car.encode(@moon_car.Header::new([]), []),
  )
  for index in [-1, 0, 2147483647] {
    let rejected = try {
      ignore(archive.block_at(index))
      false
    } catch {
      @moon_car.InvalidState(_) => true
      _ => false
    }
    assert_true(rejected)
  }
}

///|
test "root presence is independent from structural validity" {
  let root = sample_block(b"absent root")
  let archive = @moon_car.Archive::decode(
    @moon_car.encode(@moon_car.Header::new([root.cid()]), []),
  )
  assert_eq(archive.length(), 0)
  let absent = try {
    archive.require_roots()
    false
  } catch {
    @moon_car.MissingRoot(_) => true
    _ => false
  }
  assert_true(absent)
  let not_found = try {
    ignore(archive.get(root.cid()))
    false
  } catch {
    @moon_car.NotFound => true
    _ => false
  }
  assert_true(not_found)
}
