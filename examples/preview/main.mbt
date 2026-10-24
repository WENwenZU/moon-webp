/// Decodes the bundled stills and draws them in the terminal with 24-bit
/// color. Each character covers two pixels: the foreground color paints
/// the upper half block and the background color paints the lower half,
/// so a 16x16 image takes eight lines and stays square.

///|
fn channel(pixel : UInt, shift : Int) -> Int {
  (pixel >> shift).reinterpret_as_int() & 0xff
}

///|
/// Composites a pixel over mid gray. Alpha has to land somewhere, and a
/// fixed gray keeps the picture readable on light and dark terminals.
fn over_gray(pixel : UInt) -> (Int, Int, Int) {
  let alpha = channel(pixel, 24)
  let rest = 255 - alpha
  (
    (channel(pixel, 16) * alpha + 96 * rest + 127) / 255,
    (channel(pixel, 8) * alpha + 96 * rest + 127) / 255,
    (channel(pixel, 0) * alpha + 96 * rest + 127) / 255,
  )
}

///|
fn render(width : Int, height : Int, pixels : Array[UInt]) -> Unit {
  let mut y = 0
  while y < height {
    let line = StringBuilder()
    let mut top_painted : (Int, Int, Int) = (-1, -1, -1)
    let mut bottom_painted : (Int, Int, Int) = (-1, -1, -1)
    for x in 0..<width {
      let top = over_gray(pixels[y * width + x])
      let bottom = if y + 1 < height {
        over_gray(pixels[(y + 1) * width + x])
      } else {
        top
      }
      if top != top_painted {
        let (red, green, blue) = top
        line.write_string("\u{1b}[38;2;\{red};\{green};\{blue}m")
        top_painted = top
      }
      if bottom != bottom_painted {
        let (red, green, blue) = bottom
        line.write_string("\u{1b}[48;2;\{red};\{green};\{blue}m")
        bottom_painted = bottom
      }
      line.write_string("\u{2580}\u{2580}")
    }
    line.write_string("\u{1b}[0m")
    println(line.to_string())
    y = y + 2
  }
}

///|
fn alpha_stats(pixels : Array[UInt]) -> (Int, Int) {
  let mut clear = 0
  let mut translucent = 0
  for pixel in pixels {
    let alpha = channel(pixel, 24)
    if alpha == 0 {
      clear = clear + 1
    } else if alpha < 255 {
      translucent = translucent + 1
    }
  }
  (clear, translucent)
}

///|
fn main raise {
  let samples : Array[(String, Bytes)] = [
    ("still.webp", @fixtures.still),
    ("alpha.webp", @fixtures.alpha),
  ]
  for sample in samples {
    let (name, bytes) = sample
    let image = @webp.decode_webp(bytes)
    let (clear, translucent) = alpha_stats(image.pixels)
    println(
      "\{name}: \{image.width} x \{image.height}, \{clear} transparent, " +
      "\{translucent} translucent",
    )
    render(image.width, image.height, image.pixels)
    println("")
  }
  println("translucent pixels are composited over gray")
}
