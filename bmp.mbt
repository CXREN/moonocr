///| A minimal, dependency-free BMP loader. It decodes uncompressed (BI_RGB)

///| 8-bit palette, 24-bit and 32-bit bitmaps into a grayscale `Image`.

///|

///| BMP stores rows bottom-up by default and pads each row to a 4-byte

///| boundary; both behaviours are handled here.

///|
/// Read a little-endian unsigned 16-bit value at `off`.
fn read_u16(data : Bytes, off : Int) -> Int {
  data.at(off).to_int() | (data.at(off + 1).to_int() << 8)
}

///| Read a little-endian 32-bit value at `off`.
///

///| `Int` is 32-bit two's complement, so assembling the four bytes yields the

///| correct value whether the field is meant as `u32` (small magnitudes) or

///|
/// `i32` (e.g. a negative BMP height for top-down rows).
fn read_u32(data : Bytes, off : Int) -> Int {
  data.at(off).to_int() |
  (data.at(off + 1).to_int() << 8) |
  (data.at(off + 2).to_int() << 16) |
  (data.at(off + 3).to_int() << 24)
}

///| Compute the grayscale value of one pixel in a BMP row.
///

///| `row_off` points at the first byte of the (already flipped) source row and

///| `palette_offset` at the start of the 4-byte-per-entry BGR0 palette, which

///|
/// is only consulted for 8-bit images.
fn bmp_pixel_gray(
  data : Bytes,
  bpp : Int,
  palette_offset : Int,
  row_off : Int,
  x : Int,
) -> Int {
  if bpp == 8 {
    let idx = data.at(row_off + x).to_int()
    let po = palette_offset + idx * 4
    rgb_to_gray(
      data.at(po + 2).to_int(),
      data.at(po + 1).to_int(),
      data.at(po).to_int(),
    )
  } else if bpp == 24 {
    let po = row_off + x * 3
    rgb_to_gray(
      data.at(po + 2).to_int(),
      data.at(po + 1).to_int(),
      data.at(po).to_int(),
    )
  } else {
    // 32-bit BGRA; the alpha byte is ignored.
    let po = row_off + x * 4
    rgb_to_gray(
      data.at(po + 2).to_int(),
      data.at(po + 1).to_int(),
      data.at(po).to_int(),
    )
  }
}

///| Parse a BMP byte stream into a grayscale `Image`.
///

///|
/// Raises `DecodeError` when the input is not a supported uncompressed BMP.
pub fn parse_bmp(data : Bytes) -> Image raise DecodeError {
  if data.length() < 54 {
    raise DecodeError("BMP: buffer too short for a BITMAPINFOHEADER")
  }
  if data.at(0) != b'B' || data.at(1) != b'M' {
    raise DecodeError("BMP: missing BM magic")
  }
  let pixel_offset = read_u32(data, 10)
  let header_size = read_u32(data, 14)
  if header_size < 40 {
    raise DecodeError("BMP: unsupported DIB header size")
  }
  let width = read_u32(data, 18)
  let height = read_u32(data, 22)
  let bpp = read_u16(data, 28)
  let compression = read_u32(data, 30)
  if compression != 0 {
    raise DecodeError("BMP: only uncompressed (BI_RGB) images are supported")
  }
  if width <= 0 {
    raise DecodeError("BMP: invalid width")
  }
  if bpp != 8 && bpp != 24 && bpp != 32 {
    raise DecodeError("BMP: unsupported bit depth")
  }
  let flip = height > 0
  let rows = if flip { height } else { 0 - height }
  let row_size = (width * bpp + 31) / 32 * 4
  let palette_offset = 14 + header_size
  let pixels = Bytes::makei(width * rows, fn(i) {
    let x = i % width
    let y = i / width
    let src_y = if flip { rows - 1 - y } else { y }
    let row_off = pixel_offset + src_y * row_size
    bmp_pixel_gray(data, bpp, palette_offset, row_off, x).to_byte()
  })
  Image::new(width, rows, pixels)
}
