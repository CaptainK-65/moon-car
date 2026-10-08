///|
// Decode an exact CID prefix without treating the block data as part of the CID.
fn decode_block(bytes : Bytes, limits : Limits) -> (Block, Int) raise CarError {
  let reader = match @cid.WireReader::new(bytes, cid_limits(limits)) {
    Ok(reader) => reader
    Err(err) => raise InvalidCid(err.to_string())
  }
  let first = match reader.read_varint("CID version or multihash") {
    Ok(n) => n
    Err(err) => raise InvalidCid(err.to_string())
  }
  match first {
    18UL => { // CIDv0 is exactly the sha2-256 multihash.
      let length = match reader.read_varint("CIDv0 digest length") {
        Ok(n) => n
        Err(err) => raise InvalidCid(err.to_string())
      }
      if length != 32UL {
        raise InvalidCid("CIDv0 digest must have 32 bytes")
      }
      match reader.read_fixed("CIDv0 digest", 32) {
        Ok(_) => ()
        Err(err) => raise InvalidCid(err.to_string())
      }
    }
    1UL => {
      // MoonLoom handles varint canonicality and bounds.
      for name in ["CID codec", "multihash code"] {
        match reader.read_varint(name) {
          Ok(_) => ()
          Err(err) => raise InvalidCid(err.to_string())
        }
      }
      let length = match reader.read_varint("digest length") {
        Ok(n) => bounded_length(n, 1024, "CID digest")
        Err(err) => raise InvalidCid(err.to_string())
      }
      match reader.read_fixed("digest", length) {
        Ok(_) => ()
        Err(err) => raise InvalidCid(err.to_string())
      }
    }
    _ => raise InvalidCid("unsupported CID version")
  }
  let cid_length = reader.position()
  let cid = checked_cid(bytes[:cid_length], limits)
  (Block::new(cid, bytes[cid_length:].to_owned()), cid_length)
}

///|
/// Encode a single CAR block section; this does not assert hash validity.
pub fn Block::encode(
  self : Block,
  limits? : Limits = Limits::default(),
) -> Bytes raise CarError {
  let cid = self.cid.to_bytes()
  ignore(checked_cid(cid, limits))
  if self.data.length() > limits.max_block - cid.length() {
    raise LimitExceeded(
      "block",
      limits.max_block.to_uint64(),
      cid.length().to_uint64() + self.data.length().to_uint64(),
    )
  }
  let n = cid.length() + self.data.length()
  @cid.encode_u64(n.to_uint64()) + cid + self.data
}
