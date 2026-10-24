///|
/// The WebP file wrapper: `RIFF`/`WEBP` around a still image or an
/// animation, the extended `VP8X` header that announces canvas size and
/// feature flags, the `ALPH` chunk that carries the alpha plane of a
/// lossy image, and the `ANIM`/`ANMF` chunks of an animation.
///
/// Only the header chunks are interpreted here. Metadata chunks (`ICCP`,
/// `EXIF`, `XMP `) are walked and skipped, so a file with an ICC profile
/// decodes exactly like one without.

///|
/// A decoded still image. Pixels are packed ARGB with alpha in bits
/// 31..24, red in 23..16, green in 15..8, and blue in 7..0.
pub struct WebPImage {
  width : Int
  height : Int
  pixels : Array[UInt]
}

///|
/// Facts about a WebP file that do not require decoding the image
/// payload. `has_alpha` folds together the `VP8X` alpha flag, the
/// presence of an `ALPH` chunk, and the VP8L alpha hint.
pub struct WebPInfo {
  width : Int
  height : Int
  has_alpha : Bool
  has_animation : Bool
  is_lossless : Bool
} derive(Eq, @debug.Debug)

///|
pub extend WebPInfo with Eq::{not_equal, equal}

///|
pub extend WebPInfo with @debug.Debug::{to_repr}

///|
/// An 8-bit alpha plane, one byte per pixel in row-major order.
pub struct AlphaPlane {
  width : Int
  height : Int
  values : Bytes
}

///|
/// One animation frame, composited onto the canvas. `pixels` already
/// holds every frame drawn so far, so the frames can be shown in order
/// without any further blending.
pub struct AnimationFrame {
  /// Display time in milliseconds.
  duration : Int
  pixels : Array[UInt]
}

///|
/// A decoded animation: canvas size, loop count, background color, and
/// the composited frames in display order.
pub struct WebPAnimation {
  width : Int
  height : Int
  /// Number of times to repeat, zero meaning forever.
  loop_count : Int
  /// Background color from the `ANIM` chunk, packed ARGB. Frames are
  /// composited over transparency, so this is only a hint for the
  /// display surface.
  background_color : UInt
  frames : Array[AnimationFrame]
}

///|
/// The RIFF header plus the optional `VP8X` chunk: everything a still
/// image and an animation share.
priv struct WebPPreamble {
  file : RiffFile
  has_vp8x : Bool
  width : Int
  height : Int
  flags : UInt
}

///|
/// A WebP still image whose header chunks have been validated: the pixel
/// dimensions, the feature flags, and the payloads later stages need.
priv struct WebPLayout {
  width : Int
  height : Int
  has_alpha : Bool
  has_animation : Bool
  is_lossless : Bool
  alpha : BytesView?
  image : BytesView
}

///|
/// One `ANMF` frame as stored: rectangle, timing, how it is composited,
/// and the image payload that fills it.
priv struct RawFrame {
  x : Int
  y : Int
  width : Int
  height : Int
  duration : Int
  /// True for alpha blending, false for overwriting the rectangle.
  blend : Bool
  dispose_background : Bool
  has_alpha : Bool
  is_lossless : Bool
  image : BytesView
}

///|
/// Read a whole WebP file and decode its pixels.
///
/// The simple format (`RIFF`/`WEBP`/`VP8L`) and the extended format
/// (`VP8X` header plus metadata chunks plus `VP8L`) both decode. Lossy
/// images are rejected with `UnsupportedLossyImage`: their width and
/// height are still available from `webp_info`. Animations are rejected
/// with `AnimatedImage`; `decode_animation` returns their frames.
pub fn decode_webp(data : BytesView) -> WebPImage raise DecodeError {
  let layout = parse_still(read_preamble(data))
  if !layout.is_lossless {
    raise DecodeError::UnsupportedLossyImage
  }
  let image = decode_vp8l(layout.image)
  { width: image.width, height: image.height, pixels: image.pixels, }
}

///|
/// Read the container header of a WebP file without touching the image
/// payload. For an animation this reports the canvas size and whether
/// every frame is lossless.
pub fn webp_info(data : BytesView) -> WebPInfo raise DecodeError {
  let preamble = read_preamble(data)
  if is_animation(preamble) {
    let frames = read_frames(preamble)
    if frames.length() == 0 {
      raise DecodeError::MissingAnimationFrame
    }
    let mut lossless = true
    let mut alpha = (preamble.flags & 0x10U) != 0U
    for frame in frames {
      if !frame.is_lossless {
        lossless = false
      }
      if frame.has_alpha {
        alpha = true
      }
    }
    return {
      width: preamble.width,
      height: preamble.height,
      has_alpha: alpha,
      has_animation: true,
      is_lossless: lossless,
    }
  }
  let layout = parse_still(preamble)
  {
    width: layout.width,
    height: layout.height,
    has_alpha: layout.has_alpha,
    has_animation: layout.has_animation,
    is_lossless: layout.is_lossless,
  }
}

///|
/// Decode the `ALPH` chunk of a WebP file into its alpha plane.
///
/// `ALPH` only accompanies lossy images, whose pixels this library does
/// not decode; the plane is still useful for pairing with a lossy
/// decoder elsewhere. Lossless files keep their alpha channel inside the
/// `VP8L` pixels, so asking for a plane there raises
/// `MissingAlphaChunk` even if a stray `ALPH` chunk is present.
pub fn decode_alpha(data : BytesView) -> AlphaPlane raise DecodeError {
  let layout = parse_still(read_preamble(data))
  if layout.is_lossless {
    raise DecodeError::MissingAlphaChunk
  }
  let payload = match layout.alpha {
    None => raise DecodeError::MissingAlphaChunk
    Some(bytes) => bytes
  }
  {
    width: layout.width,
    height: layout.height,
    values: decode_alpha_payload(payload, layout.width, layout.height),
  }
}

///|
/// Decode an animated WebP file into its composited frames.
///
/// Each frame is drawn onto a canvas that starts transparent, is cleared
/// where the previous frame asked to be disposed, and is blended or
/// overwritten according to the frame's own method. Every returned frame
/// carries the whole canvas, so playing the animation is a straight walk
/// over the list.
pub fn decode_animation(data : BytesView) -> WebPAnimation raise DecodeError {
  let preamble = read_preamble(data)
  if !is_animation(preamble) {
    raise DecodeError::MissingAnimationFrame
  }
  let (loop_count, background_color) = read_animation_header(preamble)
  let frames = read_frames(preamble)
  if frames.length() == 0 {
    raise DecodeError::MissingAnimationFrame
  }
  let decoded : Array[Array[UInt]] = []
  for frame in frames {
    decoded.push(decode_frame_pixels(frame))
  }
  {
    width: preamble.width,
    height: preamble.height,
    loop_count,
    background_color,
    frames: compose_frames(frames, decoded, preamble.width, preamble.height),
  }
}

///|
/// True when the `VP8X` header announces an animation.
fn is_animation(preamble : WebPPreamble) -> Bool {
  preamble.has_vp8x && (preamble.flags & 0x02U) != 0U
}

///|
/// Validate the RIFF form and the optional `VP8X` chunk, which every
/// other entry point starts from.
fn read_preamble(data : BytesView) -> WebPPreamble raise DecodeError {
  let file = parse_riff(data)
  if !file.form_is(b"WEBP") {
    raise DecodeError::InvalidRiffForm
  }
  if file.chunks.length() == 0 {
    raise DecodeError::MissingImageChunk
  }
  let first = file.chunks[0]
  if !first.id_is(b"VP8X") {
    return { file, has_vp8x: false, width: 0, height: 0, flags: 0U, }
  }
  if first.size != 10U {
    raise DecodeError::InvalidVp8xChunk(first.size)
  }
  let width = le_u24(first.payload, 4) + 1
  let height = le_u24(first.payload, 7) + 1
  if width.to_uint64() * height.to_uint64() >= 1UL << 32 {
    raise DecodeError::CanvasTooLarge
  }
  { file, has_vp8x: true, width, height, flags: le_u32(first.payload, 0), }
}

///|
/// Find the image chunk of a still file and validate it against the
/// canvas the `VP8X` header announced.
fn parse_still(preamble : WebPPreamble) -> WebPLayout raise DecodeError {
  if is_animation(preamble) {
    raise DecodeError::AnimatedImage
  }
  let chunks = preamble.file.chunks
  if !preamble.has_vp8x {
    let first = chunks[0]
    if first.id_is(b"VP8L") {
      let header = parse_vp8l_header(first.payload)
      return {
        width: header.width,
        height: header.height,
        has_alpha: header.alpha_is_used,
        has_animation: false,
        is_lossless: true,
        alpha: None,
        image: first.payload,
      }
    }
    if first.id_is(b"VP8 ") {
      let (width, height) = parse_vp8_frame_header(first.payload)
      return {
        width,
        height,
        has_alpha: false,
        has_animation: false,
        is_lossless: false,
        alpha: None,
        image: first.payload,
      }
    }
    raise DecodeError::InvalidChunkOrder
  }
  let mut alpha : BytesView? = None
  let mut image : BytesView? = None
  let mut is_lossless = false
  let mut index = 1
  while index < chunks.length() {
    let current = chunks[index]
    if current.id_is(b"VP8L") || current.id_is(b"VP8 ") {
      image = Some(current.payload)
      is_lossless = current.id_is(b"VP8L")
      break
    }
    if current.id_is(b"ALPH") {
      match alpha {
        None => alpha = Some(current.payload)
        Some(_) => ()
      }
    }
    index = index + 1
  }
  let image_payload = match image {
    None => raise DecodeError::MissingImageChunk
    Some(payload) => payload
  }
  let (width, height, alpha_hint) = if is_lossless {
    let header = parse_vp8l_header(image_payload)
    (header.width, header.height, header.alpha_is_used)
  } else {
    let (width, height) = parse_vp8_frame_header(image_payload)
    (width, height, false)
  }
  if width != preamble.width || height != preamble.height {
    raise DecodeError::CanvasSizeMismatch
  }
  let has_alpha_chunk = match alpha {
    None => false
    Some(_) => true
  }
  let carries_alpha = (preamble.flags & 0x10U) != 0U ||
    alpha_hint ||
    has_alpha_chunk
  {
    width,
    height,
    has_alpha: carries_alpha,
    has_animation: false,
    is_lossless,
    alpha,
    image: image_payload,
  }
}

///|
/// Read the `ANIM` chunk: background color and loop count.
fn read_animation_header(
  preamble : WebPPreamble,
) -> (Int, UInt) raise DecodeError {
  for chunk in preamble.file.chunks {
    if chunk.id_is(b"ANIM") {
      if chunk.size.reinterpret_as_int() < 6 {
        raise DecodeError::InvalidAnimationHeader(chunk.size)
      }
      let background = le_u32(chunk.payload, 0)
      let loop_count = le_u16(chunk.payload, 4).reinterpret_as_int()
      return (loop_count, background)
    }
    if chunk.id_is(b"ANMF") {
      break
    }
  }
  raise DecodeError::MissingAnimationHeader
}

///|
/// Read the header of every `ANMF` frame. The image payload is only
/// checked as far as its own chunk framing goes; decoding it is left to
/// `decode_frame_pixels`.
fn read_frames(preamble : WebPPreamble) -> Array[RawFrame] raise DecodeError {
  let frames : Array[RawFrame] = []
  for chunk in preamble.file.chunks {
    if !chunk.id_is(b"ANMF") {
      continue
    }
    let payload = chunk.payload
    if payload.length() < 16 {
      raise DecodeError::InvalidAnimationFrame
    }
    let x = 2 * le_u24_signed(payload, 0)
    let y = 2 * le_u24_signed(payload, 3)
    let width = le_u24(payload, 6) + 1
    let height = le_u24(payload, 9) + 1
    let duration = le_u24(payload, 12)
    let bits = payload.at(15).to_uint()
    if x < 0 ||
      y < 0 ||
      x + width > preamble.width ||
      y + height > preamble.height {
      raise DecodeError::InvalidAnimationFrame
    }
    if width.to_uint64() * height.to_uint64() >= 1UL << 32 {
      raise DecodeError::InvalidAnimationFrame
    }
    let (alpha_chunk, image, is_lossless) = read_frame_payload(payload, 16)
    let alpha_chunk_present = match alpha_chunk {
      None => false
      Some(_) => true
    }
    let has_alpha = alpha_chunk_present ||
      (is_lossless && parse_vp8l_header(image).alpha_is_used)
    frames.push({
      x,
      y,
      width,
      height,
      duration,
      blend: (bits & 2U) == 0U,
      dispose_background: (bits & 1U) != 0U,
      has_alpha,
      is_lossless,
      image,
    })
  }
  frames
}

///|
/// Walk the sub-chunks stored after an `ANMF` header and return the
/// alpha chunk, the image chunk, and whether that image is lossless.
fn read_frame_payload(
  payload : BytesView,
  start : Int,
) -> (BytesView?, BytesView, Bool) raise DecodeError {
  let end = payload.length()
  let mut offset = start
  let mut alpha : BytesView? = None
  let mut image : BytesView? = None
  let mut is_lossless = false
  while offset < end {
    if offset + 8 > end {
      raise DecodeError::InvalidAnimationFrame
    }
    let size = le_u32(payload, offset + 4)
    let data_start = offset + 8
    // Unsigned comparison: a size with the top bit set is not a short
    // chunk, it is a broken one.
    if size > (end - data_start).reinterpret_as_uint() {
      raise DecodeError::InvalidAnimationFrame
    }
    let size_int = size.reinterpret_as_int()
    let data = payload.exact_view(start=data_start, end=data_start + size_int)
    if has_id(payload, offset, b"VP8L") || has_id(payload, offset, b"VP8 ") {
      image = Some(data)
      is_lossless = has_id(payload, offset, b"VP8L")
      break
    }
    if has_id(payload, offset, b"ALPH") {
      match alpha {
        None => alpha = Some(data)
        Some(_) => ()
      }
    }
    offset = data_start + size_int + (size_int & 1)
  }
  let image_payload = match image {
    None => raise DecodeError::InvalidAnimationFrame
    Some(bytes) => bytes
  }
  (alpha, image_payload, is_lossless)
}

///|
/// Decode one frame's image payload and check that it fills the frame
/// rectangle exactly.
///
/// Fully transparent pixels are stored as zero rather than as the RGB
/// values the bitstream carries. Those colors never reach the canvas, and
/// the reference animation decoder drops them too, so keeping them would
/// make a pixel-exact comparison disagree on invisible bytes.
fn decode_frame_pixels(frame : RawFrame) -> Array[UInt] raise DecodeError {
  if !frame.is_lossless {
    raise DecodeError::UnsupportedLossyImage
  }
  let image = decode_vp8l(frame.image)
  if image.width != frame.width || image.height != frame.height {
    raise DecodeError::InvalidAnimationFrame
  }
  let pixels = image.pixels
  for index in 0..<pixels.length() {
    if pixels[index] >> 24 == 0U {
      pixels[index] = 0U
    }
  }
  pixels
}

///|
/// Draw every frame onto the canvas and return the snapshots to display.
///
/// A frame is a key frame when it paints the whole canvas opaquely, or
/// when the canvas is known to be empty at that point: right after a
/// frame that covers the canvas and asked to be disposed, or after any
/// other key frame that was disposed. Key frames skip blending because
/// there is nothing underneath them to blend with, which also keeps the
/// blending arithmetic from perturbing pixels that should stay exact.
fn compose_frames(
  frames : Array[RawFrame],
  decoded : Array[Array[UInt]],
  width : Int,
  height : Int,
) -> Array[AnimationFrame] {
  let canvas : Array[UInt] = Array::make(width * height, 0U)
  let output : Array[AnimationFrame] = []
  let mut previous : RawFrame? = None
  let mut previous_was_key = false
  for index in 0..<frames.length() {
    let frame = frames[index]
    let previous_disposed = match previous {
      Some(prev) => prev.dispose_background
      None => false
    }
    let previous_full_or_key = match previous {
      Some(prev) =>
        (prev.width == width && prev.height == height) || previous_was_key
      None => false
    }
    if previous_disposed {
      match previous {
        Some(prev) => clear_rectangle(canvas, width, prev)
        None => ()
      }
    }
    let full = frame.width == width && frame.height == height
    let key = index == 0 ||
      ((!frame.has_alpha || !frame.blend) && full) ||
      (previous_disposed && previous_full_or_key)
    if key || !frame.blend {
      copy_rectangle(canvas, width, frame, decoded[index])
    } else {
      blend_rectangle(canvas, width, frame, decoded[index])
    }
    output.push({ duration: frame.duration, pixels: canvas.copy(), })
    previous = Some(frame)
    previous_was_key = key
  }
  output
}

///|
/// Reset a frame's rectangle to transparent, as a dispose-to-background
/// request asks for.
fn clear_rectangle(canvas : Array[UInt], width : Int, frame : RawFrame) -> Unit {
  for y in 0..<frame.height {
    let row = (frame.y + y) * width + frame.x
    for x in 0..<frame.width {
      canvas[row + x] = 0U
    }
  }
}

///|
/// Draw a frame's pixels into its rectangle, replacing what is there.
fn copy_rectangle(
  canvas : Array[UInt],
  width : Int,
  frame : RawFrame,
  pixels : Array[UInt],
) -> Unit {
  for y in 0..<frame.height {
    let row = (frame.y + y) * width + frame.x
    for x in 0..<frame.width {
      canvas[row + x] = pixels[y * frame.width + x]
    }
  }
}

///|
/// Draw a frame's pixels over the canvas inside its rectangle.
fn blend_rectangle(
  canvas : Array[UInt],
  width : Int,
  frame : RawFrame,
  pixels : Array[UInt],
) -> Unit {
  for y in 0..<frame.height {
    let row = (frame.y + y) * width + frame.x
    for x in 0..<frame.width {
      let source = pixels[y * frame.width + x]
      canvas[row + x] = blend_over(source, canvas[row + x])
    }
  }
}

///|
/// Composite one ARGB pixel over another. The arithmetic follows the
/// reference decoder, including its approximations: the destination
/// alpha factor is scaled by `256 - source_alpha`, and the channel sum is
/// divided by `blend_alpha` through a fixed-point reciprocal. Fully
/// opaque and fully transparent sources are shortcuts, both because they
/// are common and because dividing would otherwise shift them by one.
fn blend_over(source : UInt, destination : UInt) -> UInt {
  let source_alpha = (source >> 24).reinterpret_as_int() & 0xff
  if source_alpha == 0xff {
    return source
  }
  if source_alpha == 0 {
    return destination
  }
  let destination_alpha = (destination >> 24).reinterpret_as_int() & 0xff
  let destination_factor = (destination_alpha * (256 - source_alpha)) >> 8
  let blend_alpha = source_alpha + destination_factor
  let scale = (1 << 24) / blend_alpha
  let red = blend_channel(
    source, source_alpha, destination, destination_factor, scale, 16,
  )
  let green = blend_channel(
    source, source_alpha, destination, destination_factor, scale, 8,
  )
  let blue = blend_channel(
    source, source_alpha, destination, destination_factor, scale, 0,
  )
  red | green | blue | (blend_alpha.reinterpret_as_uint() << 24)
}

///|
/// Blend one 8-bit channel of `source` over `destination` and put it back
/// at `shift`.
fn blend_channel(
  source : UInt,
  source_alpha : Int,
  destination : UInt,
  destination_factor : Int,
  scale : Int,
  shift : Int,
) -> UInt {
  let source_channel = (source >> shift).reinterpret_as_int() & 0xff
  let destination_channel = (destination >> shift).reinterpret_as_int() & 0xff
  let sum = source_channel * source_alpha +
    destination_channel * destination_factor
  let value = (sum.to_uint64() * scale.to_uint64()) >> 24
  (value.to_uint() & 0xffU) << shift
}

///|
/// Read a 16-bit little-endian unsigned integer at `at`. Bounds are the
/// caller's job.
fn le_u16(bv : BytesView, at : Int) -> UInt {
  bv.at(at).to_uint() | (bv.at(at + 1).to_uint() << 8)
}

///|
/// Read a 24-bit little-endian unsigned integer at `at`. Bounds are the
/// caller's job.
fn le_u24(bv : BytesView, at : Int) -> Int {
  bv.at(at).to_int() |
  (bv.at(at + 1).to_int() << 8) |
  (bv.at(at + 2).to_int() << 16)
}

///|
/// Read a 24-bit little-endian two's-complement integer at `at`.
fn le_u24_signed(bv : BytesView, at : Int) -> Int {
  let value = le_u24(bv, at)
  if value >= 0x800000 {
    value - 0x1000000
  } else {
    value
  }
}

///|
/// Read the width and height out of a `VP8 ` keyframe header.
///
/// The lossy payload is never decoded, so the checks stop where the
/// reference decoder's own header validation stops: signature, keyframe
/// bit, profile, visibility of the first frame, partition length, and
/// non-zero dimensions.
fn parse_vp8_frame_header(payload : BytesView) -> (Int, Int) raise DecodeError {
  if payload.length() < 10 {
    raise DecodeError::InvalidVp8Header
  }
  if payload.at(3) != b'\x9d' ||
    payload.at(4) != b'\x01' ||
    payload.at(5) != b'\x2a' {
    raise DecodeError::InvalidVp8Header
  }
  let tag = payload.at(0).to_int() |
    (payload.at(1).to_int() << 8) |
    (payload.at(2).to_int() << 16)
  if (tag & 1) != 0 {
    raise DecodeError::InvalidVp8Header
  }
  if ((tag >> 1) & 7) > 3 {
    raise DecodeError::InvalidVp8Header
  }
  if ((tag >> 4) & 1) == 0 {
    raise DecodeError::InvalidVp8Header
  }
  if tag >> 5 >= payload.length() {
    raise DecodeError::InvalidVp8Header
  }
  let width = (payload.at(6).to_int() | (payload.at(7).to_int() << 8)) & 0x3fff
  let height = (payload.at(8).to_int() | (payload.at(9).to_int() << 8)) & 0x3fff
  if width == 0 || height == 0 {
    raise DecodeError::InvalidVp8Header
  }
  (width, height)
}

///|
/// Decode an `ALPH` chunk payload: the header byte, then either raw
/// filtered bytes or a VP8L stream that holds the plane in its green
/// channel. The spatial filter is undone afterwards in both cases.
///
/// The pre-processing field only tells a decoder whether the plane was
/// quantized and may be dithered on the way out. Dithering is optional
/// and the reference decoder leaves it off unless asked, so the plane is
/// returned as stored.
fn decode_alpha_payload(
  payload : BytesView,
  width : Int,
  height : Int,
) -> Bytes raise DecodeError {
  if payload.length() < 1 {
    raise DecodeError::AlphaPayloadTooShort
  }
  let header = payload.at(0).to_uint()
  let compression = (header & 3U).reinterpret_as_int()
  let filter = ((header >> 2) & 3U).reinterpret_as_int()
  let pre_processing = ((header >> 4) & 3U).reinterpret_as_int()
  let reserved = (header >> 6) & 3U
  if compression > 1 || pre_processing > 1 || reserved != 0U {
    raise DecodeError::InvalidAlphaHeader(header)
  }
  let data = payload.exact_view(start=1, end=payload.length())
  let count = width * height
  let pixels : Array[Byte] = Array::make(count, b'\x00')
  if compression == 0 {
    if data.length() < count {
      raise DecodeError::AlphaPayloadTooShort
    }
    for index in 0..<count {
      pixels[index] = data.at(index)
    }
  } else {
    let decoded = decode_vp8l_stream(data, width, height)
    for index in 0..<count {
      pixels[index] = ((decoded[index] >> 8) & 0xffU).to_byte()
    }
  }
  if filter != 0 {
    for y in 0..<height {
      let offset = y * width
      let previous : Int? = if y == 0 { None } else { Some(offset - width) }
      unfilter_alpha_row(filter, pixels, offset, width, previous)
    }
  }
  Bytes::from_array(pixels)
}

///|
/// Undo one row of `ALPH` spatial filtering in place. `previous` is the
/// offset of the already-unfiltered row above, or `None` on the first
/// row.
///
/// With no row above, the vertical and gradient filters fall back to
/// predicting from the left, which is what the encoder writes for the
/// top scanline; the horizontal filter seeds itself from the pixel above
/// the left edge once there is a row above.
fn unfilter_alpha_row(
  filter : Int,
  row : Array[Byte],
  offset : Int,
  width : Int,
  previous : Int?,
) -> Unit {
  if filter == 0 {
    return
  }
  if filter == 1 {
    let seed = match previous {
      None => 0
      Some(index) => row[index].to_int()
    }
    unfilter_horizontal(row, offset, width, seed)
    return
  }
  match previous {
    None => unfilter_horizontal(row, offset, width, 0)
    Some(index) =>
      if filter == 2 {
        for x in 0..<width {
          let value = (row[offset + x].to_int() + row[index + x].to_int()) &
            0xff
          row[offset + x] = value.to_byte()
        }
      } else {
        let mut left = row[index].to_int()
        let mut top_left = left
        for x in 0..<width {
          let top = row[index + x].to_int()
          let predicted = clamp_component(left + top - top_left)
          let value = (row[offset + x].to_int() + predicted) & 0xff
          row[offset + x] = value.to_byte()
          left = value
          top_left = top
        }
      }
  }
}

///|
/// Accumulate one row from left to right: each value is the sum of its
/// delta and the pixel to its left, starting from `seed`.
fn unfilter_horizontal(
  row : Array[Byte],
  offset : Int,
  width : Int,
  seed : Int,
) -> Unit {
  let mut predictor = seed
  for x in 0..<width {
    let value = (row[offset + x].to_int() + predictor) & 0xff
    row[offset + x] = value.to_byte()
    predictor = value
  }
}
