///| End-to-end recognition: the top-level OCR pipeline that turns a page of

///| digits and letters into a string.

///| Components smaller than this many pixels are treated as noise and dropped

///| before classification. Every supported glyph has at least ~20 ink pixels,

///| so this never removes a real character while catching salt-and-pepper

///|
/// specks introduced by a scanner or a noisy photograph.
fn min_glyph_area() -> Int {
  8
}

///| Recognize the components of one line, left to right, against the digit

///|

///|
/// and letter templates. `line` is sorted by horizontal position in place.
fn recognize_line(
  bin : Image,
  line : Array[Component],
  refs : Array[Reference],
) -> String {
  line.sort_by(fn(a, b) { a.x - b.x })
  let mut out = ""
  for i = 0; i < line.length(); i = i + 1 {
    let g = glyph_grid(bin, line[i], 8)
    match classify(g, refs) {
      None => ()
      Some(m) => out = out + m.label
    }
  }
  out
}

///| Recognize a single line of digits and letters, reading left to

///|

///| right. The image is binarized with Otsu's method, segmented into connected

///|

///| components, sorted by horizontal position, and each glyph is classified

///| against the built-in templates. Specks of noise are dropped and glyphs

///|
/// that match nothing are skipped.
pub fn recognize_digits(img : Image) -> String {
  let bin = binarize_otsu(img)
  let cs = filter_small(
    merge_parts(connected_components(bin)),
    min_glyph_area(),
  )
  recognize_line(bin, cs, alphanumeric_references())
}

///| Recognize multiple lines of digits and letters. Lines are

///|

///| separated by vertical gaps, detected via `group_lines`, read top to bottom,

///|
/// and joined with newlines.
pub fn recognize_text(img : Image) -> String {
  let bin = binarize_otsu(img)
  let lines = group_lines(connected_components(bin))
  let refs = alphanumeric_references()
  let mut out = ""
  for li = 0; li < lines.length(); li = li + 1 {
    if li > 0 {
      out = out + "\n"
    }
    let kept = filter_small(merge_parts(lines[li]), min_glyph_area())
    out = out + recognize_line(bin, kept, refs)
  }
  out
}
