# moon-webp

A decoder for lossless WebP images in pure MoonBit: the VP8L bitstream,
the RIFF container around it, alpha channels, and animation frames. No
dependencies, no FFI, every backend. The end state is one entry point —
hand it a whole file, get back an ARGB image — with `dwebp` as the
cross-check reference on a corpus of real files.

The library is a single package, `webp`. RIFF parsing and the VP8L image
core are in place: literals, LZ77 backward references, color cache, meta
prefix groups, and the four level-zero transforms (predictor,
cross-color, subtract green, color indexing). The file wrapper decodes
both the simple format (`VP8L`) and the extended one (`VP8X` with
skipped metadata chunks), and reads the `ALPH` plane of lossy files,
including its four spatial filters. Animation is the remaining decoding
layer.

```moonbit
let image = @webp.decode_webp(bytes)   // whole file in, ARGB pixels out
let info = @webp.webp_info(bytes)      // canvas size and feature flags
let alpha = @webp.decode_alpha(bytes)  // ALPH plane of a lossy file
```

## Building

```bash
moon check --deny-warn
moon test
```

## References

- RFC 9649 — WebP Lossless Bitstream Format
- WebP Container Specification (Google)
- [libwebp](https://github.com/webmproject/libwebp) (BSD-3-Clause) —
  reference implementation and corpus

## License

Apache-2.0
