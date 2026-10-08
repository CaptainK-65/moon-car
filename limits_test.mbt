///|
test "writer accepts exact header size and rejects one byte less" {
  let block = sample_block(b"boundary")
  let header = @moon_car.Header::new([block.cid()])
  let encoded = header.encode()
  let (_, n) = @cid.decode_u64(encoded).unwrap()
  let size = encoded.length() - n
  assert_eq(header.encode(limits=@moon_car.Limits::new(max_header=size)), encoded)
  let rejected = try { ignore(header.encode(limits=@moon_car.Limits::new(max_header=size - 1))); false } catch { _ => true }
  assert_true(rejected)
}

///|
test "header CID budget is independent from block section budget" {
  let header = @moon_car.Header::new([sample_block(b"root").cid()])
  let bytes = header.encode(limits=@moon_car.Limits::new(max_block=1))
  let decoder = @moon_car.Decoder::new(limits=@moon_car.Limits::new(max_block=1))
  assert_eq(decoder.feed(bytes).length(), 1)
  decoder.finish()
}

///|
test "archive byte count and block count enforce exact boundaries" {
  let block = sample_block(b"limit")
  let bytes = @moon_car.encode(@moon_car.Header::new([]), [block])
  let limits = @moon_car.Limits::new(max_archive=bytes.length(), max_blocks=1)
  assert_eq(@moon_car.Archive::decode(bytes, limits~).length(), 1)
  for limits in [@moon_car.Limits::new(max_archive=bytes.length() - 1), @moon_car.Limits::new(max_blocks=0)] {
    let rejected = try { ignore(@moon_car.Archive::decode(bytes, limits~)); false } catch { @moon_car.LimitExceeded(_, _, _) => true; _ => false }
    assert_true(rejected)
  }
}
