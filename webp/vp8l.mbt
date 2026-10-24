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
  let mut index = 0
  let mut previous_nonzero = 8
  while index < max_symbol {
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
      if repeat > max_symbol - index {
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
fn decode_image_stream(
  reader : BitReader,
  width : Int,
  height : Int,
  allow_transforms : Bool,
  allow_meta : Bool,
) -> Array[UInt] raise DecodeError {
  if allow_transforms {
    while reader.read(1) == 1U {
      let transform_type = reader.read(2).reinterpret_as_int()
      raise DecodeError::UnsupportedVp8lTransform(transform_type)
    }
  }
  let cache = read_color_cache_info(reader)
  let selector = read_prefix_groups(
    reader,
    width,
    height,
    allow_meta,
    cache.size,
  )
  decode_image_pixels(reader, width, height, cache, selector, distance_map())
}

///|
/// Decode a standalone VP8L payload (beginning with its five-byte header).
/// The returned pixels are ARGB. Level-zero transforms are not supported
/// yet; a bitstream that uses one reports `UnsupportedVp8lTransform`.
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
