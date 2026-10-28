/// A decoder is a parser for hostile input, so the interesting question is
/// not whether valid files decode but whether broken ones always come back
/// as a `DecodeError`. A panic here fails the test, which makes the cases
/// below cheap regression nets for index arithmetic.
///
/// Four mutations, four different promises: a truncation must always be
/// rejected, a corrupted magic must never be guessed over, a flipped
/// header bit must either be rejected or leave the buffer consistent with
/// its own dimensions, and a flipped payload bit must not panic.
///
/// The corpora are small on purpose. Every prefix of every sample is
/// decoded, so the cost is quadratic in file size and the samples are
/// kept under a kilobyte.

///|
/// Every sample, and every prefix of every sample.
fn robustness_samples() -> Array[Bytes] {
  [
    corpus_dot, corpus_row3, corpus_column7, corpus_odd7x5, corpus_palette16, corpus_gradient40x37,
    corpus_noise16, corpus_wide300, corpus_alpha12, corpus_lossy8,
  ]
}

///|
/// One bit flipped, everything else untouched.
fn robustness_flip(sample : Bytes, position : Int, bit : Int) -> Bytes {
  Bytes::makei(sample.length(), fn(index) {
    if index == position {
      (sample.at(index).to_int() ^ (1 << bit)).to_byte()
    } else {
      sample.at(index)
    }
  })
}

///|
/// `None` when the bytes are rejected or decode to a self-consistent
/// image; otherwise a description of the mismatch, which is what a caller
/// would trip over downstream.
fn robustness_consistency(bytes : Bytes) -> String? {
  let image = @webp.decode_webp(bytes) catch { _ => return None }
  if image.pixels.length() == image.width * image.height {
    None
  } else {
    Some(
      "\{image.width}x\{image.height} announced, \{image.pixels.length()} pixels stored",
    )
  }
}

///|
/// A cut anywhere inside a file must end in a `DecodeError`, never in a
/// panic or a read past the end. Truncation leaves the header intact, so
/// the dimensions stay plausible while every payload length becomes
/// suspect.
test "every truncation of a sample fails cleanly" {
  for sample in robustness_samples() {
    for length in 0..<sample.length() {
      let prefix = sample.exact_view(start=0, end=length)
      let _ = @test.expect_error(() => @webp.decode_webp(prefix))
    }
  }
}

///|
/// The twelve bytes that spell `RIFF`, `WEBP`, and the image chunk name.
/// Any single bit of them wrong and the file is not a WebP at all, so a
/// successful decode would mean the signature check is too loose.
test "a corrupted signature is never guessed over" {
  for sample in robustness_samples() {
    for position in [0, 1, 2, 3, 8, 9, 10, 11, 12, 13, 14, 15] {
      for bit in 0..<8 {
        let mutated = robustness_flip(sample, position, bit)
        let _ = @test.expect_error(() => @webp.decode_webp(mutated))
      }
    }
  }
}

///|
/// The 25 bytes in front of the pixel data: RIFF magic, declared file
/// size, `WEBP` form type, the image chunk name and size, the VP8L
/// signature, then the 32-bit VP8L header carrying dimensions, the alpha
/// hint, and the reserved version.
///
/// Not every mutation is fatal — a version bit or the alpha hint can
/// change without making the file undecodable. What must hold is that a
/// decode which does succeed returns exactly the buffer its own width and
/// height promise, so nothing downstream can read past it.
test "survives single-bit mutations of the header" {
  for sample in robustness_samples() {
    let limit = if sample.length() < 25 { sample.length() } else { 25 }
    for position in 0..<limit {
      for bit in 0..<8 {
        let mutated = robustness_flip(sample, position, bit)
        match robustness_consistency(mutated) {
          Some(detail) =>
            @test.fail("header byte \{position}, bit \{bit}: \{detail}")
          None => ()
        }
      }
    }
  }
}

///|
/// Flip one bit at a time in the compressed payload. The header stays
/// intact, so the dimensions it announces remain the ones the file was
/// built with; everything after it is fair game. Only the first stretch of
/// the payload is mutated, because that is where the tables and transforms
/// live and where a wrong index would show up first.
test "survives single-bit mutations of the payload" {
  for sample in robustness_samples() {
    let end = if sample.length() < 89 { sample.length() } else { 89 }
    for position in 25..<end {
      for bit in 0..<8 {
        let mutated = robustness_flip(sample, position, bit)
        let _ = @webp.decode_webp(mutated).width catch { _ => 0 }
      }
    }
  }
}
