///| A dependency-free Netpbm loader supporting the three formats most useful

///| for tests and small tools: P2 (ASCII grayscale), P4 (bitmap) and

///| P5 (binary grayscale). All three decode into a grayscale `Image`.

///| Advance past whitespace and `#` comments, returning the first

///|
/// non-comment, non-whitespace offset at or after `pos`.
fn skip_ws_and_comments(data : Bytes, pos : Int) -> Int {
  let n = data.length()
  let mut p = pos
  while p < n {
    let c = data.at(p).to_int()
    if c == 0x20 || c == 0x09 || c == 0x0a || c == 0x0d {
      p = p + 1
    } else if c == 0x23 {
      while p < n && data.at(p).to_int() != 0x0a {
        p = p + 1
      }
    } else {
      break
    }
  }
  p
}

///| Read a decimal ASCII integer token starting at `pos`, returning the value

///|
/// and the offset just past the last digit.
fn read_token_int(data : Bytes, pos : Int) -> (Int, Int) {
  let n = data.length()
  let mut q = skip_ws_and_comments(data, pos)
  let mut v = 0
  while q < n {
    let c = data.at(q).to_int()
    if c >= 0x30 && c <= 0x39 {
      v = v * 10 + (c - 0x30)
      q = q + 1
    } else {
      break
    }
  }
  (v, q)
}

///|
/// Decode a P5 (binary grayscale) raster, rescaling `maxval` to 255.
fn decode_p5(
  data : Bytes,
  width : Int,
  height : Int,
  data_start : Int,
  maxval : Int,
) -> Image {
  let pixels = Bytes::makei(width * height, fn(i) {
    let v = data.at(data_start + i).to_int()
    (v * 255 / maxval).to_byte()
  })
  Image::new(width, height, pixels)
}

///| Decode a P2 (ASCII grayscale) raster, rescaling `maxval` to 255.
///

///| Unlike the binary formats, P2 pixel values are whitespace-separated ASCII

///|
/// numbers, so the token scanner must advance through the raster sequentially.
fn decode_p2(
  data : Bytes,
  width : Int,
  height : Int,
  data_start : Int,
  maxval : Int,
) -> Image {
  let pixels = Array::make(width * height, b'\x00')
  let mut p = data_start
  for i = 0; i < width * height; i = i + 1 {
    let (v, q) = read_token_int(data, p)
    pixels[i] = (v * 255 / maxval).to_byte()
    p = q
  }
  Image::new(width, height, Bytes::from_array(pixels))
}

///| Decode a P4 (packed bitmap) raster. A set bit is black (`0`) and a clear

///|
/// bit is white (`255`); bits are packed MSB-first, rows padded to bytes.
fn decode_p4(
  data : Bytes,
  width : Int,
  height : Int,
  data_start : Int,
) -> Image {
  let row_bytes = (width + 7) / 8
  let pixels = Bytes::makei(width * height, fn(i) {
    let x = i % width
    let y = i / width
    let byte = data.at(data_start + y * row_bytes + x / 8).to_int()
    let bit = (byte >> (7 - x % 8)) & 1
    if bit == 0 {
      b'\xff'
    } else {
      b'\x00'
    }
  })
  Image::new(width, height, pixels)
}

///| Parse a Netpbm image (`P2`, `P4` or `P5`) into a grayscale `Image`.
///

///| Raises `DecodeError` describing the problem when the input is malformed or

///|
/// uses a feature outside the supported subset.

///| Encode an image as a P5 (binary grayscale) PGM with `maxval` 255. The
///

///| header is ASCII and the raster follows byte for byte, so the result round-

///|
/// trips through `parse_pgm`.
pub fn write_pgm_p5(img : Image) -> Bytes {
  let header = "P5\n\{img.width} \{img.height}\n255\n"
  let hb = @utf8.encode(header)
  let n = img.pixel_count()
  let out = Array::make(hb.length() + n, b'\x00')
  for i = 0; i < hb.length(); i = i + 1 {
    out[i] = hb.at(i)
  }
  for i = 0; i < n; i = i + 1 {
    out[hb.length() + i] = img.pixels.at(i)
  }
  Bytes::from_array(out)
}

///|
/// Parse a Netpbm image (`P2`, `P4` or `P5`) into a grayscale `Image`.
///
pub fn parse_pgm(data : Bytes) -> Image raise DecodeError {
  if data.length() < 2 {
    raise DecodeError("PGM: buffer too short")
  }
  if data.at(0) != b'P' {
    raise DecodeError("PGM: not a Netpbm file")
  }
  let magic = data.at(1).to_int()
  let (width, pos1) = read_token_int(data, 2)
  let (height, pos2) = read_token_int(data, pos1)
  if width <= 0 || height <= 0 {
    raise DecodeError("PGM: invalid dimensions")
  }
  if magic == 0x35 {
    // P5: binary grayscale. A single whitespace byte follows `maxval`.
    let (maxval, pos3) = read_token_int(data, pos2)
    if maxval <= 0 || maxval > 255 {
      raise DecodeError("PGM: maxval outside 1..255 is not supported")
    }
    decode_p5(data, width, height, pos3 + 1, maxval)
  } else if magic == 0x32 {
    // P2: ASCII grayscale.
    let (maxval, pos3) = read_token_int(data, pos2)
    if maxval <= 0 || maxval > 255 {
      raise DecodeError("PGM: maxval outside 1..255 is not supported")
    }
    decode_p2(data, width, height, pos3, maxval)
  } else if magic == 0x34 {
    // P4: packed bitmap, no maxval token.
    decode_p4(data, width, height, pos2 + 1)
  } else {
    raise DecodeError("PGM: unsupported format (only P2, P4 and P5)")
  }
}
