/// Walks the bundled animation and prints every composited frame with its
/// duration and a checksum. Each frame is already the whole canvas, so the
/// pictures below show what a viewer would actually display.

///|
fn channel(pixel : UInt, shift : Int) -> Int {
  (pixel >> shift).reinterpret_as_int() & 0xff
}

///|
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
/// FNV-1a over the four bytes of every pixel, in display order.
fn checksum(pixels : Array[UInt]) -> UInt {
  let mut hash = 2166136261U
  for pixel in pixels {
    for shift in [24, 16, 8, 0] {
      hash = (hash ^ ((pixel >> shift) & 0xffU)) * 16777619U
    }
  }
  hash
}

///|
fn hex(value : UInt) -> String {
  let builder = StringBuilder()
  for shift in [28, 24, 20, 16, 12, 8, 4, 0] {
    let digit = ((value >> shift) & 0xfU).reinterpret_as_int()
    let code = if digit < 10 { 48 + digit } else { 87 + digit }
    builder.write_char(code.unsafe_to_char())
  }
  builder.to_string()
}

///|
/// How many pixels this frame changed compared with the previous one.
fn changes(previous : Array[UInt]?, current : Array[UInt]) -> Int {
  match previous {
    None => current.length()
    Some(before) => {
      let mut count = 0
      for index in 0..<current.length() {
        if before[index] != current[index] {
          count = count + 1
        }
      }
      count
    }
  }
}

///|
fn main raise {
  let animation = @webp.decode_animation(@fixtures.animation)
  let loops = if animation.loop_count == 0 {
    "forever"
  } else {
    "\{animation.loop_count} times"
  }
  println(
    "\{animation.width} x \{animation.height}, " +
    "\{animation.frames.length()} frames, loops \{loops}",
  )
  println("background #\{hex(animation.background_color)}")
  println("")
  let mut previous : Array[UInt]? = None
  for index in 0..<animation.frames.length() {
    let frame = animation.frames[index]
    println(
      "frame \{index}: \{frame.duration} ms, " +
      "\{changes(previous, frame.pixels)} pixels changed, " +
      "checksum \{hex(checksum(frame.pixels))}",
    )
    render(animation.width, animation.height, frame.pixels)
    println("")
    previous = Some(frame.pixels)
  }
}
