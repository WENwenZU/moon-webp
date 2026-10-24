///|
/// Decoding failures. Every public entry point that touches file bytes
/// raises one of these instead of panicking; malformed input is the
/// normal case for a decoder, not an exceptional one.
pub(all) suberror DecodeError {
  /// The buffer ends before the 12-byte RIFF header (given length).
  UnexpectedEnd(Int)
  /// The first four bytes are not `RIFF`.
  InvalidSignature
  /// The declared file size runs past the end of the buffer.
  SizePastEnd(UInt)
  /// A chunk header runs past the declared end (header offset).
  ChunkHeaderOverrun(Int)
  /// A chunk payload runs past the declared end (header offset).
  ChunkPayloadOverrun(Int)
} derive(Eq, @debug.Debug)

///|
pub extend DecodeError with Eq::{not_equal, equal}

///|
pub extend DecodeError with @debug.Debug::{to_repr}
