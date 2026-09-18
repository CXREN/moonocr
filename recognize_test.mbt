///|
/// Blackbox tests for the end-to-end recognition pipeline.

///| Re-render a clean image as a "scan": ink becomes dark gray, paper becomes

///| light gray, and the flat pixel indices in `noise` are turned to solid black

///|
/// to simulate scanner specks.
fn scanify(img : @moonocr.Image, noise : Array[Int]) -> @moonocr.Image {
  let n = img.pixel_count()
  let pixels = Array::make(n, b'\x00')
  for i = 0; i < n; i = i + 1 {
    pixels[i] = if img.pixels.at(i).to_int() < 128 { b'\x1e' } else { b'\xf0' }
  }
  for j = 0; j < noise.length(); j = j + 1 {
    pixels[noise[j]] = b'\x00'
  }
  @moonocr.Image::new(img.width, img.height, Bytes::from_array(pixels))
}

///|
test "recognizes a single rendered digit" {
  let img = @moonocr.render_rows(@moonocr.font_rows(7), 4)
  assert_eq(@moonocr.recognize_digits(img), "7")
}

///|
test "recognizes a rendered multi-digit string left to right" {
  let img = @moonocr.render_text("314159", 4, 8)
  assert_eq(@moonocr.recognize_digits(img), "314159")
}

///|
test "recognizes digits with a larger gap between them" {
  let img = @moonocr.render_text("42", 5, 20)
  assert_eq(@moonocr.recognize_digits(img), "42")
}

///|
test "recognizes multiple rendered lines top to bottom" {
  let img = @moonocr.render_text_block(["314", "159"], 4, 8, 16)
  assert_eq(@moonocr.recognize_text(img), "314\n159")
}

///|
test "recognizes ragged lines left-aligned" {
  let img = @moonocr.render_text_block(["7", "42", "999"], 4, 8, 16)
  assert_eq(@moonocr.recognize_text(img), "7\n42\n999")
}

///|
test "recognizes every uppercase letter" {
  let img = @moonocr.render_text("ABCDEFGHIJKLMNOPQRSTUVWXYZ", 4, 8)
  assert_eq(@moonocr.recognize_digits(img), "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
}

///|
test "recognizes mixed digits and letters" {
  let img = @moonocr.render_text("A1B2C3", 4, 8)
  assert_eq(@moonocr.recognize_digits(img), "A1B2C3")
}

///|
test "recognizes letters across multiple lines" {
  let img = @moonocr.render_text_block(["HELLO", "WORLD"], 4, 8, 16)
  assert_eq(@moonocr.recognize_text(img), "HELLO\nWORLD")
}

///|
test "recognizes digits at every scale from 2 to 8" {
  for scale = 2; scale <= 8; scale = scale + 1 {
    let img = @moonocr.render_text("0123456789", scale, 8)
    assert_eq(@moonocr.recognize_digits(img), "0123456789")
  }
}

///|
test "recognizes mixed text at a non-default scale" {
  let img = @moonocr.render_text("ABC123", 6, 12)
  assert_eq(@moonocr.recognize_digits(img), "ABC123")
}

///|
test "recognizes text from a noisy grayscale scan" {
  // "314" at scale 4 is 112 wide and 32 tall; the inter-glyph gutters are the
  // paper columns x in [32,40) and [72,80). Drop dark specks in those gutters.
  let clean = @moonocr.render_text("314", 4, 8)
  let noise = [5 * 112 + 35, 5 * 112 + 75, 25 * 112 + 35]
  let scan = scanify(clean, noise)
  assert_eq(@moonocr.recognize_digits(scan), "314")
}

///|
test "recognizes every lowercase letter" {
  let img = @moonocr.render_text("abcdefghijklmnopqrstuvwxyz", 4, 8)
  assert_eq(@moonocr.recognize_digits(img), "abcdefghijklmnopqrstuvwxyz")
}

///|
test "recognizes i and j whose dots are separate components" {
  let img = @moonocr.render_text("ij", 4, 8)
  assert_eq(@moonocr.recognize_digits(img), "ij")
}

///|
test "recognizes mixed-case alphanumeric text" {
  let img = @moonocr.render_text("Hello42World", 4, 8)
  assert_eq(@moonocr.recognize_digits(img), "Hello42World")
}
