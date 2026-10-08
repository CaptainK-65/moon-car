///|
enum Stage {
  Prefix
  Body(Int)
}

///|
/// Incremental parser retaining at most one bounded section plus a ten-byte prefix.
/// feed returns completed events only; finish is mandatory to detect truncation.
/// After a parse error the decoder is poisoned and cannot be resumed.
pub struct Decoder {
  limits : Limits
  prefix : @buffer.Buffer
  body : @buffer.Buffer
  mut stage : Stage
  mut header_seen : Bool
  mut position : Int
  mut section_start : Int
  mut body_start : Int
  mut count : Int
  mut closed : Bool
  mut failed : Bool
}

///|
pub fn Decoder::new(limits? : Limits = Limits::default()) -> Decoder {
  {
    limits,
    prefix: @buffer.Buffer(),
    body: @buffer.Buffer(),
    stage: Prefix,
    header_seen: false,
    position: 0,
    section_start: 0,
    body_start: 0,
    count: 0,
    closed: false,
    failed: false,
  }
}

///|
fn Decoder::accept(self : Decoder, byte : Byte) -> Event? raise CarError {
  if self.position >= self.limits.max_archive {
    raise LimitExceeded(
      "archive",
      self.limits.max_archive.to_uint64(),
      self.position.to_uint64() + 1UL,
    )
  }
  self.position += 1
  match self.stage {
    Prefix => {
      self.prefix.write_byte(byte)
      if self.prefix.length() > 10 {
        raise InvalidVarint(self.section_start)
      }
      if (byte.to_int() & 128) != 0 {
        if self.prefix.length() == 10 {
          raise InvalidVarint(self.section_start)
        }
        return None
      }
      let (length, _) = match @cid.decode_u64(self.prefix.to_bytes()) {
        Ok(value) => value
        Err(_) => raise InvalidVarint(self.section_start)
      }
      if length == 0UL {
        if self.header_seen {
          raise InvalidCid("zero-length block section")
        } else {
          raise InvalidHeader("zero-length header")
        }
      }
      if self.header_seen && self.count >= self.limits.max_blocks {
        raise LimitExceeded(
          "blocks",
          self.limits.max_blocks.to_uint64(),
          self.count.to_uint64() + 1UL,
        )
      }
      let name = if self.header_seen { "block" } else { "header" }
      let maximum = if self.header_seen {
        self.limits.max_block
      } else {
        self.limits.max_header
      }
      let length = bounded_length(length, maximum, name)
      if length > self.limits.max_archive - self.position {
        raise LimitExceeded(
          "archive",
          self.limits.max_archive.to_uint64(),
          self.position.to_uint64() + length.to_uint64(),
        )
      }
      self.stage = Body(length)
      self.body_start = self.position
      None
    }
    Body(length) => {
      self.body.write_byte(byte)
      if self.body.length() < length {
        return None
      }
      let bytes = self.body.to_bytes()
      let event = if !self.header_seen {
        let header = decode_header(bytes, self.limits)
        self.header_seen = true
        Event::Header(header)
      } else {
        let (block, cid_length) = decode_block(bytes, self.limits)
        self.count += 1
        Event::Block(block, {
          section_offset: self.section_start,
          data_offset: self.body_start + cid_length,
          data_length: length - cid_length,
          section_length: self.position - self.section_start,
        })
      }
      self.prefix.reset()
      self.body.reset()
      self.stage = Prefix
      self.section_start = self.position
      Some(event)
    }
  }
}

///|
pub fn Decoder::feed(
  self : Decoder,
  chunk : BytesView,
) -> Array[Event] raise CarError {
  if self.closed || self.failed {
    raise InvalidState("decoder is closed or failed")
  }
  errdefer {
    self.failed = true
  }
  let events = []
  for byte in chunk {
    if self.accept(byte) is Some(event) {
      events.push(event)
    }
  }
  events
}

///|
pub fn Decoder::finish(self : Decoder) -> Unit raise CarError {
  if self.closed || self.failed {
    raise InvalidState("decoder is closed or failed")
  }
  self.closed = true
  if !self.header_seen || self.prefix.length() != 0 || self.body.length() != 0 {
    raise Truncated(self.position)
  }
}

///|
pub fn Decoder::position(self : Decoder) -> Int {
  self.position
}
