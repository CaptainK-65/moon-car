///|
fn main raise {
  let blocks = [b"first object", b"requested object", b"last object"].map(data => {
    let cid = @cid.cid_from_content(@cid.RAW_CODEC, @cid.Sha2_256, data,
      @cid.sha2_provider(), @cid.Limits::default()).unwrap()
    @car.Block::new(cid, data)
  })
  let target = blocks[1].cid()
  let archive = @car.Archive::decode(@car.encode(@car.Header::new([target]), blocks))
  let block = archive.get(target)
  block.verify()
  let location = archive.locations(target)[0]
  println("lookup: \{block.data().length()} bytes at offset \{location.data_offset}")
  println(target.to_text().unwrap())
}
