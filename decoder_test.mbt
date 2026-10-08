///|
test "every split position preserves header and block events" {
  let block = sample_block(b"hello streaming")
  let bytes = @moon_car.encode(@moon_car.Header::new([block.cid()]), [block])
  for split in 0..=bytes.length() {
    let decoder = @moon_car.Decoder::new()
    let events = decoder.feed(bytes[:split])
    events.append(decoder.feed(bytes[split:]))
    decoder.finish()
    assert_eq(events.length(), 2)
    match events[1] {
      @moon_car.Block(actual, location) => {
        assert_eq(actual.data(), block.data())
        assert_eq(actual.cid(), block.cid())
        assert_eq(bytes[location.data_offset:].to_owned(), block.data())
      }
      _ => fail("expected block event")
    }
  }
}

///|
test "byte-at-a-time parsing supports empty payload and CIDv0" {
  let cid = @cid.cid_v0_from_content(b"", @cid.sha2_provider(), @cid.Limits::default()).unwrap()
  let bytes = @moon_car.encode(@moon_car.Header::new([cid]), [@moon_car.Block::new(cid, b"")])
  let decoder = @moon_car.Decoder::new()
  let events = []
  for i in 0..<bytes.length() { events.append(decoder.feed(bytes[i:i + 1])) }
  decoder.finish()
  assert_eq(events.length(), 2)
}

///|
test "all incomplete non-boundary prefixes fail at finish" {
  let block = sample_block(b"truncate me")
  let head = @moon_car.Header::new([block.cid()]).encode()
  let bytes = head + block.encode()
  for end in 0..<bytes.length() {
    if end == head.length() { continue } // Header-only CAR is structurally valid.
    let decoder = @moon_car.Decoder::new()
    ignore(decoder.feed(bytes[:end]))
    let rejected = try { decoder.finish(); false } catch { @moon_car.Truncated(_) => true; _ => false }
    assert_true(rejected)
  }
}

///|
test "overflow and noncanonical length prefixes poison the decoder" {
  for bytes in [b"\x80\x00", b"\xff\xff\xff\xff\xff\xff\xff\xff\xff\x02", b"\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80"] {
    let decoder = @moon_car.Decoder::new()
    let rejected = try { ignore(decoder.feed(bytes)); false } catch { @moon_car.InvalidVarint(_) => true; _ => false }
    assert_true(rejected)
    let poisoned = try { ignore(decoder.feed(b"")); false } catch { @moon_car.InvalidState(_) => true; _ => false }
    assert_true(poisoned)
  }
}

///|
test "declared section budget is enforced before its body arrives" {
  let decoder = @moon_car.Decoder::new(limits=@moon_car.Limits::new(max_header=10))
  let rejected = try { ignore(decoder.feed(b"\x0b")); false } catch { @moon_car.LimitExceeded("header", _, _) => true; _ => false }
  assert_true(rejected)
}
