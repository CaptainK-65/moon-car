///|
test "official IPLD fixture has independently specified block offsets" {
  let archive = @moon_car.Archive::decode(official_fixture)
  assert_eq(archive.length(), 8)
  assert_eq(archive.header().roots().length(), 2)
  let expected = [
    (100, 137, 55),
    (192, 228, 97),
    (325, 362, 4),
    (366, 402, 94),
    (496, 533, 4),
    (537, 572, 47),
    (619, 656, 4),
    (660, 697, 18),
  ]
  for i in 0..<expected.length() {
    let location = archive.entries()[i].location()
    let (section, data, length) = expected[i]
    assert_eq(location.section_offset, section)
    assert_eq(location.data_offset, data)
    assert_eq(location.data_length, length)
  }
  archive.verify(require_roots=true)
}

///|
test "rewriting independent reference fixture preserves every byte" {
  let archive = @moon_car.Archive::decode(official_fixture)
  let blocks = Array::makei(archive.length(), i => archive.block_at(i))
  assert_eq(@moon_car.encode(archive.header(), blocks), official_fixture)
}
