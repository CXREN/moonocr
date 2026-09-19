///|
/// Blackbox tests for skew correction.
test "projection_profile counts ink pixels per row" {
  // 2x3 image: row 0 has 1 ink pixel, row 1 has 2, row 2 has none.
  let img = @moonocr.Image::new(2, 3, b"\x00\xff\x00\x00\xff\xff")
  let p = @moonocr.projection_profile(img)
  assert_eq(p.length(), 3)
  assert_eq(p[0], 1)
  assert_eq(p[1], 2)
  assert_eq(p[2], 0)
}

///|
test "rotate by 0 degrees is the identity" {
  let img = @moonocr.Image::new(2, 2, b"\x00\xff\x80\x40")
  let out = @moonocr.rotate(img, 0.0, 255)
  assert_eq(out.at(0, 0), 0)
  assert_eq(out.at(1, 0), 255)
  assert_eq(out.at(0, 1), 128)
  assert_eq(out.at(1, 1), 64)
}

///|
test "rotate by 90 degrees moves ink counter-clockwise" {
  // Ink at top-left (0,0) moves to top-right (1,0) under a 90 degree CCW turn.
  let img = @moonocr.Image::new(2, 2, b"\x00\xff\xff\xff")
  let out = @moonocr.rotate(img, 90.0, 255)
  assert_eq(out.at(1, 0), 0)
  assert_eq(out.at(0, 0), 255)
  assert_eq(out.at(0, 1), 255)
  assert_eq(out.at(1, 1), 255)
}

///|
test "detect_skew finds no skew in a horizontal line" {
  // A single horizontal line of ink is already maximally sharp at 0 degrees.
  let img = @moonocr.Image::new(
    20,
    12,
    Bytes::makei(240, fn(i) { if i / 20 == 5 { b'\x00' } else { b'\xff' } }),
  )
  assert_eq(@moonocr.detect_skew(img, 10.0, 1.0), 0.0)
}

///|
test "deskew straightens a tilted line" {
  // Tilt the same horizontal line by 4 degrees; the corrective rotation is -4.
  let clean = @moonocr.Image::new(
    20,
    12,
    Bytes::makei(240, fn(i) { if i / 20 == 5 { b'\x00' } else { b'\xff' } }),
  )
  let tilted = @moonocr.rotate(clean, 4.0, 255)
  assert_eq(@moonocr.detect_skew(tilted, 10.0, 1.0), -4.0)
}

///|
test "detect_skew returns 0 for a blank image" {
  // No rows are inkier than others, so there is no preferred angle.
  let img = @moonocr.Image::new(2, 2, b"\xff\xff\xff\xff")
  assert_eq(@moonocr.detect_skew(img, 5.0, 1.0), 0.0)
}

///|
test "deskew re-concentrates ink into a single row" {
  // After deskewing a 4-degree tilt, most ink returns to the original row.
  let clean = @moonocr.Image::new(
    20,
    12,
    Bytes::makei(240, fn(i) { if i / 20 == 5 { b'\x00' } else { b'\xff' } }),
  )
  let tilted = @moonocr.rotate(clean, 4.0, 255)
  let out = @moonocr.deskew(tilted, 10.0, 1.0)
  let p = @moonocr.projection_profile(out)
  let mut max = 0
  for i = 0; i < p.length(); i = i + 1 {
    if p[i] > max {
      max = p[i]
    }
  }
  assert_true(max >= 15)
}
