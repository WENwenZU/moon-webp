///|
/// The `Show` implementation is what a caller reaches for when it only
/// wants a log line, so it needs to name the variant and its payload.
test "renders a decode error as its variant name" {
  @test.assert_eq("\{@webp.DecodeError::UnexpectedEnd(3)}", "UnexpectedEnd(3)")
  @test.assert_eq(
    "\{@webp.DecodeError::InvalidAnimationHeader(4U)}",
    "InvalidAnimationHeader(4)",
  )
}
