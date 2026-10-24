///|
test "parses the five-byte VP8L header" {
  let header = @webp.parse_vp8l_header(b"\x2f\x2b\xc1\x31\x10\xff")
  @test.assert_eq(header.width, 300)
  @test.assert_eq(header.height, 200)
  @test.assert_eq(header.alpha_is_used, true)
}

///|
test "parses the maximum VP8L dimensions" {
  let header = @webp.parse_vp8l_header(b"\x2f\xff\xff\xff\x0f")
  @test.assert_eq(header.width, 16384)
  @test.assert_eq(header.height, 16384)
  @test.assert_eq(header.alpha_is_used, false)
}

///|
test "rejects every truncated VP8L header prefix" {
  let header = b"\x2f\x2b\xc1\x31\x10"
  for length in 0..<5 {
    let err = @test.expect_error(() => {
      @webp.parse_vp8l_header(header.exact_view(start=0, end=length))
    })
    @test.assert_eq(err, @webp.DecodeError::UnexpectedEnd(length))
  }
}

///|
test "rejects a bad VP8L signature" {
  let err = @test.expect_error(() => {
    @webp.parse_vp8l_header(b"\x2e\x2b\xc1\x31\x10")
  })
  @test.assert_eq(err, @webp.DecodeError::InvalidVp8lSignature(0x2eU))
}

///|
test "rejects a nonzero VP8L version" {
  let err = @test.expect_error(() => {
    @webp.parse_vp8l_header(b"\x2f\x2b\xc1\x31\x30")
  })
  @test.assert_eq(err, @webp.DecodeError::UnsupportedVp8lVersion(1U))
}
