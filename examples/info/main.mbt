/// Reads the header of each bundled sample and prints what it holds:
/// canvas size, lossless or lossy, alpha channel, animation. No pixel is
/// decoded, so this also works for files the decoder refuses to render.

///|
/// Pads `text` on the right with spaces up to `width` characters.
fn pad(text : String, width : Int) -> String {
  let builder = StringBuilder()
  builder.write_string(text)
  let mut rest = width - text.length()
  while rest > 0 {
    builder.write_char(' ')
    rest = rest - 1
  }
  builder.to_string()
}

///|
fn yes_no(value : Bool) -> String {
  if value {
    "yes"
  } else {
    "no"
  }
}

///|
fn main raise {
  let samples : Array[(String, Bytes)] = [
    ("still.webp", @fixtures.still),
    ("alpha.webp", @fixtures.alpha),
    ("animation.webp", @fixtures.animation),
  ]
  println(
    pad("file", 17) +
    pad("size", 8) +
    pad("codec", 10) +
    pad("alpha", 7) +
    "animation",
  )
  for sample in samples {
    let (name, bytes) = sample
    let info = @webp.webp_info(bytes)
    let size = "\{info.width}x\{info.height}"
    let codec = if info.is_lossless { "lossless" } else { "lossy" }
    println(
      pad(name, 17) +
      pad(size, 8) +
      pad(codec, 10) +
      pad(yes_no(info.has_alpha), 7) +
      yes_no(info.has_animation),
    )
  }
  println("")
  let as_still = try {
    let image = @webp.decode_webp(@fixtures.animation)
    "decoded \{image.width} columns"
  } catch {
    @webp.DecodeError::AnimatedImage => "AnimatedImage"
    err => "\{err}"
  }
  let as_animation = try {
    let animation = @webp.decode_animation(@fixtures.still)
    "decoded \{animation.frames.length()} frames"
  } catch {
    @webp.DecodeError::MissingAnimationFrame => "MissingAnimationFrame"
    err => "\{err}"
  }
  println("decode_webp on the animation:      \{as_still}")
  println("decode_animation on the still:     \{as_animation}")
}
