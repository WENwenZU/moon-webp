///|
test "parses a minimal WebP file" {
  // RIFF, declared payload 20, WEBP, one VP8L chunk of 8 bytes (even
  // size: no pad byte).
  let file = b"\x52\x49\x46\x46\x14\x00\x00\x00\x57\x45\x42\x50\x56\x50\x38\x4c\x08\x00\x00\x00\xde\xad\xbe\xef\xde\xad\xbe\xef"
  let riff = @webp.parse_riff(file)
  @test.assert_eq(riff.form_is(b"WEBP"), true)
  @test.assert_eq(riff.size, 20U)
  @test.assert_eq(riff.chunks.length(), 1)
  let chunk = riff.chunks[0]
  @test.assert_eq(chunk.id_is(b"VP8L"), true)
  @test.assert_eq(chunk.size, 8U)
  @test.assert_eq(chunk.payload.length(), 8)
  @test.assert_eq(chunk.payload.at(0).to_uint(), 222U)
  @test.assert_eq(chunk.payload.at(3).to_uint(), 239U)
}

///|
test "skips the pad byte after an odd-sized chunk" {
  // Two chunks: VP8L with 5 payload bytes (plus one pad), then ALPH
  // with 2. Declared payload: 4 (form) + 14 + 10 = 28.
  let file = b"\x52\x49\x46\x46\x1c\x00\x00\x00\x57\x45\x42\x50\x56\x50\x38\x4c\x05\x00\x00\x00\xaa\xbb\xcc\xdd\xee\x00\x41\x4c\x50\x48\x02\x00\x00\x00\xff\xff"
  let riff = @webp.parse_riff(file)
  @test.assert_eq(riff.chunks.length(), 2)
  let second = riff.chunks[1]
  @test.assert_eq(second.id_is(b"ALPH"), true)
  @test.assert_eq(second.size, 2U)
  @test.assert_eq(second.payload.at(0).to_uint(), 255U)
  @test.assert_eq(second.payload.at(1).to_uint(), 255U)
}

///|
test "rejects a buffer shorter than the header" {
  let err = @test.expect_error(() => @webp.parse_riff(b"\x52\x49"))
  @test.assert_eq(err, @webp.DecodeError::UnexpectedEnd(2))
}

///|
test "rejects a bad signature" {
  let err = @test.expect_error(() => {
    @webp.parse_riff(b"\x4e\x4f\x4e\x45\x00\x00\x00\x00\x57\x45\x42\x50")
  })
  @test.assert_eq(err, @webp.DecodeError::InvalidSignature)
}

///|
test "rejects a declared size past the end of the buffer" {
  // Declares 255 payload bytes in a 12-byte buffer, and the little-
  // endian read has to be right for the error to carry 255.
  let err = @test.expect_error(() => {
    @webp.parse_riff(b"\x52\x49\x46\x46\xff\x00\x00\x00\x57\x45\x42\x50")
  })
  @test.assert_eq(err, @webp.DecodeError::SizePastEnd(255))
}

///|
test "rejects a chunk header cut off by the declared end" {
  // Declared payload 8: the form type plus four bytes of a chunk
  // header, not enough for its eight header bytes.
  let file = b"\x52\x49\x46\x46\x08\x00\x00\x00\x57\x45\x42\x50\x56\x50\x38\x4c"
  let err = @test.expect_error(() => @webp.parse_riff(file))
  @test.assert_eq(err, @webp.DecodeError::ChunkHeaderOverrun(12))
}

///|
test "rejects a chunk payload cut off by the declared end" {
  // Declared payload 12, chunk declares 8 but only one byte follows.
  let file = b"\x52\x49\x46\x46\x0c\x00\x00\x00\x57\x45\x42\x50\x56\x50\x38\x4c\x08\x00\x00\x00\x00"
  let err = @test.expect_error(() => @webp.parse_riff(file))
  @test.assert_eq(err, @webp.DecodeError::ChunkPayloadOverrun(12))
}

///|
test "rejects a declared size whose top bit is set" {
  // 0xffffffff payload bytes reads back as -1 if the size is treated as a
  // signed integer, and -1 is smaller than any buffer.
  let err = @test.expect_error(() => {
    @webp.parse_riff(b"\x52\x49\x46\x46\xff\xff\xff\xff\x57\x45\x42\x50")
  })
  @test.assert_eq(err, @webp.DecodeError::SizePastEnd(0xffffffffU))
}

///|
test "rejects a chunk size whose top bit is set" {
  // Defined payload of four bytes, chunk claims 0xffffffff of them.
  let file = b"\x52\x49\x46\x46\x0c\x00\x00\x00\x57\x45\x42\x50\x56\x50\x38\x4c\xff\xff\xff\xff"
  let err = @test.expect_error(() => @webp.parse_riff(file))
  @test.assert_eq(err, @webp.DecodeError::ChunkPayloadOverrun(12))
}
