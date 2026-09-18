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
