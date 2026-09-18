///| Segmentation: turning a binarized image into individual connected regions

///|

///| of ink. These regions are the raw material for line, word and character

///| detection later in the pipeline.

///|

///| A pixel is treated as ink when its value is below `128`; this matches the

///| `0`/`255` ink/paper convention produced by `binarize.mbt` while also

///| working directly on dark-on-light grayscale input.

///| A single connected region of ink, described by its bounding box (inclusive
///

///| left/top, `x + w`/`y + h` are the exclusive right/bottom) and its area in

///|
/// pixels.
pub struct Component {
  x : Int
  y : Int
  w : Int
  h : Int
  area : Int
}

///|
/// Exclusive right edge of the bounding box.
pub fn Component::right(self : Component) -> Int {
  self.x + self.w
}

///|
/// Exclusive bottom edge of the bounding box.
pub fn Component::bottom(self : Component) -> Int {
  self.y + self.h
}

///| Label the connected components of ink using 8-connectivity (pixels that
///

///| touch horizontally, vertically or diagonally belong to the same region).

///|
/// Components are returned in scan order, top-to-bottom then left-to-right.
pub fn connected_components(img : Image) -> Array[Component] {
  let w = img.width
  let h = img.height
  let n = w * h
  let visited = Array::make(n, false)
  let stack = Array::make(n, 0)
  let result : Array[Component] = Array(capacity=0)
  for start = 0; start < n; start = start + 1 {
    if visited[start] {
      continue
    }
    visited[start] = true
    if img.pixels.at(start).to_int() >= 128 {
      continue
    }
    // Flood-fill one ink region with an explicit stack, tracking its bounds.
    let mut sp = 0
    stack[0] = start
    let mut x0 = start % w
    let mut y0 = start / w
    let mut x1 = x0
    let mut y1 = y0
    let mut area = 0
    while sp >= 0 {
      let idx = stack[sp]
      sp = sp - 1
      area = area + 1
      let cx = idx % w
      let cy = idx / w
      if cx < x0 {
        x0 = cx
      }
      if cy < y0 {
        y0 = cy
      }
      if cx > x1 {
        x1 = cx
      }
      if cy > y1 {
        y1 = cy
      }
      for dy = -1; dy <= 1; dy = dy + 1 {
        let ny = cy + dy
        if ny < 0 || ny >= h {
          continue
        }
        for dx = -1; dx <= 1; dx = dx + 1 {
          let nx = cx + dx
          if nx < 0 || nx >= w {
            continue
          }
          let ni = ny * w + nx
          if visited[ni] {
            continue
          }
          visited[ni] = true
          if img.pixels.at(ni).to_int() < 128 {
            sp = sp + 1
            stack[sp] = ni
          }
        }
      }
    }
    result.push({ x: x0, y: y0, w: x1 - x0 + 1, h: y1 - y0 + 1, area, })
  }
  result
}

///| Drop components whose area is below `min_area`, typically used to remove
///

///|
/// stray specks of noise before further analysis.
pub fn filter_small(
  components : Array[Component],
  min_area : Int,
) -> Array[Component] {
  let out : Array[Component] = Array(capacity=0)
  for i = 0; i < components.length(); i = i + 1 {
    let c = components[i]
    if c.area >= min_area {
      out.push(c)
    }
  }
  out
}

///| Group components into text lines by vertical overlap. Components are

///|

///| sorted by their top edge first, then each is assigned to the first line it

///| overlaps vertically, or starts a new line. The result is top-to-bottom in

///|
/// reading order, with each line's components still unsorted horizontally.
pub fn group_lines(components : Array[Component]) -> Array[Array[Component]] {
  components.sort_by(fn(a, b) { a.y - b.y })
  let lines : Array[Array[Component]] = Array(capacity=0)
  let line_y0 : Array[Int] = Array(capacity=0)
  let line_y1 : Array[Int] = Array(capacity=0)
  for i = 0; i < components.length(); i = i + 1 {
    let c = components[i]
    let cy0 = c.y
    let cy1 = c.y + c.h
    let mut placed = false
    for j = 0; j < lines.length(); j = j + 1 {
      if cy0 < line_y1[j] && cy1 > line_y0[j] {
        lines[j].push(c)
        if cy1 > line_y1[j] {
          line_y1[j] = cy1
        }
        placed = true
        break
      }
    }
    if !placed {
      let comps : Array[Component] = Array(capacity=0)
      comps.push(c)
      lines.push(comps)
      line_y0.push(cy0)
      line_y1.push(cy1)
    }
  }
  lines
}

///| Merge components that belong to the same character but were split by a

///| thin gap in the bitmap — the dot over `i` and `j` is the built-in example.

///| Two components merge when their horizontal projections overlap and the

///| vertical gap between them is at most a quarter of the taller one's height,

///|
/// which makes the rule independent of the rendering scale.
pub fn merge_parts(components : Array[Component]) -> Array[Component] {
  components.sort_by(fn(a, b) { if a.y != b.y { a.y - b.y } else { a.x - b.x } })
  let result : Array[Component] = Array(capacity=0)
  for i = 0; i < components.length(); i = i + 1 {
    let c = components[i]
    let mut placed = false
    for j = 0; j < result.length(); j = j + 1 {
      let r = result[j]
      let h_overlap = c.x < r.right() && r.x < c.right()
      let v_gap = if c.bottom() <= r.y {
        r.y - c.bottom()
      } else if r.bottom() <= c.y {
        c.y - r.bottom()
      } else {
        0
      }
      let taller = if c.h > r.h { c.h } else { r.h }
      if h_overlap && v_gap <= taller / 4 {
        let x0 = if c.x < r.x { c.x } else { r.x }
        let y0 = if c.y < r.y { c.y } else { r.y }
        let x1 = if c.right() > r.right() { c.right() } else { r.right() }
        let y1 = if c.bottom() > r.bottom() { c.bottom() } else { r.bottom() }
        result[j] = {
          x: x0,
          y: y0,
          w: x1 - x0,
          h: y1 - y0,
          area: c.area + r.area,
        }
        placed = true
        break
      }
    }
    if !placed {
      result.push(c)
    }
  }
  result
}
