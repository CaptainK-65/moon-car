///|
test "header takes ownership of root list and returns copies" {
  let cid = @cid.cid_from_content(@cid.RAW_CODEC, @cid.Sha2_256, b"root",
    @cid.sha2_provider(), @cid.Limits::default()).unwrap()
  let roots = [cid]
  let header = @moon_car.Header::new(roots)
  roots.clear()
  let copy = header.roots()
  copy.clear()
  assert_eq(header.roots().length(), 1)
}

///|
test "limits reject invalid budgets" {
  let rejected = try {
    ignore(@moon_car.Limits::new(max_block=0))
    false
  } catch { @moon_car.InvalidState(_) => true }
  assert_true(rejected)
  ignore(@moon_car.Limits::new(max_roots=0, max_blocks=0))
}
