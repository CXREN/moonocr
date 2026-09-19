///|
/// Blackbox tests for binarization.

///|
test "histogram counts every gray level" {
  // 2x2 image with values 10, 10, 200, 255.
  let img = @moonocr.Image::new(2, 2, b"\x0a\x0a\xc8\xff")
  let h = @moonocr.histogram(img)
  assert_eq(h.length(), 256)
  assert_eq(h[10], 2)
  assert_eq(h[200], 1)
  assert_eq(h[255], 1)
  assert_eq(h[0], 0)
  assert_eq(h[128], 0)
}

///|
test "binarize_fixed puts dark pixels at or below the threshold in ink" {
  let img = @moonocr.Image::new(3, 1, b"\x00\x80\xff")
  let out = @moonocr.binarize_fixed(img, 128)
  assert_eq(out.at(0, 0), 0)
  assert_eq(out.at(1, 0), 0)
  assert_eq(out.at(2, 0), 255)
}

///|
test "otsu_threshold splits a clean bimodal image" {
  // Half ink, half paper: threshold 0 separates them.
  let img = @moonocr.Image::new(2, 2, b"\x00\x00\xff\xff")
  assert_eq(@moonocr.otsu_threshold(img), 0)
  let out = @moonocr.binarize_otsu(img)
  assert_eq(out.at(0, 0), 0)
  assert_eq(out.at(1, 0), 0)
  assert_eq(out.at(0, 1), 255)
  assert_eq(out.at(1, 1), 255)
}

///|
test "otsu_threshold separates two mid-gray clusters" {
  let img = @moonocr.Image::new(4, 1, b"\x32\x32\xc8\xc8")
  assert_eq(@moonocr.otsu_threshold(img), 50)
}

///|
test "binarize_adaptive recovers text under a gradient" {
  // A single row that brightens from 0 to 255; with a 3-pixel window and
  // c = 20 the leftmost (dark) pixel is ink while the rightmost is paper.
  let img = @moonocr.Image::new(5, 1, b"\x00\x40\x80\xc0\xff")
  let out = @moonocr.binarize_adaptive(img, 3, 20)
  assert_eq(out.at(0, 0), 0)
  assert_eq(out.at(4, 0), 255)
}

///|
test "binarize_adaptive preserves an ink dot on a light field" {
  // A dark pixel surrounded by light neighbours is ink under the local mean.
  let img = @moonocr.Image::new(3, 3, b"\xff\xff\xff\xff\x10\xff\xff\xff\xff")
  let out = @moonocr.binarize_adaptive(img, 3, 20)
  assert_eq(out.at(1, 1), 0)
  assert_eq(out.at(0, 0), 255)
}

///|
test "binarize_sauvola separates a dark pixel from a light field" {
  // A dark centre surrounded by light neighbours is ink under Sauvola.
  let img = @moonocr.Image::new(3, 3, b"\xff\xff\xff\xff\x10\xff\xff\xff\xff")
  let out = @moonocr.binarize_sauvola(img, 3, 0.5, 128.0)
  assert_eq(out.at(1, 1), 0)
  assert_eq(out.at(0, 0), 255)
}

///|
test "binarize_sauvola leaves a uniform field as paper" {
  // A flat region has zero standard deviation, so the threshold drops below
  // the mean and nothing is flagged as ink (no noise).
  let img = @moonocr.Image::new(3, 3, b"\xc8\xc8\xc8\xc8\xc8\xc8\xc8\xc8\xc8")
  let out = @moonocr.binarize_sauvola(img, 3, 0.5, 128.0)
  for y = 0; y < 3; y = y + 1 {
    for x = 0; x < 3; x = x + 1 {
      assert_eq(out.at(x, y), 255)
    }
  }
}

///|
test "binarize_sauvola with k=0 thresholds at the local mean" {
  // With k = 0 the threshold is exactly the local mean, so only pixels darker
  // than the mean of their window become ink.
  let img = @moonocr.Image::new(3, 1, b"\x00\xff\xff")
  let out = @moonocr.binarize_sauvola(img, 3, 0.0, 128.0)
  assert_eq(out.at(0, 0), 0)
  assert_eq(out.at(1, 0), 255)
  assert_eq(out.at(2, 0), 255)
}
