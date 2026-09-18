# moonocr

A pure-MoonBit **optical character recognition (OCR)** engine. It reads an image,
finds the text in it, and returns the recognised characters — with no
dependencies outside the MoonBit core library.

The engine recognises **digits `0`-`9` and letters `A`-`Z` / `a`-`z`** (62
classes), on a single line or across several lines, and tolerates noise and
uneven illumination.

## Pipeline

```
image ──▶ decode ──▶ binarize ──▶ segment ──▶ features ──▶ classify ──▶ text
 (BMP/PGM/PPM)    (Otsu/fixed/adaptive)   (CCL + lines + parts)  (grid)  (nearest neighbour)
```

Each stage lives in its own module:

| Stage | Module | What it provides |
|-------|--------|------------------|
| Image model | `image.mbt` | `Image`, BT.601 `rgb_to_gray`, packed RGB(A) decode |
| Decoders | `bmp.mbt`, `pgm.mbt`, `ppm.mbt` | `parse_bmp`, `parse_pgm` (P2/P4/P5), `parse_ppm` (P3/P6) |
| Binarization | `binarize.mbt` | `binarize_fixed`, `binarize_otsu`, `binarize_adaptive` |
| Segmentation | `segment.mbt` | `connected_components`, `filter_small`, `group_lines`, `merge_parts` |
| Features | `feature.mbt` | `glyph_grid`, `char_grid` |
| Classification | `classify.mbt` | `classify`, `alphanumeric_references` |
| Recognition | `recognize.mbt` | `recognize_digits`, `recognize_text` |
| Reference font | `font.mbt` | the built-in 8x8 bitmap font and render helpers |

## Quick start

The `cmd/main` package is a small round-trip demo: each command-line argument
is one line of text, rendered to an image, run through the whole pipeline, and
printed back.

```sh
moon run cmd/main -- Hello World 42
```

```
input:
  Hello
  World
  42
output: Hello
World
42
```

## API overview

### Decoding an image

```moonbit nocheck
///|
let img = parse_pgm(bytes) // or parse_bmp / parse_ppm

///|
let gray = img.at(x, y) // 0..=255
```

All decoders return a grayscale `Image` (one byte per pixel, `0` = ink/dark,
`255` = paper/bright) and raise `DecodeError` on malformed input.

### Recognising text

```moonbit nocheck
///|
let text = recognize_text(img) // multi-line, "\n"-joined

///|
let line = recognize_digits(img) // single line
```

Both functions binarize with Otsu, drop noise specks, segment glyphs (rejoining
split parts such as the dot over `i`/`j`), and classify each glyph against the
62 built-in templates.

### Lower-level building blocks

```moonbit nocheck
// Binarization
///|
let bin = binarize_otsu(img)

///|
let adaptive = binarize_adaptive(img, window=15, c=20)

// Segmentation

///|
let components = connected_components(bin)

///|
let big = filter_small(components, min_area=8)

///|
let lines = group_lines(big)

///|
let glyphs = merge_parts(lines[0])

// Features + classification

///|
let grid = glyph_grid(bin, glyphs[0], size=8)

///|
let m = classify(grid, alphanumeric_references()) // Match?
```

## Supported image formats

- **BMP** — 8/24/32-bit uncompressed `BI_RGB`, bottom-up rows.
- **PGM** — P2 (ASCII gray), P4 (packed bitmap), P5 (binary gray), `maxval ≤ 255`.
- **PPM** — P3 (ASCII RGB), P6 (binary RGB), `maxval ≤ 255`; converted to
  grayscale with BT.601 luminance.

There are also `write_pgm_p5` and `write_ppm_p6` encoders for round-trip tests.

## How it works

- **Binarization.** Otsu's method finds a global threshold; an adaptive variant
  uses the local window mean (via an integral image) for uneven lighting.
- **Segmentation.** Ink regions are labelled with 8-connectivity flood fill.
  Components are merged into lines by vertical overlap; `merge_parts` rejoins
  glyphs split by thin gaps (the dot over `i`/`j`); `filter_small` removes noise.
- **Features.** Each glyph's bounding box is downsampled, aspect-preserving,
  onto an 8x8 grid where each cell records whether at least half its pixels are
  ink.
- **Classification.** Nearest neighbour over Hamming distance between grids.
  Reference templates are extracted with the *same* feature pipeline, so a
  clean rendering always matches itself exactly.

## Limitations

- The classifier is template-based and tuned for the built-in 8x8 font; it is
  not a trained model, so real-world fonts and heavy distortion will reduce
  accuracy.
- Only `0`-`9`, `A`-`Z`, `a`-`z` are recognised (no punctuation or diacritics).
- No file I/O in the core library: the decoders take `Bytes`, so callers supply
  the image bytes themselves.

## Testing

```sh
moon test   # 59 tests, all passing
```

## License

Apache-2.0
