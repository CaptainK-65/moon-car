///|
pub(all) suberror CarError {
  InvalidHeader(String)
  InvalidCid(String)
  InvalidVarint(Int)
  LimitExceeded(String, UInt64, UInt64)
  Truncated(Int)
  InvalidState(String)
  Integrity(Int, String)
  MissingRoot(String)
  NotFound
} derive(Debug)

///|
pub extend CarError with @debug.Debug::{to_repr}

///|
/// Parser budgets apply before allocating a declared payload.
pub struct Limits {
  max_header : Int
  max_block : Int
  max_roots : Int
  max_blocks : Int
  max_archive : Int
}

///|
pub fn Limits::new(
  max_header? : Int = 1024 * 1024,
  max_block? : Int = 16 * 1024 * 1024,
  max_roots? : Int = 1024,
  max_blocks? : Int = 1000000,
  max_archive? : Int = 256 * 1024 * 1024,
) -> Limits raise CarError {
  if max_header <= 0 || max_block <= 0 || max_roots < 0 ||
    max_blocks < 0 || max_archive <= 0 {
    raise InvalidState("limits must be positive; root and block counts may be zero")
  }
  { max_header, max_block, max_roots, max_blocks, max_archive }
}

///|
pub struct Header {
  roots : Array[@cid.Cid]
}

///|
pub fn Header::new(roots : Array[@cid.Cid]) -> Header {
  { roots: roots.copy() }
}

///|
pub fn Header::roots(self : Header) -> Array[@cid.Cid] {
  self.roots.copy()
}

///|
pub struct Block {
  cid : @cid.Cid
  data : Bytes
}

///|
pub fn Block::new(cid : @cid.Cid, data : Bytes) -> Block {
  { cid, data }
}

///|
pub fn Block::cid(self : Block) -> @cid.Cid { self.cid }

///|
pub fn Block::data(self : Block) -> Bytes { self.data }

///|
/// Absolute offsets into the CARv1 bytes, including the header and framing.
pub(all) struct Location {
  section_offset : Int
  data_offset : Int
  data_length : Int
  section_length : Int
} derive(Debug)

///|
pub extend Location with @debug.Debug::{to_repr}

///|
pub(all) enum Event {
  Header(Header)
  Block(Block, Location)
}

///|
fn cid_limits(limits : Limits) -> @cid.Limits {
  @cid.Limits::new(max_input_bytes=limits.max_block, max_digest_bytes=1024)
}

///|
fn checked_cid(bytes : BytesView, limits : Limits) -> @cid.Cid raise CarError {
  match @cid.Cid::decode_bytes(bytes, cid_limits(limits)) {
    Ok(cid) => cid
    Err(err) => raise InvalidCid(err.to_string())
  }
}

///|
fn budget(name : String, actual : Int, maximum : Int) -> Unit raise CarError {
  if actual > maximum {
    raise LimitExceeded(name, maximum.to_uint64(), actual.to_uint64())
  }
}
