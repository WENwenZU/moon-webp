/// A decoder is a parser for hostile input, so the interesting question is
/// not whether valid files decode but whether broken ones always come back
/// as a `DecodeError`. A panic here fails the test, which makes both cases
/// below cheap regression nets for index arithmetic.

///|
/// Every sample, and every prefix of every sample.
fn robustness_samples() -> Array[Bytes] {
  [
    corpus_dot, corpus_row3, corpus_column7, corpus_odd7x5, corpus_palette16, corpus_gradient40x37,
    corpus_noise16, corpus_wide300, corpus_alpha12, corpus_lossy8,
  ]
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
      let _ = @webp.decode_webp(prefix).width catch { _ => 0 }
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
        let mutated = Bytes::makei(sample.length(), fn(index) {
          if index == position {
            (sample.at(index).to_int() ^ (1 << bit)).to_byte()
          } else {
            sample.at(index)
          }
        })
        let _ = @webp.decode_webp(mutated).width catch { _ => 0 }
      }
    }
  }
}
