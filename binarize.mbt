///| Binarization: the first processing stage of the OCR pipeline. It turns a

///|

///| grayscale `Image` into a two-level image so that segmentation and feature

///| extraction operate on clean ink/paper decisions instead of 256 gray levels.

///|

///| Convention used throughout: `0` is ink (foreground, dark) and `255` is

///| paper (background, light). The algorithms assume dark text on a light

///| background.

///|
/// Count how many pixels hold each of the 256 gray levels.
pub fn histogram(img : Image) -> Array[Int] {
  let counts = Array::make(256, 0)
  let n = img.pixel_count()
  for i = 0; i < n; i = i + 1 {
    let v = img.pixels.at(i).to_int()
    counts[v] = counts[v] + 1
  }
  counts
}

///| Apply a fixed global threshold: pixels at or below `threshold` become ink
///

///|
/// (`0`), the rest become paper (`255`).
pub fn binarize_fixed(img : Image, threshold : Int) -> Image {
  let n = img.pixel_count()
  let pixels = Bytes::makei(n, fn(i) {
    if img.pixels.at(i).to_int() <= threshold {
      b'\x00'
    } else {
      b'\xff'
    }
  })
  Image::new(img.width, img.height, pixels)
}

///| Compute Otsu's threshold, the value that best separates the dark and light
///

///| pixels by maximizing the between-class variance of the two resulting

///|
/// groups. Pixels at or below the returned threshold are the ink.
pub fn otsu_threshold(img : Image) -> Int {
  let counts = histogram(img)
  let total = img.pixel_count()
  let mut sum = 0
  for i = 0; i < 256; i = i + 1 {
    sum = sum + i * counts[i]
  }
  let sum_d = sum.to_double()
  let mut w_ink = 0
  let mut sum_ink = 0
  let mut best_var = -1.0
  let mut threshold = 0
  // `t` is the largest gray level assigned to the ink class, so it stops one
  // short of 255 to keep the paper class non-empty.
  for t = 0; t < 255; t = t + 1 {
    w_ink = w_ink + counts[t]
    sum_ink = sum_ink + t * counts[t]
    let w_paper = total - w_ink
    if w_ink > 0 && w_paper > 0 {
      let mean_ink = sum_ink.to_double() / w_ink.to_double()
      let mean_paper = (sum_d - sum_ink.to_double()) / w_paper.to_double()
      let diff = mean_ink - mean_paper
      let var_between = w_ink.to_double() * w_paper.to_double() * diff * diff
      if var_between > best_var {
        best_var = var_between
        threshold = t
      }
    }
  }
  threshold
}

///|
/// Binarize with the globally optimal Otsu threshold.
pub fn binarize_otsu(img : Image) -> Image {
  let t = otsu_threshold(img)
  binarize_fixed(img, t)
}

///| Build a summed-area table (integral image) with `Int64` cells, which can
///

///| hold the sums of even large images without overflowing. The table has

///| `(width + 1) * (height + 1)` cells; `table[(y + 1) * stride + (x + 1)]` is

///|
/// the sum of all pixels strictly above row `y` and left of column `x`.
fn integral_image(img : Image) -> Array[Int64] {
  let w = img.width
  let h = img.height
  let stride = w + 1
  let table = Array::make((w + 1) * (h + 1), 0L)
  for y = 0; y < h; y = y + 1 {
    let mut row_sum = 0L
    for x = 0; x < w; x = x + 1 {
      row_sum = row_sum + img.pixels.at(y * w + x).to_int().to_int64()
      table[(y + 1) * stride + (x + 1)] = table[y * stride + (x + 1)] + row_sum
    }
  }
  table
}

///|
/// Sum of the pixels in the half-open rectangle `[x0, x1) x [y0, y1)`.
fn window_sum(
  table : Array[Int64],
  stride : Int,
  x0 : Int,
  y0 : Int,
  x1 : Int,
  y1 : Int,
) -> Int64 {
  table[y1 * stride + x1] -
  table[y0 * stride + x1] -
  table[y1 * stride + x0] +
  table[y0 * stride + x0]
}

///| Adaptive mean thresholding. Each pixel is compared against the mean of the
///

///| `window`-sized neighbourhood around it, offset by `c`; pixels darker than

///| that local threshold become ink. This handles uneven illumination where a

///|
/// single global threshold would fail.
pub fn binarize_adaptive(img : Image, window : Int, c : Int) -> Image {
  let table = integral_image(img)
  let stride = img.width + 1
  let half = window / 2
  let c64 = c.to_int64()
  let pixels = Bytes::makei(img.pixel_count(), fn(i) {
    let x = i % img.width
    let y = i / img.width
    let x0 = if x - half < 0 { 0 } else { x - half }
    let y0 = if y - half < 0 { 0 } else { y - half }
    let x1 = if x + half + 1 > img.width { img.width } else { x + half + 1 }
    let y1 = if y + half + 1 > img.height { img.height } else { y + half + 1 }
    let area = (x1 - x0) * (y1 - y0)
    let mean = window_sum(table, stride, x0, y0, x1, y1) / area.to_int64()
    let v = img.pixels.at(i).to_int().to_int64()
    if v + c64 < mean {
      b'\x00'
    } else {
      b'\xff'
    }
  })
  Image::new(img.width, img.height, pixels)
}

///|
/// Summed-area table of squared pixel values, mirroring `integral_image`. It
/// lets the local variance (and thus the standard deviation) be computed in
/// constant time per pixel, which Sauvola thresholding needs.
fn integral_image_sq(img : Image) -> Array[Int64] {
  let w = img.width
  let h = img.height
  let stride = w + 1
  let table = Array::make((w + 1) * (h + 1), 0L)
  for y = 0; y < h; y = y + 1 {
    let mut row_sum = 0L
    for x = 0; x < w; x = x + 1 {
      let v = img.pixels.at(y * w + x).to_int().to_int64()
      row_sum = row_sum + v * v
      table[(y + 1) * stride + (x + 1)] = table[y * stride + (x + 1)] + row_sum
    }
  }
  table
}

///|
/// Sauvola local binarization. Each pixel's threshold adapts to both the local
/// mean `m` and local standard deviation `s` of its `window`-sized
/// neighbourhood:
///
///   T = m * (1 + k * (s / r - 1))
///
/// `r` is the dynamic range of `s` (usually `128` for 8-bit gray) and `k`
/// controls sensitivity (typically `0.2`-`0.5`). Pixels darker than `T` become
/// ink. Unlike the fixed-offset mean threshold, Sauvola suppresses noise in
/// flat regions while keeping text in high-contrast regions.
pub fn binarize_sauvola(
  img : Image,
  window : Int,
  k : Double,
  r : Double,
) -> Image {
  let table = integral_image(img)
  let table_sq = integral_image_sq(img)
  let stride = img.width + 1
  let half = window / 2
  let pixels = Bytes::makei(img.pixel_count(), fn(i) {
    let x = i % img.width
    let y = i / img.width
    let x0 = if x - half < 0 { 0 } else { x - half }
    let y0 = if y - half < 0 { 0 } else { y - half }
    let x1 = if x + half + 1 > img.width { img.width } else { x + half + 1 }
    let y1 = if y + half + 1 > img.height { img.height } else { y + half + 1 }
    let area = (x1 - x0) * (y1 - y0)
    let area_d = area.to_double()
    let mean = window_sum(table, stride, x0, y0, x1, y1).to_double() / area_d
    let mean_sq = window_sum(table_sq, stride, x0, y0, x1, y1).to_double() /
      area_d
    let variance = mean_sq - mean * mean
    let std = if variance > 0.0 { variance.sqrt() } else { 0.0 }
    let threshold = mean * (1.0 + k * (std / r - 1.0))
    let v = img.pixels.at(i).to_int().to_double()
    if v < threshold {
      b'\x00'
    } else {
      b'\xff'
    }
  })
  Image::new(img.width, img.height, pixels)
}

///|
/// Niblack local binarization. Each pixel's threshold is the local mean plus a
/// multiple of the local standard deviation:
///
///   T = m + k * s
///
/// `k` is usually negative (around `-0.2`), placing the threshold below the
/// mean so that only pixels clearly darker than their neighbourhood become
/// ink. Niblack recovers text under uneven illumination but, unlike Sauvola,
/// can raise noise in low-variance regions.
pub fn binarize_niblack(img : Image, window : Int, k : Double) -> Image {
  let table = integral_image(img)
  let table_sq = integral_image_sq(img)
  let stride = img.width + 1
  let half = window / 2
  let pixels = Bytes::makei(img.pixel_count(), fn(i) {
    let x = i % img.width
    let y = i / img.width
    let x0 = if x - half < 0 { 0 } else { x - half }
    let y0 = if y - half < 0 { 0 } else { y - half }
    let x1 = if x + half + 1 > img.width { img.width } else { x + half + 1 }
    let y1 = if y + half + 1 > img.height { img.height } else { y + half + 1 }
    let area = (x1 - x0) * (y1 - y0)
    let area_d = area.to_double()
    let mean = window_sum(table, stride, x0, y0, x1, y1).to_double() / area_d
    let mean_sq = window_sum(table_sq, stride, x0, y0, x1, y1).to_double() /
      area_d
    let variance = mean_sq - mean * mean
    let std = if variance > 0.0 { variance.sqrt() } else { 0.0 }
    let threshold = mean + k * std
    let v = img.pixels.at(i).to_int().to_double()
    if v < threshold {
      b'\x00'
    } else {
      b'\xff'
    }
  })
  Image::new(img.width, img.height, pixels)
}
