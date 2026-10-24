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
  /// The VP8L signature is not 0x2f.
  InvalidVp8lSignature(UInt)
  /// The reserved VP8L version is not zero.
  UnsupportedVp8lVersion(UInt)
  /// A bit read was negative or wider than 24 bits.
  InvalidBitCount(Int)
  /// A simple prefix code names a symbol outside its alphabet.
  InvalidPrefixSymbol(Int)
  /// Prefix code lengths do not describe a complete binary tree.
  InvalidPrefixTree
  /// A code-length repeat runs past the announced symbol limit.
  PrefixRepeatOverrun
  /// The color cache size parameter is outside the range 1..11.
  InvalidColorCacheBits(Int)
  /// An entropy image is empty or does not match its announced dimensions.
  InvalidEntropyImage
  /// A VP8L transform type appears more than once.
  DuplicateVp8lTransform(Int)
  /// A predictor image names a mode outside 0..13.
  InvalidPredictorMode(Int)
  /// A color cache symbol names an entry outside the allocated cache.
  InvalidColorCacheIndex(Int)
  /// A backward-reference distance is zero or reaches before the image.
  InvalidBackwardReference(Int)
  /// A backward-reference copy runs past the end of the image.
  BackwardReferenceOverrun(Int)
  /// A RIFF file uses a form type other than `WEBP`.
  InvalidRiffForm
  /// The first chunk is not a `VP8X`, `VP8L`, or `VP8 ` chunk.
  InvalidChunkOrder
  /// A `VP8X` chunk does not carry its fixed ten-byte payload (chunk size).
  InvalidVp8xChunk(UInt)
  /// The `VP8X` canvas area reaches the 2^32 pixel limit.
  CanvasTooLarge
  /// A `VP8 ` chunk does not start with a well-formed keyframe header.
  InvalidVp8Header
  /// No `VP8L` or `VP8 ` image chunk follows the header chunks.
  MissingImageChunk
  /// The `VP8X` canvas size disagrees with the image chunk.
  CanvasSizeMismatch
  /// The image payload is lossy VP8, which this decoder does not decode.
  UnsupportedLossyImage
  /// No `ALPH` chunk carries alpha for the requested image.
  MissingAlphaChunk
  /// An `ALPH` header byte names an unknown method or sets reserved bits.
  InvalidAlphaHeader(UInt)
  /// An `ALPH` payload is too short for its method and canvas size.
  AlphaPayloadTooShort
  /// A `VP8X` file is an animation, which `decode_webp` does not fold
  /// into a single image.
  AnimatedImage
  /// No `ANIM` chunk precedes the animation frames.
  MissingAnimationHeader
  /// An `ANIM` chunk is shorter than its six-byte payload (chunk size).
  InvalidAnimationHeader(UInt)
  /// The file carries no `ANMF` animation frame.
  MissingAnimationFrame
  /// An `ANMF` frame header or its rectangle is malformed.
  InvalidAnimationFrame
} derive(Eq, @debug.Debug)

///|
pub extend DecodeError with Eq::{not_equal, equal}

///|
pub extend DecodeError with @debug.Debug::{to_repr}
