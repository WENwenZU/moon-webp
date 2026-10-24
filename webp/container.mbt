///|
/// The WebP file wrapper: `RIFF`/`WEBP` around a still image, the extended
/// `VP8X` header that announces canvas size and feature flags, and the
/// `ALPH` chunk that carries the alpha plane of a lossy image.
///
/// Only the header chunks are interpreted here. Metadata chunks (`ICCP`,
/// `EXIF`, `XMP `) and animation chunks are walked and skipped, so a file
/// with an ICC profile decodes exactly like one without.

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
/// A WebP file whose header chunks have been validated: the pixel
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
/// Read a whole WebP file and decode its pixels.
///
/// The simple format (`RIFF`/`WEBP`/`VP8L`) and the extended format
/// (`VP8X` header plus metadata chunks plus `VP8L`) both decode. Lossy
/// images are rejected with `UnsupportedLossyImage`: their width and
/// height are still available from `webp_info`.
pub fn decode_webp(data : BytesView) -> WebPImage raise DecodeError {
  let layout = parse_webp(data)
  if !layout.is_lossless {
    raise DecodeError::UnsupportedLossyImage
  }
  let image = decode_vp8l(layout.image)
  { width: image.width, height: image.height, pixels: image.pixels, }
}

///|
/// Read the container header of a WebP file without touching the image
/// payload.
pub fn webp_info(data : BytesView) -> WebPInfo raise DecodeError {
  let layout = parse_webp(data)
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
  let layout = parse_webp(data)
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
/// Walk the RIFF chunks of a WebP file and validate the header chunks.
fn parse_webp(data : BytesView) -> WebPLayout raise DecodeError {
  let file = parse_riff(data)
  if !file.form_is(b"WEBP") {
    raise DecodeError::InvalidRiffForm
  }
  let chunks = file.chunks
  if chunks.length() == 0 {
    raise DecodeError::MissingImageChunk
  }
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
  if !first.id_is(b"VP8X") {
    raise DecodeError::InvalidChunkOrder
  }
  if first.size != 10U {
    raise DecodeError::InvalidVp8xChunk(first.size)
  }
  let canvas_width = le_u24(first.payload, 4) + 1
  let canvas_height = le_u24(first.payload, 7) + 1
  if canvas_width.to_uint64() * canvas_height.to_uint64() >= 1UL << 32 {
    raise DecodeError::CanvasTooLarge
  }
  let flags = le_u32(first.payload, 0)
  let alpha_flag = (flags & 0x10U) != 0U
  let animation_flag = (flags & 0x02U) != 0U
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
  if width != canvas_width || height != canvas_height {
    raise DecodeError::CanvasSizeMismatch
  }
  let has_alpha_chunk = match alpha {
    None => false
    Some(_) => true
  }
  let carries_alpha = alpha_flag || alpha_hint || has_alpha_chunk
  {
    width,
    height,
    has_alpha: carries_alpha,
    has_animation: animation_flag,
    is_lossless,
    alpha,
    image: image_payload,
  }
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
