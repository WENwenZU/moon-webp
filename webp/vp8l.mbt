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
pub struct BitReader {
  data : BytesView
  bit_position : Ref[Int]
}

///|
fn BitReader::new(data : BytesView) -> BitReader {
  { data, bit_position: Ref(0), }
}

///|
pub fn BitReader::offset(self : BitReader) -> Int {
  self.bit_position.val
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
/// Parse the VP8L signature, dimensions, alpha hint, and reserved version.
pub fn parse_vp8l_header(data : BytesView) -> Vp8lHeader raise DecodeError {
  let reader = BitReader::new(data)
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
/// A canonical prefix code, stored as per-length counts and symbols sorted
/// by (code length, symbol). A single-symbol code consumes no input bits.
pub struct PrefixCode {
  alphabet_size : Int
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
  { alphabet_size: lengths.length(), counts, symbols, single_symbol, }
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
        return {
          alphabet_size,
          counts,
          symbols: [first, first],
          single_symbol: -1,
        }
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
pub struct ColorCacheInfo {
  bits : Int
  size : Int
}

///|
pub fn read_color_cache_info(
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
pub struct PrefixCodeGroup {
  green : PrefixCode
  red : PrefixCode
  blue : PrefixCode
  alpha : PrefixCode
  distance : PrefixCode
}

///|
pub fn read_prefix_code_group(
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
pub struct MetaPrefixInfo {
  prefix_bits : Int
  image_width : Int
  image_height : Int
}

///|
pub fn MetaPrefixInfo::read(
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
pub fn MetaPrefixInfo::group_index(
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
pub fn meta_prefix_group_count(entropy : Array[UInt]) -> Int raise DecodeError {
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
