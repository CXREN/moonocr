///| An 8-bit grayscale image, stored row-major with the top-left corner as

///| the origin. This is the internal representation used by the OCR pipeline:

///| every downstream stage (binarization, segmentation, classification) reads

///| a single byte per pixel in `0..=255`.

///| Error raised by the image decoders when the input is malformed or uses an

///|
/// unsupported feature.
pub suberror DecodeError {
  DecodeError(String)
}

///|
pub struct Image {
  width : Int
  height : Int
  pixels : Bytes
}

///|
/// Construct an image from raw grayscale bytes (row-major, one byte per pixel).
pub fn Image::new(width : Int, height : Int, pixels : Bytes) -> Image {
  { width, height, pixels, }
}

///|
/// Total number of pixels.
pub fn Image::pixel_count(self : Image) -> Int {
  self.width * self.height
}

///|
/// Byte length of the underlying pixel buffer.
pub fn Image::byte_length(self : Image) -> Int {
  self.pixels.length()
}

///| Grayscale value of the pixel at `(x, y)`, in the inclusive range `0..=255`.

///|

///|
/// `x` is the column and `y` is the row, both zero-based from the top-left.
pub fn Image::at(self : Image, x : Int, y : Int) -> Int {
  self.pixels.at(y * self.width + x).to_int()
}

///| Convert an sRGB byte triple to luminance using the ITU-R BT.601

///|
/// coefficients (0.299 R + 0.587 G + 0.114 B), computed in integer arithmetic.
pub fn rgb_to_gray(r : Int, g : Int, b : Int) -> Int {
  (299 * r + 587 * g + 114 * b) / 1000
}

///| Build a grayscale image from packed multi-channel pixels (row-major).

///|

///| `channels` must be either `3` (RGB) or `4` (RGBA); when it is `4` the

///| alpha byte is ignored. The pixel order within each channel group is the

///|
/// conventional RGB(A) order.
pub fn Image::from_packed(
  width : Int,
  height : Int,
  packed : Bytes,
  channels : Int,
) -> Image {
  let pixels = Bytes::makei(width * height, fn(i) {
    let o = i * channels
    let r = packed.at(o).to_int()
    let g = packed.at(o + 1).to_int()
    let b = packed.at(o + 2).to_int()
    rgb_to_gray(r, g, b).to_byte()
  })
  { width, height, pixels, }
}
