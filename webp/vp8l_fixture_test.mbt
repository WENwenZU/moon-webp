///|
// These payloads were assembled independently from RFC 9649 and decoded
// by libwebp 1.6.0's dwebp. Expected ARGB values come from the RGBA bytes
// in dwebp's PAM output.
test "decodes a literal and backward-reference image" {
  let image = @webp.decode_vp8l(
    b"\x2f\x03\x40\x00\x10\xf0\xda\x20\x01\x00\x00\x00\x00\x74\xb3\x99\xcc\xff\x2f\xf2\x44\x23\x2a\x52\xc0\xd8\x31",
  )
  @test.assert_eq(image.width, 4)
  @test.assert_eq(image.height, 2)
  @test.assert_eq(image.pixels, [
    0x80110a22U, 0x80111422U, 0x80111e22U, 0x80112822U, 0x80110a22U, 0x80111422U,
    0x80111e22U, 0x80112822U,
  ])
}

///|
test "copies an overlapping backward reference pixel by pixel" {
  let image = @webp.decode_vp8l(
    b"\x2f\x00\x00\x01\x10\xf0\xda\x20\x01\x00\x00\x00\x00\x74\xb3\x99\xcc\xff\x2f\xf2\x44\x23\x2a\xd2\xff\x5c",
  )
  @test.assert_eq(image.width, 1)
  @test.assert_eq(image.height, 5)
  @test.assert_eq(image.pixels, [
    0xff110a22U, 0xff110a22U, 0xff110a22U, 0xff110a22U, 0xff110a22U,
  ])
}

///|
test "decodes a color-cache reference" {
  let image = @webp.decode_vp8l(
    b"\x2f\x01\x00\x00\x10\x0a\x00\x24\x99\x11\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x1b\x51\x91\xfe\x87",
  )
  @test.assert_eq(image.width, 2)
  @test.assert_eq(image.pixels, [0xff110a22U, 0xff110a22U])
}

///|
test "selects prefix groups through an entropy image" {
  let image = @webp.decode_vp8l(
    b"\x2f\x07\x00\x00\x10\x84\x09\x88\xe8\x7f\x58\x85\x46\x54\xa4\xff\xd1\x85\x46\x54\xa4\xff\x01",
  )
  @test.assert_eq(image.width, 8)
  @test.assert_eq(image.pixels, [
    0xff110a22U, 0xff110a22U, 0xff110a22U, 0xff110a22U, 0xff110b22U, 0xff110b22U,
    0xff110b22U, 0xff110b22U,
  ])
}
