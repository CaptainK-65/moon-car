///|
/// Verify a block against its CID using a caller-selected hash provider.
pub fn Block::verify(
  self : Block,
  provider? : @cid.HashProvider = @cid.builtin_hash_provider(),
  limits? : Limits = Limits::default(),
) -> Unit raise CarError {
  let cid_bytes = self.cid.to_bytes()
  ignore(checked_cid(cid_bytes, limits))
  let length = cid_bytes.length().to_uint64() + self.data.length().to_uint64()
  if length > limits.max_block.to_uint64() {
    raise LimitExceeded("block", limits.max_block.to_uint64(), length)
  }
  match self.cid.verify(self.data, provider, cid_limits(limits)) {
    Ok(_) => ()
    Err(err) => raise Integrity(0, err.to_string())
  }
}

///|
/// Verifies every section, including all duplicate occurrences. A matching earlier
/// duplicate must never hide a corrupt later duplicate. Root presence is optional.
pub fn Archive::verify(
  self : Archive,
  provider? : @cid.HashProvider = @cid.builtin_hash_provider(),
  require_roots? : Bool = false,
) -> Unit raise CarError {
  for entry in self.entries {
    let block = self.read_entry(entry)
    match block.cid.verify(block.data, provider, cid_limits(self.limits)) {
      Ok(_) => ()
      Err(err) =>
        raise Integrity(entry.location.section_offset, err.to_string())
    }
  }
  if require_roots {
    self.require_roots()
  }
}
