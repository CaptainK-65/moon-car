///|
async fn read_bounded(path : String, maximum : Int) -> Bytes {
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  let buffer = @buffer.Buffer()
  while @io.Reader::read_some(file, max_len=4096) is Some(chunk) {
    if chunk.length() > maximum - buffer.length() {
      fail("file exceeds byte budget")
    }
    buffer.write_bytes(chunk)
  }
  buffer.to_bytes()
}

///|
async fn main {
  let args = @env.args()
  match args {
    [_, "pack", output, .. inputs] if inputs.length() > 0 => {
      if inputs.length() > 1024 {
        fail("input count exceeds root budget")
      }
      let blocks = []
      let mut total = 0
      for input in inputs {
        let data = read_bounded(input, 16 * 1024 * 1024 - 36)
        if data.length() > 256 * 1024 * 1024 - total {
          fail("input payloads exceed archive budget")
        }
        total += data.length()
        let cid = @cid.cid_from_content(
          @cid.RAW_CODEC,
          @cid.Sha2_256,
          data,
          @cid.sha2_provider(),
          @cid.Limits::new(max_input_bytes=16 * 1024 * 1024),
        ).unwrap()
        blocks.push(@car.Block::new(cid, data))
      }
      let bytes = @car.encode(
        @car.Header::new(blocks.map(b => b.cid())),
        blocks,
      )
      @fs.write_file(output, bytes)
      println("wrote \{bytes.length()} bytes, \{blocks.length()} blocks")
    }
    [_, "inspect", input] => {
      let archive = @car.Archive::decode(read_bounded(input, 256 * 1024 * 1024))
      for root in archive.header().roots() {
        println("root \{root.to_text().unwrap()}")
      }
      for entry in archive.entries() {
        let loc = entry.location()
        println(
          "\{entry.cid().to_text().unwrap()} section=\{loc.section_offset} data=\{loc.data_offset} length=\{loc.data_length}",
        )
      }
      println(
        "structurally valid CARv1; \{archive.length()} blocks; hashes not checked",
      )
    }
    [_, "verify", input] => {
      let archive = @car.Archive::decode(read_bounded(input, 256 * 1024 * 1024))
      archive.verify(require_roots=true)
      println("verified \{archive.length()} blocks; all root blocks present")
    }
    [_, "rewrite", input, output] => {
      let archive = @car.Archive::decode(read_bounded(input, 256 * 1024 * 1024))
      archive.verify()
      let writer = @car.Writer::new(archive.header())
      let file = @fs.open(output, mode=WriteOnly, create_mode=CreateNew)
      defer file.close()
      @io.Writer::write(file, writer.start())
      for i in 0..<archive.length() {
        @io.Writer::write(file, writer.write(archive.block_at(i)).0)
      }
      println("rewrote \{archive.length()} verified blocks in source order")
    }
    [_, "get", input, cid_text, output] => {
      let archive = @car.Archive::decode(read_bounded(input, 256 * 1024 * 1024))
      let cid = @cid.Cid::parse(cid_text, @cid.Limits::default()).unwrap()
      let block = archive.get(cid)
      block.verify()
      @fs.write_file(output, block.data())
      println("extracted and verified \{block.data().length()} bytes")
    }
    _ => {
      println(
        "MoonCAR 0.1.0\nUsage: moon run cmd/mooncar --target native -- pack OUT.car FILE...\n       inspect IN.car\n       verify IN.car\n       get IN.car CID OUT\n       rewrite IN.car NEW.car",
      )
      if args.length() > 1 && args[1] != "--help" {
        fail("invalid arguments")
      }
    }
  }
}
