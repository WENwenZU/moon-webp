# moon-webp

A WebP decoder written in MoonBit. It reads the lossless `VP8L` bitstream,
the RIFF container around it, the alpha plane of lossy files, and animated
files, and hands back ARGB pixels. No dependencies, no FFI, no build
scripts: the same source runs on wasm, wasm-gc, JavaScript, and native.

```moonbit
let image = @webp.decode_webp(bytes)     // whole file in, ARGB pixels out
let info = @webp.webp_info(bytes)        // size and feature flags, no pixels
let alpha = @webp.decode_alpha(bytes)    // ALPH plane of a lossy file
let animation = @webp.decode_animation(bytes)  // composited frames
```

## What it decodes

| Layer | Coverage |
| --- | --- |
| `VP8L` bitstream | Huffman codes in five groups with meta groups and a color cache, LZ77 backward references, and all four level-zero transforms: predictor, cross-color, subtract green, color indexing |
| Simple container | `RIFF`/`WEBP` holding a single `VP8L` chunk |
| Extended container | `VP8X` canvas and feature flags, with `ICCP`/`EXIF`/`XMP ` metadata chunks walked and skipped |
| Alpha | the `ALPH` chunk of lossy files, raw and losslessly compressed, with none/horizontal/vertical/gradient filters |
| Animation | `ANIM` loop count and background, `ANMF` frame rectangles, durations, blending, and disposal |
| `VP8` lossy image | header only: `webp_info` reports its size, `decode_webp` returns `UnsupportedLossyImage` |

Pixels are packed ARGB: alpha in bits 31..24, then red, green, blue. An
animation frame is returned as the whole canvas already composited, so a
caller can display frames in order without doing any blending itself.

## Install

```bash
moon add WENwenZU/moon-webp
```

```moonbit
import {
  "WENwenZU/moon-webp/webp" @webp,
}
```

## Usage

```moonbit
fn describe(bytes : Bytes) -> Unit raise {
  let image = @webp.decode_webp(bytes)
  println("\{image.width} x \{image.height}, \{image.pixels.length()} pixels")
}
```

Every entry point raises `DecodeError` instead of panicking, so a decoder
fed untrusted bytes can decide what to do with a truncated file, a bad
Huffman code, or a frame that leaves the canvas:

```moonbit
let image = try {
  @webp.decode_webp(bytes)
} catch {
  err => {
    println("cannot decode: \{err}")
    return
  }
}
```

## Examples

Three runnable programs live under `examples/`. They embed their input, so
each one runs on any backend with no file system access:

```bash
moon run examples/info      # header facts and the errors the API raises
moon run examples/preview   # truecolor preview of two stills in the terminal
moon run examples/frames    # every composited animation frame, with checksums
```

`examples/preview` draws each pixel as a half block with 24-bit color, and
`examples/frames` shows what blending and disposal actually produce: the
frame checksums it prints match `anim_dump` from libwebp byte for byte.

## Testing

```bash
moon check --deny-warn
moon test
moon test --target js
moon test --target native   # needs a C compiler
```

The tests are self-contained: every fixture is embedded as a byte literal,
so `moon test` needs no network and no reference tools. The fixtures
themselves were produced with `cwebp` and `img2webp` from libwebp 1.6.0 and
verified against `dwebp` and `anim_dump` before being committed, pixel for
pixel. That comparison is what makes the decoder trustworthy: a golden file
that both implementations agree on is worth more than one only this decoder
has ever seen.

A corpus test keeps that comparison alive in CI by freezing `dwebp`'s
output as one digest per image: a single pixel, a single row, a single
column, odd dimensions, 300 pixels wide, a palette, noise, a gradient, and
the alpha plane of a lossy file. Two more tests cut every sample at every
length and flip every bit of the first payload bytes, so a damaged file has
to come back as a `DecodeError` rather than a panic.

Coverage includes the header and prefix-code tables, LZ77 references,
transforms, container layouts, alpha filters, animation compositing, and
the error paths of each layer.

## Scope

- Lossy `VP8` images are recognized but not decoded. Only their dimensions
  are read, which is enough to report on a file or to skip it.
- Metadata chunks (`ICCP`, `EXIF`, `XMP `) are skipped, not exposed.
- Gamma correction is not applied; pixels come back exactly as the
  bitstream stores them.

## References

- RFC 9649, *WebP Lossless Bitstream Format*
- *WebP Container Specification*, Google
- [libwebp](https://github.com/webmproject/libwebp) (BSD-3-Clause), the
  reference implementation, used to generate and check the test corpus

## License

Apache-2.0
