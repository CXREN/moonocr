///|
/// Benchmarks for the OCR pipeline. Run with `moon bench`.
/// Each stage is timed on a rendered input so the cost of a single pass can be
/// compared across stages and watched for regressions.

///|
test "bench connected_components" (it : @bench.T) {
  let img = @moonocr.render_text("314159265358", 4, 8)
  it.bench(name="connected_components", fn() {
    it.keep(@moonocr.connected_components(img))
  })
}

///|
test "bench binarize_otsu" (it : @bench.T) {
  let img = @moonocr.render_text_block(["Hello", "World", "42"], 4, 8, 16)
  it.bench(name="binarize_otsu", fn() { it.keep(@moonocr.binarize_otsu(img)) })
}

///|
test "bench binarize_adaptive" (it : @bench.T) {
  let img = @moonocr.render_text_block(["Hello", "World", "42"], 4, 8, 16)
  it.bench(name="binarize_adaptive", fn() {
    it.keep(@moonocr.binarize_adaptive(img, 15, 20))
  })
}

///|
test "bench binarize_sauvola" (it : @bench.T) {
  let img = @moonocr.render_text_block(["Hello", "World", "42"], 4, 8, 16)
  it.bench(name="binarize_sauvola", fn() {
    it.keep(@moonocr.binarize_sauvola(img, 15, 0.3, 128.0))
  })
}

///|
test "bench binarize_niblack" (it : @bench.T) {
  let img = @moonocr.render_text_block(["Hello", "World", "42"], 4, 8, 16)
  it.bench(name="binarize_niblack", fn() {
    it.keep(@moonocr.binarize_niblack(img, 15, -0.2))
  })
}

///|
test "bench classify a glyph" (it : @bench.T) {
  let refs = @moonocr.alphanumeric_references()
  let img = @moonocr.render_rows(@moonocr.font_rows(5), 4)
  let cs = @moonocr.connected_components(img)
  let g = @moonocr.glyph_grid(img, cs[0], 8)
  it.bench(name="classify", fn() { it.keep(@moonocr.classify(g, refs)) })
}

///|
test "bench recognize a 12-digit line" (it : @bench.T) {
  let img = @moonocr.render_text("314159265358", 4, 8)
  it.bench(name="recognize_digits", fn() {
    it.keep(@moonocr.recognize_digits(img))
  })
}

///|
test "bench recognize a multi-line block" (it : @bench.T) {
  let img = @moonocr.render_text_block(["Hello", "World", "42"], 4, 8, 16)
  it.bench(name="recognize_text", fn() { it.keep(@moonocr.recognize_text(img)) })
}
