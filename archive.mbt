///|
pub struct Entry {
  cid : @cid.Cid
  location : Location
}

///|
pub fn Entry::cid(self : Entry) -> @cid.Cid { self.cid }

///|
pub fn Entry::location(self : Entry) -> Location { self.location }

///|
/// Validated CAR bytes with an exact full-CID offset index. Duplicate sections
/// remain visible in source order. No payloads are retained in the index.
pub struct Archive {
  bytes : Bytes
  header : Header
  entries : Array[Entry]
  by_cid : Map[Bytes, Array[Entry]]
  limits : Limits
}

///|
pub fn Archive::decode(bytes : Bytes, limits? : Limits = Limits::new()) -> Archive raise CarError {
  budget("archive", bytes.length(), limits.max_archive)
  let decoder = Decoder::new(limits~)
  let entries = []
  let by_cid : Map[Bytes, Array[Entry]] = Map([])
  let mut header = None
  let mut pos = 0
  while pos < bytes.length() {
    let end = pos + (bytes.length() - pos).min(4096)
    for event in decoder.feed(bytes[pos:end]) {
      match event {
        Header(h) => header = Some(h)
        Block(block, location) => {
          let entry = Entry::{ cid: block.cid, location }
          entries.push(entry)
          by_cid.get_or_init(block.cid.to_bytes(), () => []).push(entry)
        }
      }
    }
    pos = end
  }
  decoder.finish()
  match header {
    Some(header) => { bytes, header, entries, by_cid, limits }
    None => raise InvalidHeader("missing CAR header")
  }
}

///|
pub fn Archive::header(self : Archive) -> Header { self.header }

///|
pub fn Archive::entries(self : Archive) -> Array[Entry] { self.entries.copy() }

///|
pub fn Archive::bytes(self : Archive) -> Bytes { self.bytes }

///|
pub fn Archive::length(self : Archive) -> Int { self.entries.length() }

///|
pub fn Archive::locations(self : Archive, cid : @cid.Cid) -> Array[Location] {
  match self.by_cid.get(cid.to_bytes()) {
    Some(entries) => entries.map(entry => entry.location)
    None => []
  }
}

///|
fn Archive::read_entry(self : Archive, entry : Entry) -> Block raise CarError {
  let loc = entry.location
  let bytes = self.bytes[loc.section_offset:loc.section_offset + loc.section_length]
  let prefix_length = match @cid.decode_u64(bytes) {
    Ok((_, n)) => n
    Err(_) => raise InvalidVarint(loc.section_offset)
  }
  let (block, _) = decode_block(bytes[prefix_length:].to_owned(), self.limits)
  if block.cid != entry.cid { raise InvalidCid("index entry CID mismatch") }
  block
}

///|
/// Return the first section for an exact CID. Hash integrity is checked separately.
pub fn Archive::get(self : Archive, cid : @cid.Cid) -> Block raise CarError {
  match self.by_cid.get(cid.to_bytes()) {
    Some(entries) => self.read_entry(entries[0])
    None => raise NotFound
  }
}

///|
pub fn Archive::get_all(self : Archive, cid : @cid.Cid) -> Array[Block] raise CarError {
  match self.by_cid.get(cid.to_bytes()) {
    Some(entries) => entries.map(entry => self.read_entry(entry))
    None => []
  }
}

///|
/// Check root block presence only. This does not prove transitive DAG closure.
pub fn Archive::require_roots(self : Archive) -> Unit raise CarError {
  for root in self.header.roots {
    if !self.by_cid.contains(root.to_bytes()) {
      let text = match root.to_text() { Ok(s) => s; Err(_) => "unprintable CID" }
      raise MissingRoot(text)
    }
  }
}
