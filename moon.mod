// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "CXREN/moonocr"

version = "0.1.0"

readme = "README.md"

repository = "https://github.com/CXREN/moonocr"

license = "Apache-2.0"

keywords = [ "ocr", "image", "computer-vision", "netpbm", "bmp" ]

preferred_target = "wasm"

description = "A pure-MoonBit OCR engine: BMP/PGM/PPM decoding, binarization, segmentation, feature extraction and nearest-neighbour classification of digits and letters."
