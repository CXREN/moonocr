///| Command-line demo of the OCR pipeline. Each argument is one line of digits

///|

///| and letters (upper and lower case).

///|

///| It renders them into an image, runs the full pipeline (binarize, segment,

///|

///| group lines, feature-extract, classify) and prints the recognized result.

///|

///|
/// Usage: `moon run cmd/main -- <line1> <line2> ...`
fn main {
  let args = @env.args()
  if args.length() >= 2 {
    let n = args.length() - 1
    let lines : Array[String] = Array(capacity=n)
    for i = 1; i < args.length(); i = i + 1 {
      lines.push(args[i])
    }
    let img = @lib.render_text_block(lines, 4, 8, 16)
    let result = @lib.recognize_text(img)
    println("input:")
    for i = 0; i < lines.length(); i = i + 1 {
      println("  \{lines[i]}")
    }
    println("output: \{result}")
  } else {
    println("usage: moonocr <line1> <line2> ...")
  }
}
