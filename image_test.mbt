///|
/// Blackbox tests for `Image` and grayscale conversion.
test "rgb_to_gray matches BT.601 for primaries and neutrals" {
  assert_eq(@moonocr.rgb_to_gray(255, 0, 0), 76)
  assert_eq(@moonocr.rgb_to_gray(0, 255, 0), 149)
  assert_eq(@moonocr.rgb_to_gray(0, 0, 255), 29)
  assert_eq(@moonocr.rgb_to_gray(255, 255, 255), 255)
  assert_eq(@moonocr.rgb_to_gray(0, 0, 0), 0)
}

///|
test "Image::from_packed converts RGB triplets to luminance" {
  // 2x1 image: a red pixel followed by a white pixel.
  let packed = b"\xff\x00\x00\xff\xff\xff"
  let img = @moonocr.Image::from_packed(2, 1, packed, 3)
  assert_eq(img.width, 2)
  assert_eq(img.height, 1)
  assert_eq(img.at(0, 0), 76)
  assert_eq(img.at(1, 0), 255)
}

///|
test "Image::new indexes row-major from the top-left" {
  let pixels = b"\x0a\x14\x1e\x28"
  let img = @moonocr.Image::new(2, 2, pixels)
  assert_eq(img.pixel_count(), 4)
  assert_eq(img.byte_length(), 4)
  assert_eq(img.at(0, 0), 10)
  assert_eq(img.at(1, 0), 20)
  assert_eq(img.at(0, 1), 30)
  assert_eq(img.at(1, 1), 40)
}
