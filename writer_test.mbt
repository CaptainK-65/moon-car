///|
fn sample_block(data : Bytes) -> @moon_car.Block {
  let cid = @cid.cid_from_content(
    @cid.RAW_CODEC,
    @cid.Sha2_256,
    data,
    @cid.sha2_provider(),
    @cid.Limits::default(),
  ).unwrap()
  @moon_car.Block::new(cid, data)
}

///|
test "writer yields real absolute payload offsets" {
  let block = sample_block(b"hello")
  let writer = @moon_car.Writer::new(@moon_car.Header::new([block.cid()]))
  let head = writer.start()
  let (section, offset) = writer.write(block)
  let bytes = head + section
  assert_eq(
    bytes[offset.data_offset:offset.data_offset + offset.data_length].to_owned(),
    b"hello",
  )
  assert_eq(offset.section_offset, head.length())
  assert_eq(writer.position(), bytes.length())
}

///|
test "writer fails atomically on over-limit blocks and state misuse" {
  let writer = @moon_car.Writer::new(
    @moon_car.Header::new([]),
    limits=@moon_car.Limits::new(max_blocks=1),
  )
  let before = try {
    ignore(writer.write(sample_block(b"x")))
    false
  } catch {
    _ => true
  }
  assert_true(before)
  ignore(writer.start())
  ignore(writer.write(sample_block(b"x")))
  let pos = writer.position()
  let rejected = try {
    ignore(writer.write(sample_block(b"y")))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(writer.position(), pos)
}
