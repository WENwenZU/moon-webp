///|
/// The five-byte VP8L image header.
pub struct Vp8lHeader {
  width : Int
  height : Int
  alpha_is_used : Bool
} derive(Eq, @debug.Debug)

///|
pub extend Vp8lHeader with Eq::{not_equal, equal}

///|
pub extend Vp8lHeader with @debug.Debug::{to_repr}

///|
/// A shared-cursor, least-significant-bit-first VP8L bit reader.
priv struct BitReader {
  data : BytesView
  bit_position : Ref[Int]
}

///|
fn BitReader::new(data : BytesView) -> BitReader {
  { data, bit_position: Ref(0), }
}

///|
/// Read up to 24 bits. The first bit read becomes bit zero of the result.
fn BitReader::read(self : BitReader, count : Int) -> UInt raise DecodeError {
  if count < 0 || count > 24 {
    raise DecodeError::InvalidBitCount(count)
  }
  let position = self.bit_position.val
  let available = self.data.length() * 8
  if position > available || count > available - position {
    raise DecodeError::UnexpectedEnd(self.data.length())
  }
  let mut value = 0U
  for index in 0..<count {
    let source = position + index
    let bit = (self.data.at(source / 8).to_uint() >> (source % 8)) & 1U
    value = value | (bit << index)
  }
  self.bit_position.val = position + count
  value
}

///|
fn read_vp8l_header(reader : BitReader) -> Vp8lHeader raise DecodeError {
  let signature = reader.read(8)
  if signature != 0x2fU {
    raise DecodeError::InvalidVp8lSignature(signature)
  }
  let width = reader.read(14).reinterpret_as_int() + 1
  let height = reader.read(14).reinterpret_as_int() + 1
  check_dimensions(width, height)
  let alpha_is_used = reader.read(1) != 0U
  let version = reader.read(3)
  if version != 0U {
    raise DecodeError::UnsupportedVp8lVersion(version)
  }
  { width, height, alpha_is_used, }
}

///|
/// Parse the VP8L signature, dimensions, alpha hint, and reserved version.
pub fn parse_vp8l_header(data : BytesView) -> Vp8lHeader raise DecodeError {
  read_vp8l_header(BitReader::new(data))
}

///|
/// A canonical prefix code, stored as per-length counts and symbols sorted
/// by (code length, symbol). A single-symbol code consumes no input bits.
priv struct PrefixCode {
  counts : Array[Int]
  symbols : Array[Int]
  single_symbol : Int
}

///|
fn PrefixCode::from_lengths(
  lengths : Array[Int],
) -> PrefixCode raise DecodeError {
  if lengths.is_empty() {
    raise DecodeError::InvalidPrefixTree
  }
  let counts = Array::make(16, 0)
  let mut symbol_count = 0
  for length in lengths {
    if length < 0 || length > 15 {
      raise DecodeError::InvalidPrefixTree
    }
    counts[length] = counts[length] + 1
    if length != 0 {
      symbol_count = symbol_count + 1
    }
  }
  let mut remaining = 1
  for length in 1..<16 {
    remaining = (remaining << 1) - counts[length]
    if remaining < 0 {
      raise DecodeError::InvalidPrefixTree
    }
  }
  let mut single_symbol = -1
  if symbol_count == 1 {
    if counts[1] != 1 {
      raise DecodeError::InvalidPrefixTree
    }
    for symbol in 0..<lengths.length() {
      if lengths[symbol] == 1 {
        single_symbol = symbol
      }
    }
  } else if symbol_count == 0 || remaining != 0 {
    raise DecodeError::InvalidPrefixTree
  }
  let symbols : Array[Int] = []
  for length in 1..<16 {
    for symbol in 0..<lengths.length() {
      if lengths[symbol] == length {
        symbols.push(symbol)
      }
    }
  }
  { counts, symbols, single_symbol, }
}

///|
fn PrefixCode::read_symbol(
  self : PrefixCode,
  reader : BitReader,
) -> Int raise DecodeError {
  if self.single_symbol >= 0 {
    return self.single_symbol
  }
  let mut code = 0
  let mut first = 0
  let mut index = 0
  for length in 1..<16 {
    code = code | reader.read(1).reinterpret_as_int()
    let count = self.counts[length]
    if code >= first && code < first + count {
      return self.symbols[index + code - first]
    }
    index = index + count
    first = (first + count) << 1
    code = code << 1
  }
  raise DecodeError::InvalidPrefixTree
}

///|
/// Read either the simple or normal representation of one prefix code.
fn read_prefix_code(
  reader : BitReader,
  alphabet_size : Int,
) -> PrefixCode raise DecodeError {
  let lengths = Array::make(alphabet_size, 0)
  if reader.read(1) == 1U {
    let symbol_count = reader.read(1).reinterpret_as_int() + 1
    let first_8bits = reader.read(1) == 1U
    let first_width = if first_8bits { 8 } else { 1 }
    let first = reader.read(first_width).reinterpret_as_int()
    if first >= alphabet_size {
      raise DecodeError::InvalidPrefixSymbol(first)
    }
    lengths[first] = 1
    if symbol_count == 2 {
      let second = reader.read(8).reinterpret_as_int()
      if second >= alphabet_size {
        raise DecodeError::InvalidPrefixSymbol(second)
      }
      if second == first {
        // Duplicate symbols are legal, though inefficient. They still
        // form a two-leaf tree and therefore consume one bit per symbol.
        let counts = Array::make(16, 0)
        counts[1] = 2
        return { counts, symbols: [first, first], single_symbol: -1, }
      }
      lengths[second] = 1
    }
    return PrefixCode::from_lengths(lengths)
  }
  let order = [17, 18, 0, 1, 2, 3, 4, 5, 16, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  let code_length_count = 4 + reader.read(4).reinterpret_as_int()
  let code_length_lengths = Array::make(19, 0)
  for index in 0..<code_length_count {
    code_length_lengths[order[index]] = reader.read(3).reinterpret_as_int()
  }
  let code_length_code = PrefixCode::from_lengths(code_length_lengths)
  let mut max_symbol = alphabet_size
  if reader.read(1) == 1U {
    let length_nbits = 2 + 2 * reader.read(3).reinterpret_as_int()
    max_symbol = 2 + reader.read(length_nbits).reinterpret_as_int()
    if max_symbol > alphabet_size {
      raise DecodeError::InvalidPrefixSymbol(max_symbol)
    }
  }
  // `max_symbol` caps the number of code-length tokens that are read, not the
  // number of lengths they produce: a repeat token can cover a whole run at
  // once. The length list therefore still has to reach the end of the alphabet,
  // which is how the reference decoder reads it.
  let mut index = 0
  let mut tokens = 0
  let mut previous_nonzero = 8
  while index < alphabet_size && tokens < max_symbol {
    tokens = tokens + 1
    let code = code_length_code.read_symbol(reader)
    if code <= 15 {
      lengths[index] = code
      if code != 0 {
        previous_nonzero = code
      }
      index = index + 1
    } else {
      let (value, repeat) = match code {
        16 => (previous_nonzero, 3 + reader.read(2).reinterpret_as_int())
        17 => (0, 3 + reader.read(3).reinterpret_as_int())
        18 => (0, 11 + reader.read(7).reinterpret_as_int())
        _ => raise DecodeError::InvalidPrefixTree
      }
      if repeat > alphabet_size - index {
        raise DecodeError::PrefixRepeatOverrun
      }
      for _ in 0..<repeat {
        lengths[index] = value
        index = index + 1
      }
    }
  }
  PrefixCode::from_lengths(lengths)
}

///|
priv struct ColorCacheInfo {
  bits : Int
  size : Int
}

///|
fn read_color_cache_info(
  reader : BitReader,
) -> ColorCacheInfo raise DecodeError {
  if reader.read(1) == 0U {
    return { bits: 0, size: 0, }
  }
  let bits = reader.read(4).reinterpret_as_int()
  if bits < 1 || bits > 11 {
    raise DecodeError::InvalidColorCacheBits(bits)
  }
  { bits, size: 1 << bits, }
}

///|
priv struct PrefixCodeGroup {
  green : PrefixCode
  red : PrefixCode
  blue : PrefixCode
  alpha : PrefixCode
  distance : PrefixCode
}

///|
fn read_prefix_code_group(
  reader : BitReader,
  color_cache_size : Int,
) -> PrefixCodeGroup raise DecodeError {
  {
    green: read_prefix_code(reader, 256 + 24 + color_cache_size),
    red: read_prefix_code(reader, 256),
    blue: read_prefix_code(reader, 256),
    alpha: read_prefix_code(reader, 256),
    distance: read_prefix_code(reader, 40),
  }
}

///|
/// Dimensions and mapping for the optional entropy (meta prefix) image.
priv struct MetaPrefixInfo {
  prefix_bits : Int
  image_width : Int
  image_height : Int
}

///|
fn MetaPrefixInfo::read(
  reader : BitReader,
  width : Int,
  height : Int,
) -> MetaPrefixInfo? raise DecodeError {
  if reader.read(1) == 0U {
    return None
  }
  if width <= 0 || height <= 0 {
    raise DecodeError::InvalidEntropyImage
  }
  let prefix_bits = reader.read(3).reinterpret_as_int() + 2
  let tile_size = 1 << prefix_bits
  Some({
    prefix_bits,
    image_width: (width + tile_size - 1) / tile_size,
    image_height: (height + tile_size - 1) / tile_size,
  })
}

///|
fn MetaPrefixInfo::group_index(
  self : MetaPrefixInfo,
  entropy : Array[UInt],
  x : Int,
  y : Int,
) -> Int raise DecodeError {
  if x < 0 ||
    y < 0 ||
    entropy.length() != self.image_width * self.image_height ||
    x >> self.prefix_bits >= self.image_width ||
    y >> self.prefix_bits >= self.image_height {
    raise DecodeError::InvalidEntropyImage
  }
  let position = (y >> self.prefix_bits) * self.image_width +
    (x >> self.prefix_bits)
  ((entropy[position] >> 8) & 0xffffU).reinterpret_as_int()
}

///|
fn meta_prefix_group_count(entropy : Array[UInt]) -> Int raise DecodeError {
  if entropy.is_empty() {
    raise DecodeError::InvalidEntropyImage
  }
  let mut largest = 0U
  for pixel in entropy {
    let group = (pixel >> 8) & 0xffffU
    if group > largest {
      largest = group
    }
  }
  largest.reinterpret_as_int() + 1
}

///|
/// A decoded VP8L image. Pixels are packed ARGB with alpha in bits
/// 31..24, red in 23..16, green in 15..8, and blue in 7..0.
pub struct Vp8lImage {
  width : Int
  height : Int
  pixels : Array[UInt]
}

///|
/// The 120 neighborhood distance codes around the current pixel,
/// packed as `(y_offset << 4) | (8 - x_offset)`.
fn distance_map() -> Array[Int] {
  [
    0x18, 0x07, 0x17, 0x19, 0x28, 0x06, 0x27, 0x29, 0x16, 0x1a, 0x26, 0x2a, 0x38,
    0x05, 0x37, 0x39, 0x15, 0x1b, 0x36, 0x3a, 0x25, 0x2b, 0x48, 0x04, 0x47, 0x49,
    0x14, 0x1c, 0x35, 0x3b, 0x46, 0x4a, 0x24, 0x2c, 0x58, 0x45, 0x4b, 0x34, 0x3c,
    0x03, 0x57, 0x59, 0x13, 0x1d, 0x56, 0x5a, 0x23, 0x2d, 0x44, 0x4c, 0x55, 0x5b,
    0x33, 0x3d, 0x68, 0x02, 0x67, 0x69, 0x12, 0x1e, 0x66, 0x6a, 0x22, 0x2e, 0x54,
    0x5c, 0x43, 0x4d, 0x65, 0x6b, 0x32, 0x3e, 0x78, 0x01, 0x77, 0x79, 0x53, 0x5d,
    0x11, 0x1f, 0x64, 0x6c, 0x42, 0x4e, 0x76, 0x7a, 0x21, 0x2f, 0x75, 0x7b, 0x31,
    0x3f, 0x63, 0x6d, 0x52, 0x5e, 0x00, 0x74, 0x7c, 0x41, 0x4f, 0x10, 0x20, 0x62,
    0x6e, 0x30, 0x73, 0x7d, 0x51, 0x5f, 0x40, 0x72, 0x7e, 0x61, 0x6f, 0x50, 0x71,
    0x7f, 0x60, 0x70,
  ]
}

///|
fn copy_value(reader : BitReader, prefix_code : Int) -> Int raise DecodeError {
  if prefix_code < 4 {
    return prefix_code + 1
  }
  let extra_bits = (prefix_code - 2) >> 1
  let offset = (2 + (prefix_code & 1)) << extra_bits
  offset + reader.read(extra_bits).reinterpret_as_int() + 1
}

///|
fn plane_distance(
  image_width : Int,
  distance_code : Int,
  offsets : Array[Int],
) -> Int {
  if distance_code > 120 {
    return distance_code - 120
  }
  let packed = offsets[distance_code - 1]
  let y_offset = packed >> 4
  let x_offset = 8 - (packed & 0xf)
  let distance = y_offset * image_width + x_offset
  if distance < 1 {
    1
  } else {
    distance
  }
}

///|
fn color_cache_key(color : UInt, bits : Int) -> Int {
  ((0x1e35a7bdU * color) >> (32 - bits)).reinterpret_as_int()
}

///|
fn color_cache_insert(cache : Array[UInt], bits : Int, color : UInt) -> Unit {
  if bits > 0 {
    cache[color_cache_key(color, bits)] = color
  }
}

///|
priv struct PrefixGroupSelector {
  meta : MetaPrefixInfo?
  entropy : Array[UInt]
  groups : Array[PrefixCodeGroup]
}

///|
fn PrefixGroupSelector::for_pixel(
  self : PrefixGroupSelector,
  x : Int,
  y : Int,
) -> PrefixCodeGroup raise DecodeError {
  match self.meta {
    None => self.groups[0]
    Some(meta) => self.groups[meta.group_index(self.entropy, x, y)]
  }
}

///|
fn read_prefix_groups(
  reader : BitReader,
  width : Int,
  height : Int,
  allow_meta : Bool,
  color_cache_size : Int,
) -> PrefixGroupSelector raise DecodeError {
  let meta = if allow_meta {
    MetaPrefixInfo::read(reader, width, height)
  } else {
    None
  }
  match meta {
    None =>
      {
        meta: None,
        entropy: [],
        groups: [read_prefix_code_group(reader, color_cache_size)],
      }
    Some(info) => {
      let entropy = decode_image_stream(
        reader,
        info.image_width,
        info.image_height,
        false,
        false,
      )
      let group_count = meta_prefix_group_count(entropy)
      let groups : Array[PrefixCodeGroup] = []
      for _ in 0..<group_count {
        groups.push(read_prefix_code_group(reader, color_cache_size))
      }
      { meta: Some(info), entropy, groups, }
    }
  }
}

///|
fn decode_image_pixels(
  reader : BitReader,
  width : Int,
  height : Int,
  cache : ColorCacheInfo,
  selector : PrefixGroupSelector,
  distance_offsets : Array[Int],
) -> Array[UInt] raise DecodeError {
  let total = width * height
  let cache_values = Array::make(cache.size, 0U)
  let pixels : Array[UInt] = []
  while pixels.length() < total {
    let x = pixels.length() % width
    let y = pixels.length() / width
    let group = selector.for_pixel(x, y)
    let symbol = group.green.read_symbol(reader)
    if symbol < 256 {
      let red = group.red.read_symbol(reader)
      let blue = group.blue.read_symbol(reader)
      let alpha = group.alpha.read_symbol(reader)
      let color = (alpha.reinterpret_as_uint() << 24) |
        (red.reinterpret_as_uint() << 16) |
        (symbol.reinterpret_as_uint() << 8) |
        blue.reinterpret_as_uint()
      pixels.push(color)
      color_cache_insert(cache_values, cache.bits, color)
    } else if symbol < 280 {
      let length = copy_value(reader, symbol - 256)
      if length > total - pixels.length() {
        raise DecodeError::BackwardReferenceOverrun(length)
      }
      let distance_symbol = group.distance.read_symbol(reader)
      let distance_code = copy_value(reader, distance_symbol)
      let distance = plane_distance(width, distance_code, distance_offsets)
      if distance <= 0 || distance > pixels.length() {
        raise DecodeError::InvalidBackwardReference(distance)
      }
      for _ in 0..<length {
        let color = pixels[pixels.length() - distance]
        pixels.push(color)
        color_cache_insert(cache_values, cache.bits, color)
      }
    } else {
      let index = symbol - 280
      if index < 0 || index >= cache.size {
        raise DecodeError::InvalidColorCacheIndex(index)
      }
      let color = cache_values[index]
      pixels.push(color)
      color_cache_insert(cache_values, cache.bits, color)
    }
  }
  pixels
}

///|
fn div_round_up(value : Int, divisor : Int) -> Int {
  (value + divisor - 1) / divisor
}

///|
fn component(color : UInt, shift : Int) -> Int {
  ((color >> shift) & 0xffU).reinterpret_as_int()
}

///|
fn add_pixels(a : UInt, b : UInt) -> UInt {
  let mut result = 0U
  for index in 0..<4 {
    let shift = index * 8
    let value = (component(a, shift) + component(b, shift)) & 0xff
    result = result | (value.reinterpret_as_uint() << shift)
  }
  result
}

///|
fn average2(a : UInt, b : UInt) -> UInt {
  let mut result = 0U
  for index in 0..<4 {
    let shift = index * 8
    let value = (component(a, shift) + component(b, shift)) >> 1
    result = result | (value.reinterpret_as_uint() << shift)
  }
  result
}

///|
fn absolute(value : Int) -> Int {
  if value < 0 {
    -value
  } else {
    value
  }
}

///|
fn select_predictor(left : UInt, top : UInt, top_left : UInt) -> UInt {
  let mut score = 0
  for index in 0..<4 {
    let shift = index * 8
    let a = component(top, shift)
    let b = component(left, shift)
    let c = component(top_left, shift)
    score = score + absolute(b - c) - absolute(a - c)
  }
  if score <= 0 {
    top
  } else {
    left
  }
}

///|
fn clamp_component(value : Int) -> Int {
  if value < 0 {
    0
  } else if value > 255 {
    255
  } else {
    value
  }
}

///|
fn clamp_add_subtract_full(left : UInt, top : UInt, top_left : UInt) -> UInt {
  let mut result = 0U
  for index in 0..<4 {
    let shift = index * 8
    let value = clamp_component(
      component(left, shift) +
      component(top, shift) -
      component(top_left, shift),
    )
    result = result | (value.reinterpret_as_uint() << shift)
  }
  result
}

///|
fn trunc_div2(value : Int) -> Int {
  if value < 0 {
    -(-value / 2)
  } else {
    value / 2
  }
}

///|
fn clamp_add_subtract_half(left : UInt, top : UInt, top_left : UInt) -> UInt {
  let average = average2(left, top)
  let mut result = 0U
  for index in 0..<4 {
    let shift = index * 8
    let value = clamp_component(
      component(average, shift) +
      trunc_div2(component(average, shift) - component(top_left, shift)),
    )
    result = result | (value.reinterpret_as_uint() << shift)
  }
  result
}

///|
fn predict_pixel(
  mode : Int,
  left : UInt,
  top : UInt,
  top_left : UInt,
  top_right : UInt,
) -> UInt raise DecodeError {
  match mode {
    0 => 0xff000000U
    1 => left
    2 => top
    3 => top_right
    4 => top_left
    5 => average2(average2(left, top_right), top)
    6 => average2(left, top_left)
    7 => average2(left, top)
    8 => average2(top_left, top)
    9 => average2(top, top_right)
    10 => average2(average2(left, top_left), average2(top, top_right))
    11 => select_predictor(left, top, top_left)
    12 => clamp_add_subtract_full(left, top, top_left)
    13 => clamp_add_subtract_half(left, top, top_left)
    _ => raise DecodeError::InvalidPredictorMode(mode)
  }
}

///|
fn signed_byte(value : Int) -> Int {
  let unsigned = value & 0xff
  if unsigned >= 128 {
    unsigned - 256
  } else {
    unsigned
  }
}

///|
fn color_transform_delta(multiplier : Int, color : Int) -> Int {
  (signed_byte(multiplier) * signed_byte(color)) >> 5
}

///|
priv enum Vp8lTransformKind {
  Predictor
  CrossColor
  SubtractGreen
  ColorIndexing
}

///|
priv struct Vp8lTransform {
  kind : Vp8lTransformKind
  bits : Int
  xsize : Int
  palette_size : Int
  data : Array[UInt]
}

///|
fn cumulative_palette(raw : Array[UInt], size : Int) -> Array[UInt] {
  let palette = Array::make(size, 0U)
  if size > 0 {
    palette[0] = raw[0]
  }
  for index in 1..<size {
    palette[index] = add_pixels(raw[index], palette[index - 1])
  }
  palette
}

///|
fn read_transforms(
  reader : BitReader,
  width : Int,
  height : Int,
) -> (Array[Vp8lTransform], Int) raise DecodeError {
  let transforms : Array[Vp8lTransform] = []
  let mut current_width = width
  let mut seen = 0
  while reader.read(1) == 1U {
    let transform_type = reader.read(2).reinterpret_as_int()
    let kind = match transform_type {
      0 => Predictor
      1 => CrossColor
      2 => SubtractGreen
      _ => ColorIndexing
    }
    if (seen & (1 << transform_type)) != 0 {
      raise DecodeError::DuplicateVp8lTransform(transform_type)
    }
    seen = seen | (1 << transform_type)
    match kind {
      Predictor | CrossColor => {
        let bits = reader.read(3).reinterpret_as_int() + 2
        // The transform data is a subsampled image holding one entry per
        // tile: the predictor mode or the color coefficients.
        let tile_size = 1 << bits
        let data = decode_image_stream(
          reader,
          div_round_up(current_width, tile_size),
          div_round_up(height, tile_size),
          false,
          false,
        )
        transforms.push({
          kind,
          bits,
          xsize: current_width,
          palette_size: 0,
          data,
        })
      }
      SubtractGreen =>
        transforms.push({
          kind,
          bits: 0,
          xsize: current_width,
          palette_size: 0,
          data: [],
        })
      ColorIndexing => {
        let color_count = reader.read(8).reinterpret_as_int() + 1
        // Fewer colors buy more bits per index: pairs, quads, or bytes.
        let bits = if color_count > 16 {
          0
        } else if color_count > 4 {
          1
        } else if color_count > 2 {
          2
        } else {
          3
        }
        let original_width = current_width
        current_width = div_round_up(current_width, 1 << bits)
        // The palette is a one-pixel-high image, delta coded against the
        // entry before it.
        let raw_palette = decode_image_stream(
          reader, color_count, 1, false, false,
        )
        transforms.push({
          kind,
          bits,
          xsize: original_width,
          palette_size: color_count,
          data: cumulative_palette(raw_palette, color_count),
        })
      }
    }
  }
  (transforms, current_width)
}

///|
fn inverse_predictor(
  pixels : Array[UInt],
  width : Int,
  height : Int,
  transform : Vp8lTransform,
) -> Array[UInt] raise DecodeError {
  let output = Array::make(width * height, 0U)
  let tile_width = 1 << transform.bits
  let tiles_per_row = div_round_up(width, tile_width)
  for y in 0..<height {
    for x in 0..<width {
      let index = y * width + x
      // Border pixels ignore the tile mode: the top-left pixel predicts
      // black, the rest of the top row predicts from the pixel on its left,
      // and the leftmost pixel of every other row predicts from the pixel
      // above it.
      let prediction = if y == 0 && x == 0 {
        0xff000000U
      } else if y == 0 {
        output[index - 1]
      } else if x == 0 {
        output[index - width]
      } else {
        let tile = (y >> transform.bits) * tiles_per_row + (x >> transform.bits)
        // The low four bits of the green channel hold the mode; the
        // reference decoder masks them off rather than validating the byte.
        let mode = component(transform.data[tile], 8) & 0xf
        // The rightmost column borrows the first pixel of its own row as the
        // top-right neighbour.
        let top_right = if x + 1 < width {
          output[index - width + 1]
        } else {
          output[y * width]
        }
        predict_pixel(
          mode,
          output[index - 1],
          output[index - width],
          output[index - width - 1],
          top_right,
        )
      }
      output[index] = add_pixels(pixels[index], prediction)
    }
  }
  output
}

///|
fn inverse_cross_color(
  pixels : Array[UInt],
  width : Int,
  height : Int,
  transform : Vp8lTransform,
) -> Array[UInt] {
  let output = Array::make(width * height, 0U)
  let tile_size = 1 << transform.bits
  let tiles_per_row = div_round_up(width, tile_size)
  for y in 0..<height {
    for x in 0..<width {
      let coefficient = transform.data[(y >> transform.bits) * tiles_per_row +
        (x >> transform.bits)]
      let green = component(pixels[y * width + x], 8)
      let green_to_red = component(coefficient, 0)
      let green_to_blue = component(coefficient, 8)
      let red_to_blue = component(coefficient, 16)
      let red = component(pixels[y * width + x], 16)
      let blue = component(pixels[y * width + x], 0)
      let new_red = (red + color_transform_delta(green_to_red, green)) & 0xff
      let new_blue = (
          blue +
          color_transform_delta(green_to_blue, green) +
          color_transform_delta(red_to_blue, new_red)
        ) &
        0xff
      output[y * width + x] = (pixels[y * width + x] & 0xff00ff00U) |
        (new_red.reinterpret_as_uint() << 16) |
        new_blue.reinterpret_as_uint()
    }
  }
  output
}

///|
fn inverse_subtract_green(
  pixels : Array[UInt],
  width : Int,
  height : Int,
) -> Array[UInt] {
  let output = Array::make(width * height, 0U)
  for index in 0..<(width * height) {
    let color = pixels[index]
    let green = component(color, 8)
    let red = (component(color, 16) + green) & 0xff
    let blue = (component(color, 0) + green) & 0xff
    output[index] = (color & 0xff00ff00U) |
      (red.reinterpret_as_uint() << 16) |
      blue.reinterpret_as_uint()
  }
  output
}

///|
fn inverse_color_indexing(
  pixels : Array[UInt],
  packed_width : Int,
  height : Int,
  transform : Vp8lTransform,
) -> Array[UInt] {
  let width = transform.xsize
  let output = Array::make(width * height, 0U)
  let bits_per_index = 8 >> transform.bits
  let pixels_per_byte = 1 << transform.bits
  let index_mask = (1 << bits_per_index) - 1
  for y in 0..<height {
    for x in 0..<width {
      let packed = pixels[y * packed_width + x / pixels_per_byte]
      let green = component(packed, 8)
      let shift = x % pixels_per_byte * bits_per_index
      let index = (green >> shift) & index_mask
      if index < transform.palette_size {
        output[y * width + x] = transform.data[index]
      }
    }
  }
  output
}

///|
fn inverse_transforms(
  pixels : Array[UInt],
  width : Int,
  height : Int,
  transforms : Array[Vp8lTransform],
) -> Array[UInt] raise DecodeError {
  let mut current = pixels
  let mut current_width = width
  let mut index = transforms.length()
  while index > 0 {
    index = index - 1
    let transform = transforms[index]
    match transform.kind {
      Predictor =>
        current = inverse_predictor(current, current_width, height, transform)
      CrossColor =>
        current = inverse_cross_color(current, current_width, height, transform)
      SubtractGreen =>
        current = inverse_subtract_green(current, current_width, height)
      ColorIndexing => {
        current = inverse_color_indexing(
          current, current_width, height, transform,
        )
        current_width = transform.xsize
      }
    }
  }
  current
}

///|
fn decode_image_stream(
  reader : BitReader,
  width : Int,
  height : Int,
  allow_transforms : Bool,
  allow_meta : Bool,
) -> Array[UInt] raise DecodeError {
  let (transforms, decoded_width) = if allow_transforms {
    read_transforms(reader, width, height)
  } else {
    ([], width)
  }
  let cache = read_color_cache_info(reader)
  let selector = read_prefix_groups(
    reader,
    decoded_width,
    height,
    allow_meta,
    cache.size,
  )
  let pixels = decode_image_pixels(
    reader,
    decoded_width,
    height,
    cache,
    selector,
    distance_map(),
  )
  inverse_transforms(pixels, decoded_width, height, transforms)
}

///|
/// Decode a VP8L image stream that carries no five-byte header, taking
/// its dimensions from the caller. This is how an `ALPH` chunk stores a
/// compressed alpha plane.
fn decode_vp8l_stream(
  data : BytesView,
  width : Int,
  height : Int,
) -> Array[UInt] raise DecodeError {
  decode_image_stream(BitReader::new(data), width, height, true, true)
}

///|
/// Decode a standalone VP8L payload (beginning with its five-byte header).
/// The returned pixels are ARGB, after every level-zero transform has been
/// undone.
pub fn decode_vp8l(data : BytesView) -> Vp8lImage raise DecodeError {
  let reader = BitReader::new(data)
  let header = read_vp8l_header(reader)
  let pixels = decode_image_stream(
    reader,
    header.width,
    header.height,
    true,
    true,
  )
  { width: header.width, height: header.height, pixels, }
}
