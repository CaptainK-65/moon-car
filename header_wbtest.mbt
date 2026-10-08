///|
test "canonical empty header matches published wire format" {
  let limits = Limits::new()
  let bytes = b"\xa2\x65roots\x80\x67version\x01"
  assert_eq(encode_header(Header::new([]), limits), bytes)
  assert_eq(decode_header(bytes, limits).roots().length(), 0)
}

///|
test "recursive and huge roots are rejected before generic CBOR decode" {
  for
    bytes in [
      b"\xa2\x65roots\x81\x81\x81\x81", b"\xa2\x65roots\x9b\xff\xff\xff\xff\xff\xff\xff\xff",
      b"\xa2\x67version\x01\x65roots\x80", b"\xa2\x65roots\x80\x67version\x18\x01",
      b"\xa2\x65roots\x80\x67version\x02",
    ] {
    let rejected = try {
      ignore(decode_header(bytes, Limits::new()))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}
