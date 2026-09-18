///|
/// Blackbox tests for glyph feature extraction.

///|
test "glyph_grid keeps a solid block solid at the same size" {
  let img = @moonocr.Image::new(2, 2, b"\x00\x00\x00\x00")
  let cs = @moonocr.connected_components(img)
  let g = @moonocr.glyph_grid(img, cs[0], 2)
  assert_eq(g.length(), 4)
  assert_eq(g[0], 255)
  assert_eq(g[1], 255)
  assert_eq(g[2], 255)
  assert_eq(g[3], 255)
}

///|
test "glyph_grid preserves a paper corner at equal size" {
  // An L-shaped glyph: three ink pixels with a paper corner at bottom-right.
  let img = @moonocr.Image::new(2, 2, b"\x00\x00\x00\xff")
  let cs = @moonocr.connected_components(img)
  let g = @moonocr.glyph_grid(img, cs[0], 2)
  assert_eq(g[0], 255)
  assert_eq(g[1], 255)
  assert_eq(g[2], 255)
  assert_eq(g[3], 0)
}

///|
test "glyph_grid upscales a single ink pixel without empty cells" {
  let img = @moonocr.Image::new(2, 1, b"\x00\xff")
  let cs = @moonocr.connected_components(img)
  let g = @moonocr.glyph_grid(img, cs[0], 2)
  assert_eq(g[0], 255)
  assert_eq(g[1], 255)
  assert_eq(g[2], 255)
  assert_eq(g[3], 255)
}

///|
test "glyph_grid preserves aspect ratio instead of stretching" {
  // A 2x1 horizontal bar stays one row tall in the normalized 2x2 grid.
  let img = @moonocr.Image::new(2, 1, b"\x00\x00")
  let cs = @moonocr.connected_components(img)
  let g = @moonocr.glyph_grid(img, cs[0], 2)
  assert_eq(g[0], 255)
  assert_eq(g[1], 255)
  assert_eq(g[2], 0)
  assert_eq(g[3], 0)
}

///|
test "glyph_grid downscales a larger glyph" {
  let img = @moonocr.Image::new(
    4, 4, b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00",
  )
  let cs = @moonocr.connected_components(img)
  let g = @moonocr.glyph_grid(img, cs[0], 2)
  assert_eq(g[0], 255)
  assert_eq(g[1], 255)
  assert_eq(g[2], 255)
  assert_eq(g[3], 255)
}

///|
test "glyph_grid uses majority voting in a single cell" {
  // Three ink pixels and one paper pixel collapse to a single ink cell.
  let img = @moonocr.Image::new(2, 2, b"\x00\x00\x00\xff")
  let cs = @moonocr.connected_components(img)
  let g = @moonocr.glyph_grid(img, cs[0], 1)
  assert_eq(g.length(), 1)
  assert_eq(g[0], 255)
}

///|
test "glyph_grid respects the component offset" {
  // A 2x2 ink block at the bottom-right of a 3x3 page.
  let img = @moonocr.Image::new(3, 3, b"\xff\xff\xff\xff\x00\x00\xff\x00\x00")
  let cs = @moonocr.connected_components(img)
  assert_eq(cs[0].x, 1)
  assert_eq(cs[0].y, 1)
  let g = @moonocr.glyph_grid(img, cs[0], 2)
  assert_eq(g[0], 255)
  assert_eq(g[1], 255)
  assert_eq(g[2], 255)
  assert_eq(g[3], 255)
}
