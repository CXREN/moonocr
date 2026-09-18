///|
/// Blackbox tests for the PPM (color) decoder and encoder.

///|
test "parse_ppm decodes a P6 red and blue pair to grayscale" {
  // "P6\n2 1\n255\n" followed by red (255,0,0) and blue (0,0,255).
  let data = b"P6\n2 1\n255\n\xff\x00\x00\x00\x00\xff"
  let img = @moonocr.parse_ppm(data)
  assert_eq(img.width, 2)
  assert_eq(img.height, 1)
  assert_eq(img.at(0, 0), 76) // 0.299 * 255
  assert_eq(img.at(1, 0), 29) // 0.114 * 255
}

///|
test "parse_ppm decodes a P3 ASCII raster like its P6 twin" {
  let data = b"P3\n2 1\n255\n 255 0 0  0 0 255\n"
  let img = @moonocr.parse_ppm(data)
  assert_eq(img.width, 2)
  assert_eq(img.height, 1)
  assert_eq(img.at(0, 0), 76)
  assert_eq(img.at(1, 0), 29)
}

///|
test "write_ppm_p6 round-trips a grayscale image" {
  let img = @moonocr.Image::new(2, 1, b"\x64\xc8")
  let encoded = @moonocr.write_ppm_p6(img)
  let decoded = @moonocr.parse_ppm(encoded)
  assert_eq(decoded.width, 2)
  assert_eq(decoded.height, 1)
  assert_eq(decoded.at(0, 0), 100)
  assert_eq(decoded.at(1, 0), 200)
}

///|
test "parse_ppm rescales a non-255 maxval" {
  // maxval 100: red (100,0,0) -> gray 76, blue (0,0,100) -> gray 29.
  let data = b"P6\n2 1\n100\n\x64\x00\x00\x00\x00\x64"
  let img = @moonocr.parse_ppm(data)
  assert_eq(img.at(0, 0), 76)
  assert_eq(img.at(1, 0), 29)
}
