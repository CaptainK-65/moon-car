///|
// A schema-only preflight prevents the generic CBOR decoder from seeing recursive
// or attacker-sized structures. It is not a general-purpose CBOR parser.
priv struct HeaderCursor {
  bytes : Bytes
  mut pos : Int
}

///|
fn HeaderCursor::take(self : HeaderCursor, n : Int) -> BytesView raise CarError {
  if n < 0 || n > self.bytes.length() - self.pos {
    raise InvalidHeader("truncated CBOR header")
  }
  let start = self.pos
  self.pos += n
  self.bytes[start:self.pos]
}

///|
fn HeaderCursor::argument(self : HeaderCursor, major : Int) -> UInt64 raise CarError {
  let first = self.take(1)[0].to_int()
  if first >> 5 != major { raise InvalidHeader("unexpected CBOR type") }
  let ai = first & 31
  if ai < 24 { return ai.to_uint64() }
  let count = match ai {
    24 => 1
    25 => 2
    26 => 4
    27 => 8
    _ => raise InvalidHeader("indefinite or reserved CBOR length")
  }
  let mut value = 0UL
  for byte in self.take(count) { value = (value << 8) | byte.to_uint64() }
  let minimum = match count {
    1 => 24UL
    2 => 256UL
    4 => 65536UL
    _ => 4294967296UL
  }
  if value < minimum { raise InvalidHeader("non-minimal CBOR integer") }
  value
}

///|
fn bounded_length(value : UInt64, maximum : Int, name : String) -> Int raise CarError {
  if value > maximum.to_uint64() {
    raise LimitExceeded(name, maximum.to_uint64(), value)
  }
  value.to_int()
}

///|
fn HeaderCursor::key(self : HeaderCursor, key : Bytes) -> Unit raise CarError {
  let n = bounded_length(self.argument(3), key.length(), "header key")
  if self.take(n).to_owned() != key { raise InvalidHeader("unexpected header key or key order") }
}

///|
fn decode_header(bytes : Bytes, limits : Limits) -> Header raise CarError {
  budget("header", bytes.length(), limits.max_header)
  let cursor = HeaderCursor::{ bytes, pos: 0 }
  if cursor.argument(5) != 2UL { raise InvalidHeader("expected roots and version map") }
  cursor.key(b"roots")
  let count = bounded_length(cursor.argument(4), limits.max_roots, "roots")
  for _ in 0..<count {
    if cursor.argument(6) != 42UL { raise InvalidHeader("root must use CID tag 42") }
    let n = bounded_length(cursor.argument(2), limits.max_header, "root CID")
    let link = cursor.take(n)
    if n < 2 || link[0] != b'\x00' { raise InvalidHeader("CID link requires identity prefix") }
    ignore(checked_cid(link[1:], limits))
  }
  cursor.key(b"version")
  if cursor.argument(0) != 1UL { raise InvalidHeader("only CAR version 1 is supported") }
  if cursor.pos != bytes.length() { raise InvalidHeader("trailing header bytes") }
  // Safe after bounded, non-recursive schema validation above.
  let value = try @cbor.decode(bytes) catch {
    err => raise InvalidHeader(err.to_string())
  }
  let roots = []
  match value {
    @cbor.Map(fields) => for (key, value) in fields {
      if key == @cbor.Text("roots") {
        match value {
          @cbor.Array(items) => for item in items {
            match item {
              @cbor.Tag(42UL, @cbor.Bytes(link)) => roots.push(checked_cid(link[1:], limits))
              _ => raise InvalidHeader("invalid root")
            }
          }
          _ => raise InvalidHeader("invalid roots")
        }
      }
    }
    _ => raise InvalidHeader("invalid map")
  }
  Header::new(roots)
}

///|
fn encode_header(header : Header, limits : Limits) -> Bytes raise CarError {
  budget("roots", header.roots.length(), limits.max_roots)
  let mut size = 18 // map, keys, version and shortest array marker
  let links = []
  for root in header.roots {
    let bytes = root.to_bytes()
    ignore(checked_cid(bytes, limits))
    // Account for maximum CBOR overhead before building a potentially large value.
    if bytes.length() > limits.max_header - size - 12 {
      raise LimitExceeded("header", limits.max_header.to_uint64(), (size.to_uint64() + bytes.length().to_uint64() + 12UL))
    }
    size += bytes.length() + 12
    links.push(@cbor.Tag(42UL, @cbor.Bytes(b"\x00" + bytes)))
  }
  let bytes = @cbor.encode(@cbor.Map([
    (@cbor.Text("roots"), @cbor.Array(links)),
    (@cbor.Text("version"), @cbor.Unsigned(1UL)),
  ]))
  budget("header", bytes.length(), limits.max_header)
  bytes
}

///|
/// Encode a canonical CARv1 header including its unsigned-varint length prefix.
pub fn Header::encode(self : Header, limits? : Limits = Limits::new()) -> Bytes raise CarError {
  let bytes = encode_header(self, limits)
  @cid.encode_u64(bytes.length().to_uint64()) + bytes
}
