///| A dependency-free Netpbm color loader for P6 (binary RGB) and P3 (ASCII

///| RGB). Both decode into a grayscale `Image` using BT.601 luminance, so a

///| scanned colour photograph can feed the same pipeline as a PGM file.

///| Decode a P6 (binary RGB) raster, rescaling `maxval` to 255 and converting

///|
/// each triple to grayscale.
fn decode_p6(
  data : Bytes,
  width : Int,
  height : Int,
  data_start : Int,
  maxval : Int,
) -> Image {
  let pixels = Bytes::makei(width * height, fn(i) {
    let o = data_start + i * 3
    let r = data.at(o).to_int() * 255 / maxval
    let g = data.at(o + 1).to_int() * 255 / maxval
    let b = data.at(o + 2).to_int() * 255 / maxval
    rgb_to_gray(r, g, b).to_byte()
  })
  Image::new(width, height, pixels)
}

///| Decode a P3 (ASCII RGB) raster, rescaling `maxval` to 255 and converting

///|
/// each triple to grayscale.
fn decode_p3(
  data : Bytes,
  width : Int,
  height : Int,
  data_start : Int,
  maxval : Int,
) -> Image {
  let pixels = Array::make(width * height, b'\x00')
  let mut p = data_start
  for i = 0; i < width * height; i = i + 1 {
    let (r, p1) = read_token_int(data, p)
    let (g, p2) = read_token_int(data, p1)
    let (b, p3) = read_token_int(data, p2)
    pixels[i] = rgb_to_gray(
      r * 255 / maxval,
      g * 255 / maxval,
      b * 255 / maxval,
    ).to_byte()
    p = p3
  }
  Image::new(width, height, Bytes::from_array(pixels))
}

///| Parse a Netpbm colour image (`P3` or `P6`) into a grayscale `Image`.
///

///| Raises `DecodeError` describing the problem when the input is malformed or

///|
/// uses a feature outside the supported subset.
pub fn parse_ppm(data : Bytes) -> Image raise DecodeError {
  if data.length() < 2 {
    raise DecodeError("PPM: buffer too short")
  }
  if data.at(0) != b'P' {
    raise DecodeError("PPM: not a Netpbm file")
  }
  let magic = data.at(1).to_int()
  let (width, pos1) = read_token_int(data, 2)
  let (height, pos2) = read_token_int(data, pos1)
  if width <= 0 || height <= 0 {
    raise DecodeError("PPM: invalid dimensions")
  }
  if magic == 0x36 {
    // P6: binary RGB. A single whitespace byte follows `maxval`.
    let (maxval, pos3) = read_token_int(data, pos2)
    if maxval <= 0 || maxval > 255 {
      raise DecodeError("PPM: maxval outside 1..255 is not supported")
    }
    decode_p6(data, width, height, pos3 + 1, maxval)
  } else if magic == 0x33 {
    // P3: ASCII RGB.
    let (maxval, pos3) = read_token_int(data, pos2)
    if maxval <= 0 || maxval > 255 {
      raise DecodeError("PPM: maxval outside 1..255 is not supported")
    }
    decode_p3(data, width, height, pos3, maxval)
  } else {
    raise DecodeError("PPM: unsupported format (only P3 and P6)")
  }
}

///| Encode a grayscale image as a P6 (binary RGB) PPM with `maxval` 255,

///| writing each gray value into all three channels. The result round-trips

///|
/// through `parse_ppm` byte-for-byte in grayscale.
pub fn write_ppm_p6(img : Image) -> Bytes {
  let header = "P6\n\{img.width} \{img.height}\n255\n"
  let hb = @utf8.encode(header)
  let n = img.pixel_count()
  let out = Array::make(hb.length() + n * 3, b'\x00')
  for i = 0; i < hb.length(); i = i + 1 {
    out[i] = hb.at(i)
  }
  for i = 0; i < n; i = i + 1 {
    let g = img.pixels.at(i)
    out[hb.length() + i * 3] = g
    out[hb.length() + i * 3 + 1] = g
    out[hb.length() + i * 3 + 2] = g
  }
  Bytes::from_array(out)
}
