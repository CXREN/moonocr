/// Skew correction for slightly rotated text. Scanned documents often have
/// lines tilted by a few degrees; straightening them first makes the
/// downstream segmentation and classification far more reliable.

///|
/// The number of ink pixels (value `< 128`) in each row. A horizontal line of
/// text concentrates ink into a small band of rows, so this profile is the
/// basis of skew detection.
pub fn projection_profile(img : Image) -> Array[Int] {
  let counts = Array::make(img.height, 0)
  for y = 0; y < img.height; y = y + 1 {
    let mut c = 0
    for x = 0; x < img.width; x = x + 1 {
      if img.at(x, y) < 128 {
        c = c + 1
      }
    }
    counts[y] = c
  }
  counts
}

///|
/// Rotate an image by `angle` degrees (positive counter-clockwise) about its
/// centre, using nearest-neighbour sampling. Source pixels that fall outside
/// the image are replaced by `fill` (use `255` for paper), so the result keeps
/// the original dimensions.
pub fn rotate(img : Image, angle : Double, fill : Int) -> Image {
  let w = img.width
  let h = img.height
  let rad = angle * @math.PI / 180.0
  let cos_a = @math.cos(rad)
  let sin_a = @math.sin(rad)
  let cx = (w - 1).to_double() / 2.0
  let cy = (h - 1).to_double() / 2.0
  let fill_byte = fill.to_byte()
  let pixels = Bytes::makei(w * h, fn(i) {
    let ox = i % w
    let oy = i / w
    // Inverse rotation maps each output pixel back to its source position.
    let dx = ox.to_double() - cx
    let dy = oy.to_double() - cy
    let sx = cx + dx * cos_a + dy * sin_a
    let sy = cy - dx * sin_a + dy * cos_a
    let sx_i = @math.round(sx).to_int()
    let sy_i = @math.round(sy).to_int()
    if sx_i < 0 || sx_i >= w || sy_i < 0 || sy_i >= h {
      fill_byte
    } else {
      img.pixels.at(sy_i * w + sx_i)
    }
  })
  Image::new(w, h, pixels)
}

///|
/// Variance of a projection profile. When the text lines are horizontal the
/// ink is packed into a few rows, making the profile spiky and its variance
/// large; the more the text is tilted, the more ink smears across rows and the
/// smaller the variance.
fn profile_variance(profile : Array[Int]) -> Double {
  let n = profile.length()
  if n == 0 {
    return 0.0
  }
  let mut sum = 0
  for i = 0; i < n; i = i + 1 {
    sum = sum + profile[i]
  }
  let mean = sum.to_double() / n.to_double()
  let mut sq = 0.0
  for i = 0; i < n; i = i + 1 {
    let d = profile[i].to_double() - mean
    sq = sq + d * d
  }
  sq / n.to_double()
}

///|
/// Estimate the corrective rotation for slightly tilted text. It tries angles
/// from `-max_angle` to `max_angle` in steps of `step` degrees and returns the
/// one that makes the horizontal projection profile sharpest. Rotating the
/// input by the returned angle straightens its lines. A blank or uniformly
/// inked image has no preferred angle, so `0.0` is returned.
pub fn detect_skew(img : Image, max_angle : Double, step : Double) -> Double {
  let mut best = 0.0
  let mut best_var = -1.0
  let n = (max_angle * 2.0 / step).to_int()
  for i = 0; i <= n; i = i + 1 {
    let a = -max_angle + i.to_double() * step
    let v = profile_variance(projection_profile(rotate(img, a, 255)))
    // Prefer the angle closest to 0 when several are equally sharp; small
    // rotations can leave a one-pixel line in the same row and thus tie.
    if v > best_var || (v == best_var && a.abs() < best.abs()) {
      best_var = v
      best = a
    }
  }
  if best_var <= 0.0 {
    0.0
  } else {
    best
  }
}

///|
/// Deskew an image in one step: detect the corrective rotation and apply it,
/// returning a copy whose text lines are as horizontal as possible.
pub fn deskew(img : Image, max_angle : Double, step : Double) -> Image {
  let angle = detect_skew(img, max_angle, step)
  rotate(img, angle, 255)
}
