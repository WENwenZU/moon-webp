///|
/// RIFF container parsing. WebP files are RIFF files, and this module
/// handles the container level: the `RIFF`/size header, the form
/// fourcc, and the chunk walk with its odd-payload pad byte. All
/// integers on the wire are little-endian.
///
/// Views are borrowed from the caller's buffer throughout: parsing
/// copies nothing.
pub struct RiffChunk {
  id : BytesView
  size : UInt
  payload : BytesView
} derive(@debug.Debug)

///|
pub extend RiffChunk with @debug.Debug::{to_repr}

///|
/// True when the chunk id spells `id`, e.g. `chunk.id_is(b"VP8L")`.
pub fn RiffChunk::id_is(self : RiffChunk, id : Bytes) -> Bool {
  has_id(self.id, 0, id)
}

///|
/// A parsed RIFF file: form type, declared payload size, and chunks.
pub struct RiffFile {
  form : BytesView
  /// Declared payload size from bytes 4..8: the file length minus the
  /// eight bytes of `RIFF` plus size.
  size : UInt
  chunks : Array[RiffChunk]
} derive(@debug.Debug)

///|
pub extend RiffFile with @debug.Debug::{to_repr}

///|
/// True when the form type spells `form`, e.g. `file.form_is(b"WEBP")`.
pub fn RiffFile::form_is(self : RiffFile, form : Bytes) -> Bool {
  has_id(self.form, 0, form)
}

///|
/// Parse a RIFF file from an in-memory buffer, walking chunks up to
/// the declared end. Each chunk is an id, a little-endian 32-bit
/// payload size, the payload, and one pad byte when that size is odd.
pub fn parse_riff(buf : BytesView) -> RiffFile raise DecodeError {
  if buf.length() < 12 {
    raise DecodeError::UnexpectedEnd(buf.length())
  }
  if !has_id(buf, 0, b"RIFF") {
    raise DecodeError::InvalidSignature
  }
  let size = le_u32(buf, 4)
  let declared = size.reinterpret_as_int()
  if declared > buf.length() - 8 {
    raise DecodeError::SizePastEnd(size)
  }
  let end = 8 + declared
  let chunks : Array[RiffChunk] = []
  let mut offset = 12
  while offset < end {
    if offset + 8 > end {
      raise DecodeError::ChunkHeaderOverrun(offset)
    }
    let csize = le_u32(buf, offset + 4)
    let csize_i = csize.reinterpret_as_int()
    let dstart = offset + 8
    if dstart + csize_i > end {
      raise DecodeError::ChunkPayloadOverrun(offset)
    }
    chunks.push({
      id: buf.exact_view(start=offset, end=offset + 4),
      size: csize,
      payload: buf.exact_view(start=dstart, end=dstart + csize_i),
    })
    // Next chunk starts after the payload and its pad byte, when the
    // payload size is odd.
    offset = dstart + csize_i + (csize & 1).reinterpret_as_int()
  }
  { form: buf.exact_view(start=8, end=12), size, chunks, }
}

///|
/// True when the four bytes at `at` spell `id`.
fn has_id(bv : BytesView, at : Int, id : Bytes) -> Bool {
  bv.length() >= at + 4 &&
  bv.at(at) == id[0] &&
  bv.at(at + 1) == id[1] &&
  bv.at(at + 2) == id[2] &&
  bv.at(at + 3) == id[3]
}

///|
/// Read a 32-bit little-endian unsigned integer at `at`. Bounds are
/// the caller's job.
fn le_u32(bv : BytesView, at : Int) -> UInt {
  bv.at(at).to_uint() |
  (bv.at(at + 1).to_uint() << 8) |
  (bv.at(at + 2).to_uint() << 16) |
  (bv.at(at + 3).to_uint() << 24)
}
