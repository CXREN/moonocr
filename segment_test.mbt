///|
/// Blackbox tests for connected-component segmentation.

///|
test "connected_components finds separate ink pixels" {
  // Three isolated ink pixels separated by paper.
  let img = @moonocr.Image::new(5, 1, b"\x00\xff\x00\xff\x00")
  let cs = @moonocr.connected_components(img)
  assert_eq(cs.length(), 3)
  assert_eq(cs[0].x, 0)
  assert_eq(cs[0].w, 1)
  assert_eq(cs[1].x, 2)
  assert_eq(cs[2].x, 4)
}

///|
test "connected_components merges a solid block into one region" {
  let img = @moonocr.Image::new(2, 2, b"\x00\x00\x00\x00")
  let cs = @moonocr.connected_components(img)
  assert_eq(cs.length(), 1)
  assert_eq(cs[0].x, 0)
  assert_eq(cs[0].y, 0)
  assert_eq(cs[0].w, 2)
  assert_eq(cs[0].h, 2)
  assert_eq(cs[0].area, 4)
}

///|
test "connected_components uses 8-connectivity for diagonals" {
  // Two ink pixels touching only at a corner belong to one region.
  let img = @moonocr.Image::new(2, 2, b"\x00\xff\xff\x00")
  let cs = @moonocr.connected_components(img)
  assert_eq(cs.length(), 1)
  assert_eq(cs[0].w, 2)
  assert_eq(cs[0].h, 2)
  assert_eq(cs[0].area, 2)
}

///|
test "connected_components keeps separated blobs apart" {
  // Two 1-pixel dots with a paper gap between them.
  let img = @moonocr.Image::new(3, 1, b"\x00\xff\x00")
  let cs = @moonocr.connected_components(img)
  assert_eq(cs.length(), 2)
}

///|
test "connected_components returns nothing for an empty page" {
  let img = @moonocr.Image::new(2, 2, b"\xff\xff\xff\xff")
  let cs = @moonocr.connected_components(img)
  assert_eq(cs.length(), 0)
}

///|
test "filter_small removes specks but keeps real glyphs" {
  // A 2-pixel horizontal bar at the top-left, and a 1-pixel speck far away.
  let img = @moonocr.Image::new(3, 3, b"\x00\x00\xff\xff\xff\xff\xff\xff\x00")
  let cs = @moonocr.connected_components(img)
  assert_eq(cs.length(), 2)
  let kept = @moonocr.filter_small(cs, 2)
  assert_eq(kept.length(), 1)
  assert_eq(kept[0].area, 2)
}

///|
test "group_lines splits rendered rows on a vertical gap" {
  // Two rendered lines "314" and "159" separated by a 16-pixel gap. Each glyph
  // is one component, so group_lines should yield two rows of three.
  let img = @moonocr.render_text_block(["314", "159"], 4, 8, 16)
  let cs = @moonocr.connected_components(img)
  let lines = @moonocr.group_lines(cs)
  assert_eq(lines.length(), 2)
  assert_eq(lines[0].length(), 3)
  assert_eq(lines[1].length(), 3)
}

///|
test "merge_parts joins the separate dot and stem of a lowercase i" {
  // The built-in `i` renders as two components: a dot on the top row and a
  // stem below it. merge_parts should reunite them into one glyph.
  let img = @moonocr.render_rows(@moonocr.font_rows_lower('i'), 4)
  let cs = @moonocr.connected_components(img)
  assert_eq(cs.length(), 2)
  let merged = @moonocr.merge_parts(cs)
  assert_eq(merged.length(), 1)
}

///|
test "merge_parts leaves a single solid glyph alone" {
  let img = @moonocr.render_rows(@moonocr.font_rows(0), 4)
  let cs = @moonocr.connected_components(img)
  assert_eq(cs.length(), 1)
  assert_eq(@moonocr.merge_parts(cs).length(), 1)
}
