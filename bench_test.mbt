///|
/// Benchmarks for the OCR pipeline. Run with `moon bench`.

///|
test "bench recognize a 12-digit line" (it : @bench.T) {
  let img = @moonocr.render_text("314159265358", 4, 8)
  it.bench(fn() { it.keep(@moonocr.recognize_digits(img)) })
}

///|
test "bench recognize a multi-line block" (it : @bench.T) {
  let img = @moonocr.render_text_block(["Hello", "World", "42"], 4, 8, 16)
  it.bench(fn() { it.keep(@moonocr.recognize_text(img)) })
}
