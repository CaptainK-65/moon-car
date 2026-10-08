///|
test "decoder rejects bytes beyond exact archive budget" {
  let head = @moon_car.Header::new([]).encode()
  let decoder = @moon_car.Decoder::new(
    limits=@moon_car.Limits::new(max_archive=head.length()),
  )
  ignore(decoder.feed(head))
  assert_eq(decoder.position(), head.length())
  let rejected = try {
    ignore(decoder.feed(b"\x01"))
    false
  } catch {
    @moon_car.LimitExceeded("archive", _, _) => true
    _ => false
  }
  assert_true(rejected)
}

///|
test "writer retry after rejected block preserves its section offset" {
  let writer = @moon_car.Writer::new(
    @moon_car.Header::new([]),
    limits=@moon_car.Limits::new(max_block=40),
  )
  let head = writer.start()
  let rejected = try {
    ignore(writer.write(sample_block(b"too long")))
    false
  } catch {
    @moon_car.LimitExceeded("block", _, _) => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(writer.position(), head.length())
  let (_, location) = writer.write(sample_block(b"x"))
  assert_eq(location.section_offset, head.length())
  let twice = try {
    ignore(writer.start())
    false
  } catch {
    @moon_car.InvalidState(_) => true
    _ => false
  }
  assert_true(twice)
}

///|
test "writer total budget rejects framing without partial state changes" {
  let writer = @moon_car.Writer::new(
    @moon_car.Header::new([]),
    limits=@moon_car.Limits::new(max_archive=20),
  )
  let head = writer.start()
  let rejected = try {
    ignore(writer.write(sample_block(b"x")))
    false
  } catch {
    @moon_car.LimitExceeded("archive", _, _) => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(writer.position(), head.length())
}

///|
test "absent CID queries and snapshot arrays cannot mutate the archive" {
  let block = sample_block(b"a")
  let bytes = @moon_car.encode(@moon_car.Header::new([]), [block])
  let archive = @moon_car.Archive::decode(bytes)
  assert_eq(archive.bytes(), bytes)
  assert_eq(archive.entries()[0].cid(), block.cid())
  let entries = archive.entries()
  entries.clear()
  assert_eq(archive.length(), 1)
  let absent = sample_block(b"b").cid()
  assert_eq(archive.locations(absent).length(), 0)
  assert_eq(archive.get_all(absent).length(), 0)
}

///|
test "block verification rejects mismatches and unsupported hash algorithms" {
  let good = sample_block(b"good")
  let bad = @moon_car.Block::new(good.cid(), b"bad")
  let rejected = try {
    bad.verify()
    false
  } catch {
    @moon_car.Integrity(_, _) => true
    _ => false
  }
  assert_true(rejected)
  let cid = @cid.Cid::decode_bytes(
    b"\x01\x55\x7f\x01\x01",
    @cid.Limits::default(),
  ).unwrap()
  let unknown = @moon_car.Block::new(cid, b"x")
  let archive = @moon_car.Archive::decode(
    @moon_car.encode(@moon_car.Header::new([]), [unknown]),
  )
  let unsupported = try {
    archive.verify()
    false
  } catch {
    @moon_car.Integrity(_, _) => true
    _ => false
  }
  assert_true(unsupported)
}

///|
test "header profiles reject trailing, indefinite and reserved CBOR" {
  for
    body in [
      b"\xa2\x65roots\x80\x67version\x01\x00", b"\xbf", b"\xa2\x65roots\x9f", b"\xa2\x65roots\x9c",
      b"\xa2\x65roots\x80\x67version\x21",
    ] {
    assert_true(
      fails_to_decode(@cid.encode_u64(body.length().to_uint64()) + body),
    )
  }
}
