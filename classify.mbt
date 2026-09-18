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
