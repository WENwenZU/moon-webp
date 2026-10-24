///|
test "reads VP8L bits least-significant-bit first across bytes" {
  let reader = BitReader::new(b"\x6b\x01")
  @test.assert_eq(reader.read(3), 3U)
  @test.assert_eq(reader.read(5), 13U)
  @test.assert_eq(reader.read(1), 1U)
  @test.assert_eq(reader.bit_position.val, 9)
}

///|
test "reads zero bits without moving and rejects invalid widths" {
  let reader = BitReader::new(b"\xff")
  @test.assert_eq(reader.read(0), 0U)
  @test.assert_eq(reader.bit_position.val, 0)
  let negative = @test.expect_error(() => reader.read(-1))
  @test.assert_eq(negative, DecodeError::InvalidBitCount(-1))
  let wide = @test.expect_error(() => reader.read(25))
  @test.assert_eq(wide, DecodeError::InvalidBitCount(25))
}

///|
test "rejects a bit read past the input without moving" {
  let reader = BitReader::new(b"\xff")
  let err = @test.expect_error(() => reader.read(9))
  @test.assert_eq(err, DecodeError::UnexpectedEnd(1))
  @test.assert_eq(reader.bit_position.val, 0)
}

///|
test "decodes a hand-computed canonical prefix code" {
  // Lengths [1, 3, 3, 2] produce symbols 0/3/1/2 with codes
  // 0/10/110/111. The bytes contain symbols 2, 0, 1, 3.
  let code = PrefixCode::from_lengths([1, 3, 3, 2])
  let reader = BitReader::new(b"\xb7\x00")
  @test.assert_eq(code.read_symbol(reader), 2)
  @test.assert_eq(code.read_symbol(reader), 0)
  @test.assert_eq(code.read_symbol(reader), 1)
  @test.assert_eq(code.read_symbol(reader), 3)
  @test.assert_eq(reader.bit_position.val, 9)
}

///|
test "a single-symbol prefix code consumes no bits" {
  let code = PrefixCode::from_lengths([0, 1])
  let reader = BitReader::new(b"\xff")
  @test.assert_eq(code.read_symbol(reader), 1)
  @test.assert_eq(code.read_symbol(reader), 1)
  @test.assert_eq(reader.bit_position.val, 0)
}

///|
test "rejects empty oversubscribed and incomplete prefix trees" {
  let empty = @test.expect_error(() => PrefixCode::from_lengths([]))
  @test.assert_eq(empty, DecodeError::InvalidPrefixTree)
  let over = @test.expect_error(() => PrefixCode::from_lengths([1, 1, 1]))
  @test.assert_eq(over, DecodeError::InvalidPrefixTree)
  let under = @test.expect_error(() => PrefixCode::from_lengths([2, 2]))
  @test.assert_eq(under, DecodeError::InvalidPrefixTree)
}

///|
test "reads a simple two-symbol prefix code" {
  // Simple form, two 8-bit symbols 5 and 9, followed by code 1.
  let reader = BitReader::new(b"\x2f\x48\x08")
  let code = read_prefix_code(reader, 16)
  @test.assert_eq(reader.bit_position.val, 19)
  @test.assert_eq(code.read_symbol(reader), 9)
}

///|
test "accepts a duplicate simple symbol as a two-leaf tree" {
  // Both leaves name symbol 1, so decoding still consumes one bit.
  let reader = BitReader::new(b"\x1b\x00")
  let code = read_prefix_code(reader, 16)
  @test.assert_eq(reader.bit_position.val, 12)
  @test.assert_eq(code.read_symbol(reader), 1)
  @test.assert_eq(reader.bit_position.val, 13)
}

///|
test "reads a normal canonical prefix code" {
  // The code-length alphabet has lengths 1/2/2 for symbols 1/2/3.
  // It encodes target lengths [1, 2, 3, 3], then symbols 0/1/2/3.
  let reader = BitReader::new(b"\x04\x40\x24\x7a\xed")
  let code = read_prefix_code(reader, 4)
  @test.assert_eq(reader.bit_position.val, 31)
  @test.assert_eq(code.read_symbol(reader), 0)
  @test.assert_eq(code.read_symbol(reader), 1)
  @test.assert_eq(code.read_symbol(reader), 2)
  @test.assert_eq(code.read_symbol(reader), 3)
}

///|
test "expands code-length repeat 16" {
  // One literal 4 followed by repeats of 6, 6, and 3 gives sixteen
  // symbols of length four. The final 1111 code decodes symbol 15.
  let reader = BitReader::new(b"\x0a\x00\x80\x20\xfc\x79")
  let code = read_prefix_code(reader, 16)
  @test.assert_eq(code.read_symbol(reader), 15)
}

///|
test "expands code-length zero repeat 17" {
  // Three zeros, two one-bit lengths, then three more zeros.
  let reader = BitReader::new(b"\x20\x40\x04\x11")
  let code = read_prefix_code(reader, 8)
  @test.assert_eq(code.read_symbol(reader), 4)
}

///|
test "expands code-length zero repeat 18" {
  // Eleven zeros followed by two one-bit lengths.
  let reader = BitReader::new(b"\x00\x41\x04\x10")
  let code = read_prefix_code(reader, 13)
  @test.assert_eq(code.read_symbol(reader), 12)
}

///|
test "stops reading code lengths at max symbol" {
  // The single-symbol code-length code supplies two one-bit lengths,
  // and the trailing alphabet entries stay unused.
  let reader = BitReader::new(b"\x00\x40\x82")
  let code = read_prefix_code(reader, 4)
  @test.assert_eq(reader.bit_position.val, 23)
  @test.assert_eq(code.read_symbol(reader), 1)
  @test.assert_eq(reader.bit_position.val, 24)
}

///|
test "repeat 16 before a nonzero length defaults to eight" {
  // Forty-three repeats fill 256 symbols: 6 * 42 + 4.
  let reader = BitReader::new(
    b"\x0a\x00\x00\x20\xfe\xff\xff\xff\xff\xff\xff\xff\xff\xff\xbf\x7f",
  )
  let code = read_prefix_code(reader, 256)
  @test.assert_eq(reader.bit_position.val, 119)
  @test.assert_eq(code.read_symbol(reader), 255)
  @test.assert_eq(reader.bit_position.val, 127)
}

///|
test "rejects a symbol limit beyond the alphabet" {
  let reader = BitReader::new(b"\x04\x40\xa4\x18")
  let err = @test.expect_error(() => read_prefix_code(reader, 4))
  @test.assert_eq(err, DecodeError::InvalidPrefixSymbol(5))
}

///|
test "rejects a repeat past the announced symbol limit" {
  let reader = BitReader::new(b"\x0a\x00\x80\x20\x1c")
  let err = @test.expect_error(() => read_prefix_code(reader, 4))
  @test.assert_eq(err, DecodeError::PrefixRepeatOverrun)
}

///|
test "rejects a simple symbol outside the alphabet" {
  let reader = BitReader::new(b"\x2d\x00")
  let err = @test.expect_error(() => read_prefix_code(reader, 4))
  @test.assert_eq(err, DecodeError::InvalidPrefixSymbol(5))
}

///|
test "reads color cache size and validates its bit width" {
  let reader = BitReader::new(b"\x17")
  let cache = read_color_cache_info(reader)
  @test.assert_eq(cache.bits, 11)
  @test.assert_eq(cache.size, 2048)
  @test.assert_eq(reader.bit_position.val, 5)
  let zero = @test.expect_error(() => {
    read_color_cache_info(BitReader::new(b"\x01"))
  })
  @test.assert_eq(zero, DecodeError::InvalidColorCacheBits(0))
  let twelve = @test.expect_error(() => {
    read_color_cache_info(BitReader::new(b"\x19"))
  })
  @test.assert_eq(twelve, DecodeError::InvalidColorCacheBits(12))
}

///|
test "reads all five codes in a prefix group" {
  let reader = BitReader::new(b"\x3d\x28\x42\x13\xaa\xd0\x05")
  let group = read_prefix_code_group(reader, 2)
  @test.assert_eq(group.green.single_symbol, 7)
  @test.assert_eq(group.red.single_symbol, 8)
  @test.assert_eq(group.blue.single_symbol, 9)
  @test.assert_eq(group.alpha.single_symbol, 10)
  @test.assert_eq(group.distance.single_symbol, 11)
  @test.assert_eq(reader.bit_position.val, 55)
}

///|
test "maps length and distance prefix values" {
  let reader = BitReader::new(b"\xff\xff")
  @test.assert_eq(copy_value(reader, 0), 1)
  @test.assert_eq(copy_value(reader, 1), 2)
  @test.assert_eq(copy_value(reader, 2), 3)
  @test.assert_eq(copy_value(reader, 3), 4)
  @test.assert_eq(copy_value(reader, 4), 6)
  @test.assert_eq(copy_value(reader, 5), 8)
  @test.assert_eq(copy_value(reader, 23), 4096)
}

///|
test "maps the 120 neighborhood distance codes" {
  let offsets = distance_map()
  @test.assert_eq(offsets.length(), 120)
  @test.assert_eq(plane_distance(4, 1, offsets), 4)
  @test.assert_eq(plane_distance(4, 2, offsets), 1)
  @test.assert_eq(plane_distance(4, 3, offsets), 5)
  @test.assert_eq(plane_distance(4, 4, offsets), 3)
  @test.assert_eq(plane_distance(4, 120, offsets), 36)
  @test.assert_eq(plane_distance(4, 121, offsets), 1)
  @test.assert_eq(plane_distance(4, 124, offsets), 4)
}

///|
test "hashes ARGB colors into the color cache" {
  @test.assert_eq(color_cache_key(0xff110a22U, 2), 2)
  @test.assert_eq(color_cache_key(0xffaabbccU, 2), 3)
}

///|
fn test_symbol_code(
  alphabet_size : Int,
  symbol : Int,
) -> PrefixCode raise DecodeError {
  let lengths = Array::make(alphabet_size, 0)
  lengths[symbol] = 1
  PrefixCode::from_lengths(lengths)
}

///|
fn test_group(
  green_symbol : Int,
  cache_size : Int,
) -> PrefixCodeGroup raise DecodeError {
  {
    green: test_symbol_code(280 + cache_size, green_symbol),
    red: test_symbol_code(256, 0),
    blue: test_symbol_code(256, 0),
    alpha: test_symbol_code(256, 255),
    distance: test_symbol_code(40, 0),
  }
}

///|
test "rejects a backward reference before the start of the image" {
  let selector = { meta: None, entropy: [], groups: [test_group(256, 0)], }
  let err = @test.expect_error(() => {
    decode_image_pixels(
      BitReader::new(b""),
      1,
      1,
      { bits: 0, size: 0, },
      selector,
      distance_map(),
    )
  })
  @test.assert_eq(err, DecodeError::InvalidBackwardReference(1))
}

///|
test "rejects a backward reference past the image end" {
  let selector = { meta: None, entropy: [], groups: [test_group(259, 0)], }
  let err = @test.expect_error(() => {
    decode_image_pixels(
      BitReader::new(b""),
      1,
      1,
      { bits: 0, size: 0, },
      selector,
      distance_map(),
    )
  })
  @test.assert_eq(err, DecodeError::BackwardReferenceOverrun(4))
}

///|
test "rejects a color cache symbol without a cache" {
  let selector = {
    meta: None,
    entropy: [],
    groups: [
      {
        green: test_symbol_code(281, 280),
        red: test_symbol_code(256, 0),
        blue: test_symbol_code(256, 0),
        alpha: test_symbol_code(256, 255),
        distance: test_symbol_code(40, 0),
      },
    ],
  }
  let err = @test.expect_error(() => {
    decode_image_pixels(
      BitReader::new(b""),
      1,
      1,
      { bits: 0, size: 0, },
      selector,
      distance_map(),
    )
  })
  @test.assert_eq(err, DecodeError::InvalidColorCacheIndex(0))
}

///|
test "computes meta prefix dimensions and group mapping" {
  let reader = BitReader::new(b"\x05")
  let meta = MetaPrefixInfo::read(reader, 65, 33)
  match meta {
    None => fail("expected an entropy image")
    Some(info) => {
      @test.assert_eq(info.prefix_bits, 4)
      @test.assert_eq(info.image_width, 5)
      @test.assert_eq(info.image_height, 3)
      let entropy = Array::make(15, 0U)
      entropy[14] = 0x0300U
      @test.assert_eq(info.group_index(entropy, 64, 32), 3)
      @test.assert_eq(info.group_index(entropy, 0, 0), 0)
    }
  }
  @test.assert_eq(meta_prefix_group_count([0U, 0x100U, 0x200U]), 3)
}

///|
test "handles absent and malformed meta prefix images" {
  let absent = MetaPrefixInfo::read(BitReader::new(b"\x00"), 1, 1)
  match absent {
    None => ()
    Some(_) => fail("expected no entropy image")
  }
  let err = @test.expect_error(() => meta_prefix_group_count([]))
  @test.assert_eq(err, DecodeError::InvalidEntropyImage)
}

///|
test "predicts with every mode from the RFC table" {
  let left = 0xff112233U
  let top = 0xff445566U
  let top_left = 0xff778899U
  let top_right = 0xffaabbccU
  let expected = [
    0xff000000U, 0xff112233U, 0xff445566U, 0xffaabbccU, 0xff778899U, 0xff506172U,
    0xff445566U, 0xff2a3b4cU, 0xff5d6e7fU, 0xff778899U, 0xff5d6e7fU, 0xff112233U,
    0xff000000U, 0xff041526U,
  ]
  for mode in 0..<14 {
    @test.assert_eq(
      predict_pixel(mode, left, top, top_left, top_right),
      expected[mode],
    )
  }
  let err = @test.expect_error(() => {
    predict_pixel(14, left, top, top_left, top_right)
  })
  @test.assert_eq(err, DecodeError::InvalidPredictorMode(14))
}

///|
test "clamps and selects on saturated neighbors" {
  // Every channel of `left + top - top_left` wraps past 255 or below 0 here,
  // so the clamping predictors have to saturate instead of wrapping.
  let cases = [
    (0xff000000U, 0xffffffffU, 0xffffffffU),
    (0xff00ff00U, 0xff000000U, 0xffffffffU),
    (0x80f0f0f0U, 0x00101010U, 0xff202020U),
  ]
  let expected = [
    [0xff000000U, 0xff000000U, 0xff3f3f3fU],
    [0xff000000U, 0xff000000U, 0xff003f00U],
    [0x80f0f0f0U, 0x00e0e0e0U, 0x00b0b0b0U],
  ]
  for index in 0..<3 {
    let (left, top, top_left) = cases[index]
    @test.assert_eq(
      predict_pixel(11, left, top, top_left, top),
      expected[index][0],
    )
    @test.assert_eq(
      predict_pixel(12, left, top, top_left, top),
      expected[index][1],
    )
    @test.assert_eq(
      predict_pixel(13, left, top, top_left, top),
      expected[index][2],
    )
  }
}
