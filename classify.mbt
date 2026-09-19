///| Classification: matching an extracted glyph feature against a set of

///|

///| labelled references. The simplest robust approach for a small alphabet is

///| nearest-neighbour over the Hamming distance between binarized feature

///| grids, which is what this module implements.

///|
/// A labelled feature grid used as a template.
pub struct Reference {
  label : String
  grid : Array[Int]
}

///|
pub fn Reference::new(label : String, grid : Array[Int]) -> Reference {
  { label, grid, }
}

///| The result of classification: the winning label and its distance (a
///

///|
/// smaller distance means a closer match).
pub struct Match {
  label : String
  distance : Int
}

///|
/// Number of positions at which the two feature vectors differ.
pub fn cell_distance(a : Array[Int], b : Array[Int]) -> Int {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  let mut d = 0
  for i = 0; i < n; i = i + 1 {
    if a[i] != b[i] {
      d = d + 1
    }
  }
  d
}

/// Weighted Hamming distance: every cell where the two grids differ adds its
/// weight instead of 1, so a disagreement in an important cell counts more.
/// Cells past the end of `weights` fall back to weight 1.
pub fn weighted_distance(
  a : Array[Int],
  b : Array[Int],
  weights : Array[Int],
) -> Int {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  let mut d = 0
  for i = 0; i < n; i = i + 1 {
    if a[i] != b[i] {
      let w = if i < weights.length() { weights[i] } else { 1 }
      d = d + w
    }
  }
  d
}

///| Return the reference whose grid is closest to `features`, or `None` when
///

///| there are no references. Ties are broken in favour of the earliest

///|
/// reference.
pub fn classify(features : Array[Int], refs : Array[Reference]) -> Match? {
  let mut best : Match? = None
  for i = 0; i < refs.length(); i = i + 1 {
    let d = cell_distance(features, refs[i].grid)
    match best {
      None => best = Some({ label: refs[i].label, distance: d, })
      Some(m) =>
        if d < m.distance {
          best = Some({ label: refs[i].label, distance: d, })
        }
    }
  }
  best
}

/// A 64-cell weight grid that emphasises the glyph interior (weight `2`) over
/// the outer ring (weight `1`). The interior holds the stroke structure that
/// stays stable across fonts, while the border is more sensitive to noise.
pub fn center_weights() -> Array[Int] {
  let w = Array::make(64, 1)
  for y = 0; y < 8; y = y + 1 {
    for x = 0; x < 8; x = x + 1 {
      if x >= 2 && x <= 5 && y >= 2 && y <= 5 {
        w[y * 8 + x] = 2
      }
    }
  }
  w
}

/// Classify by weighted Hamming distance, giving each cell the importance in
/// `weights`. Otherwise identical to `classify`.
pub fn classify_weighted(
  features : Array[Int],
  refs : Array[Reference],
  weights : Array[Int],
) -> Match? {
  let mut best : Match? = None
  for i = 0; i < refs.length(); i = i + 1 {
    let d = weighted_distance(features, refs[i].grid, weights)
    match best {
      None => best = Some({ label: refs[i].label, distance: d, })
      Some(m) =>
        if d < m.distance {
          best = Some({ label: refs[i].label, distance: d, })
        }
    }
  }
  best
}

///| The ten digit templates from the built-in font, labelled `"0"` through
///

///|
/// `"9"`.
pub fn digit_references() -> Array[Reference] {
  let refs : Array[Reference] = Array(capacity=10)
  for ch in "0123456789" {
    refs.push(Reference::new(ch.to_string(), char_grid(ch)))
  }
  refs
}

///| The 62 templates for digits `0`-`9` and letters `A`-`Z` / `a`-`z`, from
///

///|
/// the built-in font.
pub fn alphanumeric_references() -> Array[Reference] {
  let refs : Array[Reference] = Array(capacity=62)
  for ch in "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz" {
    refs.push(Reference::new(ch.to_string(), char_grid(ch)))
  }
  refs
}
