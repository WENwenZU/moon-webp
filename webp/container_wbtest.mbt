///|
// Row-level vectors for the alpha filter: the first row is already
// unfiltered and serves as the predictor for the second one.
test "undoes a vertical alpha row from the row above" {
  let row : Array[Byte] = [b'\x0a', b'\x0f', b'\x10', b'\x03', b'\x03', b'\x03']
  unfilter_alpha_row(2, row, 3, 3, Some(0))
  @test.assert_eq(row, [b'\x0a', b'\x0f', b'\x10', b'\x0d', b'\x12', b'\x13'])
}

///|
test "undoes a horizontal alpha row seeded from the pixel above" {
  let row : Array[Byte] = [b'\x0a', b'\x0f', b'\x10', b'\x03', b'\x03', b'\x03']
  unfilter_alpha_row(1, row, 3, 3, Some(0))
  @test.assert_eq(row, [b'\x0a', b'\x0f', b'\x10', b'\x0d', b'\x10', b'\x13'])
}

///|
test "undoes a gradient alpha row from three neighbors" {
  let row : Array[Byte] = [b'\x0a', b'\x0f', b'\x10', b'\x03', b'\x03', b'\x03']
  unfilter_alpha_row(3, row, 3, 3, Some(0))
  @test.assert_eq(row, [b'\x0a', b'\x0f', b'\x10', b'\x0d', b'\x15', b'\x19'])
}

///|
test "unfilters the first alpha row from the left" {
  for filter in [1, 2, 3] {
    let row : Array[Byte] = [b'\x0a', b'\x05', b'\x01']
    unfilter_alpha_row(filter, row, 0, 3, None)
    @test.assert_eq(row, [b'\x0a', b'\x0f', b'\x10'])
  }
}

///|
test "leaves an unfiltered alpha row alone" {
  let row : Array[Byte] = [b'\x0a', b'\x05', b'\x01']
  unfilter_alpha_row(0, row, 0, 3, None)
  @test.assert_eq(row, [b'\x0a', b'\x05', b'\x01'])
}

///|
test "copies an uncompressed alpha payload" {
  @test.assert_eq(
    decode_alpha_payload(b"\x00\x01\x02\x03\x04", 2, 2),
    b"\x01\x02\x03\x04",
  )
  @test.assert_eq(
    decode_alpha_payload(b"\x10\x01\x02\x03\x04", 2, 2),
    b"\x01\x02\x03\x04",
  )
}

///|
test "rejects a short alpha payload" {
  let err = @test.expect_error(() => decode_alpha_payload(b"", 2, 2))
  @test.assert_eq(err, DecodeError::AlphaPayloadTooShort)
  let err = @test.expect_error(() => decode_alpha_payload(b"\x00\x01\x02", 2, 2))
  @test.assert_eq(err, DecodeError::AlphaPayloadTooShort)
}

///|
test "rejects an alpha header with unknown bits" {
  let err = @test.expect_error(() => {
    decode_alpha_payload(b"\x40\x01\x02\x03\x04", 2, 2)
  })
  @test.assert_eq(err, DecodeError::InvalidAlphaHeader(0x40U))
  let err = @test.expect_error(() => {
    decode_alpha_payload(b"\x20\x01\x02\x03\x04", 2, 2)
  })
  @test.assert_eq(err, DecodeError::InvalidAlphaHeader(0x20U))
  let err = @test.expect_error(() => {
    decode_alpha_payload(b"\x02\x01\x02\x03\x04", 2, 2)
  })
  @test.assert_eq(err, DecodeError::InvalidAlphaHeader(0x02U))
}

///|
test "reads lossy dimensions from a VP8 keyframe header" {
  let (width, height) = parse_vp8_frame_header(
    b"\x10\x00\x00\x9d\x01\x2a\x0d\x00\x0b\x00",
  )
  @test.assert_eq(width, 13)
  @test.assert_eq(height, 11)
}

///|
test "rejects malformed VP8 keyframe headers" {
  let headers = [
    b"\x10\x00\x00\x9d\x01\x2a\x0d\x00\x0b", b"\x10\x00\x00\x9c\x01\x2a\x0d\x00\x0b\x00",
    b"\x11\x00\x00\x9d\x01\x2a\x0d\x00\x0b\x00", b"\x00\x00\x00\x9d\x01\x2a\x0d\x00\x0b\x00",
    b"\x18\x00\x00\x9d\x01\x2a\x0d\x00\x0b\x00", b"\x10\x00\x00\x9d\x01\x2a\x00\x00\x0b\x00",
    b"\x50\x01\x00\x9d\x01\x2a\x0d\x00\x0b\x00",
  ]
  for header in headers {
    let err = @test.expect_error(() => parse_vp8_frame_header(header))
    @test.assert_eq(err, DecodeError::InvalidVp8Header)
  }
}

///|
test "reads a 24-bit little-endian field" {
  @test.assert_eq(le_u24(b"\x01\x02\x03", 0), 0x030201)
  @test.assert_eq(le_u24(b"\xff\x34\x12\x00", 1), 0x001234)
}
