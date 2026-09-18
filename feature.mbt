///| Feature extraction: turning a segmented glyph into a fixed-size vector so

///| that different glyphs can be compared numerically. The scheme downsamples

///| the glyph's bounding box onto a square grid, where each cell records

///| whether ink covers at least half of it. The flattened grid is the feature

///| vector.

///|

///| The same convention as elsewhere holds: pixel values below `128` are ink.

///| Normalize the pixels of `c` onto a `size`-by-`size` grid, returning

///| `size * size` cells in row-major order. Each cell is `255` when at least

///| half of the source pixels it covers are ink, otherwise `0`.

///|

///| The glyph is scaled to fit the grid while preserving its aspect ratio and

///| centered with paper padding, so a thin glyph stays thin instead of being

///|
/// stretched out of shape.
pub fn glyph_grid(img : Image, c : Component, size : Int) -> Array[Int] {
  let grid = Array::make(size * size, 0)
  let stride = img.width
  let long_side = if c.w > c.h { c.w } else { c.h }
  let gw = if c.w * size / long_side < 1 { 1 } else { c.w * size / long_side }
  let gh = if c.h * size / long_side < 1 { 1 } else { c.h * size / long_side }
  let off_x = (size - gw) / 2
  let off_y = (size - gh) / 2
  for oy = 0; oy < size; oy = oy + 1 {
    let gy = oy - off_y
    if gy < 0 || gy >= gh {
      continue
    }
    let sy0 = c.y + gy * c.h / gh
    let sy1_floor = c.y + (gy + 1) * c.h / gh
    let sy1 = if sy1_floor > sy0 { sy1_floor } else { sy0 + 1 }
    for ox = 0; ox < size; ox = ox + 1 {
      let gx = ox - off_x
      if gx < 0 || gx >= gw {
        continue
      }
      let sx0 = c.x + gx * c.w / gw
      let sx1_floor = c.x + (gx + 1) * c.w / gw
      let sx1 = if sx1_floor > sx0 { sx1_floor } else { sx0 + 1 }
      let mut ink = 0
      let mut total = 0
      for sy = sy0; sy < sy1; sy = sy + 1 {
        for sx = sx0; sx < sx1; sx = sx + 1 {
          total = total + 1
          if img.pixels.at(sy * stride + sx).to_int() < 128 {
            ink = ink + 1
          }
        }
      }
      if ink * 2 >= total {
        grid[oy * size + ox] = 255
      }
    }
  }
  grid
}

///| The normalized feature grid of the built-in glyph for `c`, extracted by

///|

///| rendering it and running it through the same `glyph_grid` path used for

///| real input. Using this as a reference keeps templates in the exact feature

///| space the classifier sees, so a clean rendering matches itself at distance

///|
/// zero even when the raw font bitmap is not horizontally symmetric.
pub fn char_grid(c : Char) -> Array[Int] {
  let img = render_rows(char_rows(c), 4)
  let cs = merge_parts(connected_components(img))
  if cs.length() == 0 {
    Array::make(64, 0)
  } else {
    glyph_grid(img, cs[0], 8)
  }
}
