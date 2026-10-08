///|
fn main raise {
  let data = b"a reproducible distribution payload"
  let cid = @cid.cid_from_content(
    @cid.RAW_CODEC,
    @cid.Sha2_256,
    data,
    @cid.sha2_provider(),
    @cid.Limits::default(),
  ).unwrap()
  let bytes = @car.encode(@car.Header::new([cid]), [@car.Block::new(cid, data)])
  let archive = @car.Archive::decode(bytes)
  archive.verify(require_roots=true)
  println(
    "distribution: \{bytes.length()} CAR bytes, \{archive.length()} verified block",
  )
  println(cid.to_text().unwrap())
}
