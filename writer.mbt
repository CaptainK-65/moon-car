///|
/// Produces one framed section per call. The caller owns the output sink.
/// Errors do not advance the writer; successfully emitted sections are immutable.
pub struct Writer {
  limits : Limits
  header : Header
  mut position : Int
  mut count : Int
  mut started : Bool
}

///|
pub fn Writer::new(
  header : Header,
  limits? : Limits = Limits::default(),
) -> Writer {
  { limits, header, position: 0, count: 0, started: false, }
}

///|
pub fn Writer::start(self : Writer) -> Bytes raise CarError {
  if self.started {
    raise InvalidState("writer already started")
  }
  let bytes = self.header.encode(limits=self.limits)
  budget("archive", bytes.length(), self.limits.max_archive)
  self.position = bytes.length()
  self.started = true
  bytes
}

///|
pub fn Writer::write(
  self : Writer,
  block : Block,
) -> (Bytes, Location) raise CarError {
  if !self.started {
    raise InvalidState("writer must start before blocks")
  }
  if self.count >= self.limits.max_blocks {
    raise LimitExceeded(
      "blocks",
      self.limits.max_blocks.to_uint64(),
      self.count.to_uint64() + 1UL,
    )
  }
  let bytes = block.encode(limits=self.limits)
  if bytes.length() > self.limits.max_archive - self.position {
    raise LimitExceeded(
      "archive",
      self.limits.max_archive.to_uint64(),
      self.position.to_uint64() + bytes.length().to_uint64(),
    )
  }
  let location = Location::{
    section_offset: self.position,
    data_offset: self.position + bytes.length() - block.data.length(),
    data_length: block.data.length(),
    section_length: bytes.length(),
  }
  self.position += bytes.length()
  self.count += 1
  (bytes, location)
}

///|
pub fn Writer::position(self : Writer) -> Int {
  self.position
}

///|
/// Write blocks in caller order. Equal roots and block order yield equal bytes.
pub fn encode(
  header : Header,
  blocks : Array[Block],
  limits? : Limits = Limits::default(),
) -> Bytes raise CarError {
  let writer = Writer::new(header, limits~)
  let buffer = @buffer.Buffer()
  buffer.write_bytes(writer.start())
  for block in blocks {
    buffer.write_bytes(writer.write(block).0)
  }
  buffer.to_bytes()
}
