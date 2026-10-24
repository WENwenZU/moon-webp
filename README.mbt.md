# moon-webp

A decoder for lossless WebP images in pure MoonBit: the VP8L bitstream,
the RIFF container around it, alpha channels, and animation frames. No
dependencies, no FFI, every backend. The end state is one entry point —
hand it a whole file, get back an ARGB image — with `dwebp` as the
cross-check reference on a corpus of real files.

The library is a single package, `webp`. RIFF parsing and the VP8L image
core — literals, LZ77 backward references, color cache, and meta prefix
groups — are in place. Transforms, the WebP file wrapper, and animation
are the remaining decoding layers.

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
