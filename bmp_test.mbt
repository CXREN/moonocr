///|
/// Blackbox tests for the BMP loader.
fn put_u16(buf : Array[Byte], off : Int, v : Int) -> Unit {
  buf[off] = (v & 0xff).to_byte()
  buf[off + 1] = ((v >> 8) & 0xff).to_byte()
}

///|
fn put_u32(buf : Array[Byte], off : Int, v : Int) -> Unit {
  buf[off] = (v & 0xff).to_byte()
  buf[off + 1] = ((v >> 8) & 0xff).to_byte()
  buf[off + 2] = ((v >> 16) & 0xff).to_byte()
  buf[off + 3] = ((v >> 24) & 0xff).to_byte()
}

///| Build an uncompressed 24-bit bottom-up BMP. `pixel` maps `(x, y)` in

///|
/// top-down coordinates to an `(r, g, b)` triple.
fn build_bmp24(
  width : Int,
  height : Int,
  pixel : (Int, Int) -> (Int, Int, Int),
) -> Bytes {
  let row_size = (width * 24 + 31) / 32 * 4
  let pixel_offset = 54
  let total = pixel_offset + row_size * height
  let buf = Array::make(total, b'\x00')
  buf[0] = b'B'
  buf[1] = b'M'
  put_u32(buf, 2, total)
  put_u32(buf, 10, pixel_offset)
  put_u32(buf, 14, 40)
  put_u32(buf, 18, width)
  put_u32(buf, 22, height)
  put_u16(buf, 26, 1)
  put_u16(buf, 28, 24)
  for y = 0; y < height; y = y + 1 {
    let src_y = height - 1 - y
    let row = pixel_offset + y * row_size
    for x = 0; x < width; x = x + 1 {
      let (r, g, b) = pixel(x, src_y)
      let o = row + x * 3
      buf[o] = b.to_byte()
      buf[o + 1] = g.to_byte()
      buf[o + 2] = r.to_byte()
    }
  }
  Bytes::from_array(buf)
}

///|
test "parse_bmp decodes a 1x1 red 24-bit bitmap" {
  let bmp = build_bmp24(1, 1, fn(_x, _y) { (255, 0, 0) })
  let img = try! @moonocr.parse_bmp(bmp)
  assert_eq(img.width, 1)
  assert_eq(img.height, 1)
  assert_eq(img.at(0, 0), 76)
}

///|
test "parse_bmp flips bottom-up rows into top-down order" {
  // 1x2 image: top pixel white, bottom pixel black.
  let bmp = build_bmp24(1, 2, fn(_x, y) {
    if y == 0 {
      (255, 255, 255)
    } else {
      (0, 0, 0)
    }
  })
  let img = try! @moonocr.parse_bmp(bmp)
  assert_eq(img.at(0, 0), 255)
  assert_eq(img.at(0, 1), 0)
}

///|
test "parse_bmp decodes a 2x2 bitmap with distinct primaries" {
  let colors = [(255, 0, 0), (0, 255, 0), (0, 0, 255), (255, 255, 255)]
  let bmp = build_bmp24(2, 2, fn(x, y) { colors[y * 2 + x] })
  let img = try! @moonocr.parse_bmp(bmp)
  assert_eq(img.at(0, 0), 76)
  assert_eq(img.at(1, 0), 149)
  assert_eq(img.at(0, 1), 29)
  assert_eq(img.at(1, 1), 255)
}

///|
test "parse_bmp rejects non-BMP input" {
  @test.assert_raise(() => @moonocr.parse_bmp(b"this is not a bitmap"))
}
