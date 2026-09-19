///|
/// Blackbox tests for classification.

///|
test "cell_distance counts differing cells" {
  let a = [255, 0, 255, 0]
  let b = [255, 255, 0, 0]
  assert_eq(@moonocr.cell_distance(a, b), 2)
}

///|
test "classify returns the nearest label" {
  let refs = [
    @moonocr.Reference::new("a", [255, 255, 0, 0]),
    @moonocr.Reference::new("b", [0, 0, 255, 255]),
  ]
  let m = @moonocr.classify([255, 255, 0, 0], refs).unwrap()
  assert_eq(m.label, "a")
  assert_eq(m.distance, 0)
}

///|
test "classify returns None when there are no references" {
  let refs : Array[@moonocr.Reference] = Array(capacity=0)
  assert_true(@moonocr.classify([0, 0], refs) is None)
}

///|
test "recognizes a rendered digit end to end" {
  let img = @moonocr.render_rows(@moonocr.font_rows(5), 4)
  let cs = @moonocr.connected_components(img)
  assert_eq(cs.length(), 1)
  let g = @moonocr.glyph_grid(img, cs[0], 8)
  let m = @moonocr.classify(g, @moonocr.digit_references()).unwrap()
  assert_eq(m.label, "5")
  assert_eq(m.distance, 0)
}

///|
test "recognizes every digit from its rendered bitmap" {
  let refs = @moonocr.digit_references()
  for d = 0; d < 10; d = d + 1 {
    let img = @moonocr.render_rows(@moonocr.font_rows(d), 4)
    let cs = @moonocr.connected_components(img)
    let g = @moonocr.glyph_grid(img, cs[0], 8)
    let m = @moonocr.classify(g, refs).unwrap()
    assert_eq(m.label, d.to_string())
  }
}

///|
test "weighted_distance counts disagreements by their weight" {
  let a = [255, 0, 255, 0]
  let b = [0, 0, 0, 0]
  let weights = [3, 1, 1, 1]
  // Differ at index 0 (weight 3) and index 2 (weight 1).
  assert_eq(@moonocr.weighted_distance(a, b, weights), 4)
}

///|
test "center_weights emphasises the interior" {
  let w = @moonocr.center_weights()
  assert_eq(w.length(), 64)
  assert_eq(w[0], 1) // top-left corner is the border
  assert_eq(w[8 * 3 + 3], 2) // (3,3) is interior
}

///|
test "classify_weighted returns the nearest label under weights" {
  let refs = [
    @moonocr.Reference::new("a", [255, 255, 0, 0]),
    @moonocr.Reference::new("b", [0, 0, 255, 255]),
  ]
  let m = @moonocr.classify_weighted([255, 255, 0, 0], refs, [1, 1, 1, 1]).unwrap()
  assert_eq(m.label, "a")
  assert_eq(m.distance, 0)
}

///|
test "shift_variants returns the original plus four shifts" {
  let grid = [255, 0, 0, 0] // 2x2 with ink at (0,0)
  let vs = @moonocr.shift_variants(grid, 2)
  assert_eq(vs.length(), 5)
  assert_eq(vs[0][0], 255) // original keeps ink at (0,0)
  assert_eq(vs[2][1], 255) // right shift moves ink to (1,0)
  assert_eq(vs[4][2], 255) // down shift moves ink to (0,1)
  assert_eq(vs[1][0], 0) // left shift drops ink off the edge
}

///|
test "classify_shifted recognizes an off-centre glyph" {
  let refs = @moonocr.digit_references()
  let img = @moonocr.render_rows(@moonocr.font_rows(5), 4)
  let cs = @moonocr.connected_components(img)
  let g = @moonocr.glyph_grid(img, cs[0], 8)
  // Shift the glyph right by one cell, as a slightly misaligned segment.
  let shifted = @moonocr.shift_variants(g, 8)[2]
  let m = @moonocr.classify_shifted(shifted, refs, 8).unwrap()
  assert_eq(m.label, "5")
  assert_eq(m.distance, 0)
}
