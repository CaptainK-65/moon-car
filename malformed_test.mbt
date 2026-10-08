///|
fn fails_to_decode(bytes : Bytes) -> Bool {
  try {
    ignore(@moon_car.Archive::decode(bytes))
    false
  } catch {
    _ => true
  }
}

///|
test "zero-length block and invalid CID prefixes are rejected" {
  let head = @moon_car.Header::new([]).encode()
  for
    section in [
      b"\x00", b"\x01\x02", b"\x02\x12\x01", b"\x04\x01\x55\x12\x20", b"\x03\x81\x00\x55",
    ] {
    assert_true(fails_to_decode(head + section))
  }
}

///|
test "invalid root tags, identity prefix and CID digest fail validation" {
  let cid = sample_block(b"root").cid().to_bytes()
  for
    root in [
      @cbor.Tag(41UL, @cbor.Bytes(b"\x00" + cid)),
      @cbor.Tag(42UL, @cbor.Bytes(b"\x01" + cid)),
      @cbor.Tag(42UL, @cbor.Bytes(b"\x00\x01\x55\x12\x20")),
      @cbor.Bytes(b"\x00" + cid),
    ] {
    let header = @cbor.encode(
      @cbor.Map([
        (@cbor.Text("roots"), @cbor.Array([root])),
        (@cbor.Text("version"), @cbor.Unsigned(1UL)),
      ]),
    )
    assert_true(
      fails_to_decode(@cid.encode_u64(header.length().to_uint64()) + header),
    )
  }
}

///|
test "unsupported version, missing keys, extra keys and duplicate keys are rejected" {
  for
    fields in [
      [
        (@cbor.Text("roots"), @cbor.Array([])),
        (@cbor.Text("version"), @cbor.Unsigned(2UL)),
      ],
      [(@cbor.Text("roots"), @cbor.Array([]))],
      [
        (@cbor.Text("roots"), @cbor.Array([])),
        (@cbor.Text("roots"), @cbor.Array([])),
      ],
      [
        (@cbor.Text("roots"), @cbor.Array([])),
        (@cbor.Text("version"), @cbor.Unsigned(1UL)),
        (@cbor.Text("extra"), @cbor.Array([])),
      ],
    ] {
    let header = @cbor.encode(@cbor.Map(fields))
    assert_true(
      fails_to_decode(@cid.encode_u64(header.length().to_uint64()) + header),
    )
  }
}

///|
test "completed decoder rejects further input and repeated finish" {
  let decoder = @moon_car.Decoder::new()
  ignore(decoder.feed(@moon_car.Header::new([]).encode()))
  decoder.finish()
  let feed_failed = try {
    ignore(decoder.feed(b""))
    false
  } catch {
    @moon_car.InvalidState(_) => true
    _ => false
  }
  let finish_failed = try {
    decoder.finish()
    false
  } catch {
    @moon_car.InvalidState(_) => true
    _ => false
  }
  assert_true(feed_failed && finish_failed)
}

///|
test "root count is checked before decoding roots" {
  let head = @moon_car.Header::new([sample_block(b"root").cid()]).encode()
  let decoder = @moon_car.Decoder::new(
    limits=@moon_car.Limits::new(max_roots=0),
  )
  let rejected = try {
    ignore(decoder.feed(head))
    false
  } catch {
    @moon_car.LimitExceeded("roots", _, _) => true
    _ => false
  }
  assert_true(rejected)
}

///|
test "generated length and chunk matrix preserves binary payloads" {
  for size in [0, 1, 91, 92, 127, 128, 255, 256, 1024, 16384] {
    let data = Bytes::makei(size, i => ((i * 73 + 19) & 255).to_byte())
    let block = sample_block(data)
    let bytes = @moon_car.encode(@moon_car.Header::new([block.cid()]), [block])
    for chunk in [1, 2, 7, 64, 4096] {
      let decoder = @moon_car.Decoder::new()
      let mut pos = 0
      let mut blocks = 0
      while pos < bytes.length() {
        let end = pos + (bytes.length() - pos).min(chunk)
        for event in decoder.feed(bytes[pos:end]) {
          if event is @moon_car.Block(actual, location) {
            actual.verify()
            assert_eq(actual.data(), data)
            assert_eq(
              bytes[location.data_offset:location.data_offset + size].to_owned(),
              data,
            )
            blocks += 1
          }
        }
        pos = end
      }
      decoder.finish()
      assert_eq(blocks, 1)
    }
  }
}

///|
test "sha2-512 CID prefix is not confused with payload" {
  let data = b"sha512 archive"
  let cid = @cid.cid_from_content(
    @cid.RAW_CODEC,
    @cid.Sha2_512,
    data,
    @cid.sha2_provider(),
    @cid.Limits::default(),
  ).unwrap()
  let archive = @moon_car.Archive::decode(
    @moon_car.encode(@moon_car.Header::new([cid]), [
      @moon_car.Block::new(cid, data),
    ]),
  )
  assert_eq(archive.get(cid).data(), data)
  archive.verify(require_roots=true)
}
