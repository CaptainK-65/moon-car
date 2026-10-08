///|
fn main raise {
  let data = b"snapshot over a fragmented transport"
  let cid = @cid.cid_from_content(
    @cid.RAW_CODEC,
    @cid.Sha2_256,
    data,
    @cid.sha2_provider(),
    @cid.Limits::default(),
  ).unwrap()
  let bytes = @car.encode(@car.Header::new([cid]), [@car.Block::new(cid, data)])
  let decoder = @car.Decoder::new()
  let mut pos = 0
  let mut verified = 0
  while pos < bytes.length() {
    let end = pos + (bytes.length() - pos).min(7)
    for event in decoder.feed(bytes[pos:end]) {
      match event {
        Header(header) => println("snapshot roots: \{header.roots().length()}")
        Block(block, _) => {
          block.verify()
          verified += 1
        }
      }
    }
    pos = end
  }
  decoder.finish()
  println("stream: \{verified} verified block, no retained archive")
}
