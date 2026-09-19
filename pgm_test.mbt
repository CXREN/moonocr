///|
/// Blackbox tests for the Netpbm loader.
test "parse_pgm decodes a P5 binary grayscale image" {
  let data = b"P5\n2 2\n255\n\x00\x55\xaa\xff"
  let img = try! @moonocr.parse_pgm(data)
  assert_eq(img.width, 2)
  assert_eq(img.height, 2)
  assert_eq(img.at(0, 0), 0)
  assert_eq(img.at(1, 0), 85)
  assert_eq(img.at(0, 1), 170)
  assert_eq(img.at(1, 1), 255)
}

///|
test "parse_pgm rescales a P5 image with maxval 15" {
  // Four samples at 0, 5, 10, 15 scaled to 0..255.
  let data = b"P5\n2 2\n15\n\x00\x05\x0a\x0f"
  let img = try! @moonocr.parse_pgm(data)
  assert_eq(img.at(0, 0), 0)
  assert_eq(img.at(1, 0), 85)
  assert_eq(img.at(0, 1), 170)
  assert_eq(img.at(1, 1), 255)
}

///|
test "parse_pgm decodes a P4 packed bitmap" {
  // Row 0: black, white -> 0b10000000; row 1: white, black -> 0b01000000.
  let data = b"P4\n2 2\n\x80\x40"
  let img = try! @moonocr.parse_pgm(data)
  assert_eq(img.at(0, 0), 0)
  assert_eq(img.at(1, 0), 255)
  assert_eq(img.at(0, 1), 255)
  assert_eq(img.at(1, 1), 0)
}

///|
test "parse_pgm decodes a P2 ASCII grayscale image" {
  let data = b"P2\n3 1\n255\n0 128 255\n"
  let img = try! @moonocr.parse_pgm(data)
  assert_eq(img.width, 3)
  assert_eq(img.at(0, 0), 0)
  assert_eq(img.at(1, 0), 128)
  assert_eq(img.at(2, 0), 255)
}

///|
test "parse_pgm skips comments in the header" {
  let data = b"P5\n# a comment\n2 1\n255\n\x00\xff"
  let img = try! @moonocr.parse_pgm(data)
  assert_eq(img.width, 2)
  assert_eq(img.at(0, 0), 0)
  assert_eq(img.at(1, 0), 255)
}

///|
test "parse_pgm rejects non-Netpbm input" {
  @test.assert_raise(() => @moonocr.parse_pgm(b"GIF89a"))
}

///|
test "write_pgm_p5 round-trips through parse_pgm" {
  let img = @moonocr.Image::new(2, 2, b"\x00\x40\x80\xc0")
  let bytes = @moonocr.write_pgm_p5(img)
  let back = try! @moonocr.parse_pgm(bytes)
  assert_eq(back.width, 2)
  assert_eq(back.height, 2)
  assert_eq(back.at(0, 0), 0)
  assert_eq(back.at(1, 0), 64)
  assert_eq(back.at(0, 1), 128)
  assert_eq(back.at(1, 1), 192)
}

///|
test "parse_pgm decodes a P1 ASCII bitmap" {
  // PBM convention: 1 is black (ink), 0 is white (paper).
  let data = b"P1\n3 2\n1 0 1\n0 1 0\n"
  let img = try! @moonocr.parse_pgm(data)
  assert_eq(img.width, 3)
  assert_eq(img.height, 2)
  assert_eq(img.at(0, 0), 0)
  assert_eq(img.at(1, 0), 255)
  assert_eq(img.at(2, 0), 0)
  assert_eq(img.at(0, 1), 255)
  assert_eq(img.at(1, 1), 0)
  assert_eq(img.at(2, 1), 255)
}

///|
test "parse_pgm skips comments inside a P1 raster" {
  let data = b"P1\n2 2\n# bitmap\n1 0\n0 1\n"
  let img = try! @moonocr.parse_pgm(data)
  assert_eq(img.at(0, 0), 0)
  assert_eq(img.at(1, 0), 255)
  assert_eq(img.at(0, 1), 255)
  assert_eq(img.at(1, 1), 0)
}
