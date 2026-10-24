///|
// Animation fixtures. `anim_tool` comes straight from img2webp;
// `anim_mixed` and `anim_key` were assembled from lossless frame payloads
// so that every blend/dispose combination, a sub-rectangle, a disposed
// rectangle, and the key-frame shortcut are exercised. Expected frames are
// anim_dump 1.6.0 `-pam` output, already composited onto the canvas.

let anim_tool_file : Bytes = b"\x52\x49\x46\x46\x08\x01\x00\x00\x57\x45\x42\x50\x56\x50\x38\x58" +
  b"\x0a\x00\x00\x00\x02\x00\x00\x00\x09\x00\x00\x07\x00\x00\x41\x4e" +
  b"\x49\x4d\x06\x00\x00\x00\xff\xff\xff\xff\x02\x00\x41\x4e\x4d\x46" +
  b"\x3c\x00\x00\x00\x00\x00\x00\x00\x00\x00\x09\x00\x00\x07\x00\x00" +
  b"\x64\x00\x00\x02\x56\x50\x38\x4c\x24\x00\x00\x00\x2f\x09\xc0\x01" +
  b"\x00\xb9\x8c\xe8\x7f\xec\x22\x8a\xd0\xff\x30\x90\x49\xdb\x08\xa8" +
  b"\x86\xfa\x57\xda\x6f\x02\xc6\x54\xbc\xa1\x24\x26\xe0\xdc\x32\x02" +
  b"\x41\x4e\x4d\x46\x48\x00\x00\x00\x00\x00\x00\x00\x00\x00\x09\x00" +
  b"\x00\x07\x00\x00\x78\x00\x00\x00\x56\x50\x38\x4c\x2f\x00\x00\x00" +
  b"\x2f\x09\xc0\x01\x00\xb9\x8c\xe8\x7f\xec\x22\xa2\xff\x01\xc2\x6c" +
  b"\x23\x80\x31\x0c\x63\xfe\x74\xf7\x3b\x00\xb1\x60\x1a\x3a\x87\x10" +
  b"\x43\x04\x02\x94\xb1\x05\x85\x11\x62\x02\x7a\xf4\x2d\x4e\x00\x00" +
  b"\x41\x4e\x4d\x46\x48\x00\x00\x00\x00\x00\x00\x00\x00\x00\x09\x00" +
  b"\x00\x07\x00\x00\x50\x00\x00\x00\x56\x50\x38\x4c\x2f\x00\x00\x00" +
  b"\x2f\x09\xc0\x01\x00\xb9\x8c\xe8\x7f\xec\x22\xa2\xff\x01\xc2\x6c" +
  b"\x23\x80\x31\x4c\x70\xfe\x0a\xf7\x3b\x00\xb1\x60\x1a\x3a\x87\x90" +
  b"\x57\x04\xd9\xb6\x29\x82\x49\x6c\x7f\x4c\x40\x4b\xdf\xe2\x04\x00"

///|
let anim_tool_frames : Array[Array[UInt]] = [
  [
    0xff000000, 0xff170b25, 0xff2e164a, 0xff45216f, 0xff5c2c94, 0xff7337b9, 0xff8a42de,
    0xffa14d03, 0xffb85828, 0xffcf634d, 0xff071d0d, 0xff1e2832, 0xff353357, 0xff4c3e7c,
    0xff6349a1, 0xff7a54c6, 0xff915feb, 0xffa86a10, 0xffbf7535, 0xffd6805a, 0xff0e3a1a,
    0xff25453f, 0xff3c5064, 0xff535b89, 0xff6a66ae, 0xff8171d3, 0xff987cf8, 0xffaf871d,
    0xffc69242, 0xffdd9d67, 0xff155727, 0xff2c624c, 0xff436d71, 0xff5a7896, 0xff7183bb,
    0xff888ee0, 0xff9f9905, 0xffb6a42a, 0xffcdaf4f, 0xffe4ba74, 0xff1c7434, 0xff337f59,
    0xff4a8a7e, 0xff6195a3, 0xff78a0c8, 0xff8fabed, 0xffa6b612, 0xffbdc137, 0xffd4cc5c,
    0xffebd781, 0xff239141, 0xff3a9c66, 0xff51a78b, 0xff68b2b0, 0xff7fbdd5, 0xff96c8fa,
    0xffadd31f, 0xffc4de44, 0xffdbe969, 0xfff2f48e, 0xff2aae4e, 0xff41b973, 0xff58c498,
    0xff6fcfbd, 0xff86dae2, 0xff9de507, 0xffb4f02c, 0xffcbfb51, 0xffe20676, 0xfff9119b,
    0xff31cb5b, 0xff48d680, 0xff5fe1a5, 0xff76ecca, 0xff8df7ef, 0xffa40214, 0xffbb0d39,
    0xffd2185e, 0xffe92383, 0xff002ea8,
  ],
  [
    0xff293511, 0xff404036, 0xff574b5b, 0xff6e5680, 0xff8561a5, 0xff9c6cca, 0xffb377ef,
    0xffca8214, 0xffe18d39, 0xfff8985e, 0xff30521e, 0xff475d43, 0xff5e6868, 0xff75738d,
    0xff8c7eb2, 0xffa389d7, 0xffba94fc, 0xffd19f21, 0xffe8aa46, 0xffffb56b, 0xff376f2b,
    0xff4e7a50, 0xff658575, 0xff7c909a, 0xff939bbf, 0xffaaa6e4, 0xffc1b109, 0xffd8bc2e,
    0xffefc753, 0xff06d278, 0xff3e8c38, 0xff55975d, 0xff6ca282, 0xff83ada7, 0xff9ab8cc,
    0xffb1c3f1, 0xffc8ce16, 0xffdfd93b, 0xfff6e460, 0xff0def85, 0xff45a945, 0xff5cb46a,
    0xff73bf8f, 0xff8acab4, 0xffa1d5d9, 0xffb8e0fe, 0xffcfeb23, 0xffe6f648, 0xfffd016d,
    0xff140c92, 0xff4cc652, 0xff63d177, 0xff7adc9c, 0xff91e7c1, 0xffa8f2e6, 0xffbffd0b,
    0xffd60830, 0xffed1355, 0xff041e7a, 0xff1b299f, 0xff53e35f, 0xff6aee84, 0xff81f9a9,
    0xff9804ce, 0xffaf0ff3, 0xffc61a18, 0xffdd253d, 0xfff43062, 0xff0b3b87, 0xff2246ac,
    0xff5a006c, 0xff710b91, 0xff8816b6, 0xff9f21db, 0xffb62c00, 0xffcd3725, 0xffe4424a,
    0xfffb4d6f, 0xff125894, 0xff2963b9,
  ],
  [
    0xff526a22, 0xff697547, 0xff80806c, 0xff978b91, 0xffae96b6, 0xffc5a1db, 0xffdcac00,
    0xfff3b725, 0xff0ac24a, 0xff21cd6f, 0xff59872f, 0xff709254, 0xff879d79, 0xff9ea89e,
    0xffb5b3c3, 0xffccbee8, 0xffe3c90d, 0xfffad432, 0xff11df57, 0xff28ea7c, 0xff60a43c,
    0xff77af61, 0xff8eba86, 0xffa5c5ab, 0xffbcd0d0, 0xffd3dbf5, 0xffeae61a, 0xff01f13f,
    0xff18fc64, 0xff2f0789, 0xff67c149, 0xff7ecc6e, 0xff95d793, 0xfface2b8, 0xffc3eddd,
    0xffdaf802, 0xfff10327, 0xff080e4c, 0xff1f1971, 0xff362496, 0xff6ede56, 0xff85e97b,
    0xff9cf4a0, 0xffb3ffc5, 0xffca0aea, 0xffe1150f, 0xfff82034, 0xff0f2b59, 0xff26367e,
    0xff3d41a3, 0xff75fb63, 0xff8c0688, 0xffa311ad, 0xffba1cd2, 0xffd127f7, 0xffe8321c,
    0xffff3d41, 0xff164866, 0xff2d538b, 0xff445eb0, 0xff7c1870, 0xff932395, 0xffaa2eba,
    0xffc139df, 0xffd84404, 0xffef4f29, 0xff065a4e, 0xff1d6573, 0xff347098, 0xff4b7bbd,
    0xff83357d, 0xff9a40a2, 0xffb14bc7, 0xffc856ec, 0xffdf6111, 0xfff66c36, 0xff0d775b,
    0xff248280, 0xff3b8da5, 0xff5298ca,
  ],
]

///|
let anim_tool_loop : Int = 2

///|
let anim_tool_background : UInt = 0xffffffff

///|
let anim_tool_durations : Array[Int] = [100, 120, 80]

///|
let anim_mixed_file : Bytes = b"\x52\x49\x46\x46\x32\x02\x00\x00\x57\x45\x42\x50\x56\x50\x38\x58" +
  b"\x0a\x00\x00\x00\x12\x00\x00\x00\x09\x00\x00\x07\x00\x00\x41\x4e" +
  b"\x49\x4d\x06\x00\x00\x00\x30\x20\x10\xff\x03\x00\x41\x4e\x4d\x46" +
  b"\x48\x00\x00\x00\x00\x00\x00\x00\x00\x00\x09\x00\x00\x07\x00\x00" +
  b"\x64\x00\x00\x00\x56\x50\x38\x4c\x2f\x00\x00\x00\x2f\x09\xc0\x01" +
  b"\x00\xb9\x8c\xe8\x7f\xec\x22\xa2\xff\x01\xc2\x6c\x23\x80\x31\x0c" +
  b"\x63\xfe\x74\xf7\x3b\x00\xb1\x60\x1a\x3a\x87\x10\x43\x04\x02\x94" +
  b"\xb1\x05\x85\x11\x62\x02\x7a\xf4\x2d\x4e\x00\x00\x41\x4e\x4d\x46" +
  b"\x7c\x00\x00\x00\x02\x00\x00\x01\x00\x00\x03\x00\x00\x02\x00\x00" +
  b"\x32\x00\x00\x00\x56\x50\x38\x4c\x64\x00\x00\x00\x2f\x03\x80\x00" +
  b"\x10\x5f\x60\x96\x91\x24\x80\x63\x98\xee\xe9\x1e\xf4\x45\xbe\x3f" +
  b"\x1e\x93\x8d\x24\xe1\xe8\xd9\xf5\xf5\xfd\xc3\xd7\xf0\xf6\xa6\x16" +
  b"\x92\x24\x88\x60\xf2\x8d\x9f\xf3\x57\x39\x8a\x13\x38\x01\xb5\x91" +
  b"\x6c\x50\x0f\x4d\xc9\xc4\xaf\x27\x9f\xb6\x84\x3a\x13\x3b\x36\x48" +
  b"\x60\xa3\xfd\xff\x4b\x27\x80\xe0\x8d\x1e\xf4\xee\x66\x76\x07\x04" +
  b"\x01\x24\x4c\x19\x44\xb7\xc2\x04\x0b\x4c\x1b\xd1\xff\x70\xe4\x05" +
  b"\x41\x4e\x4d\x46\x40\x00\x00\x00\x00\x00\x00\x00\x00\x00\x04\x00" +
  b"\x00\x03\x00\x00\x46\x00\x00\x03\x56\x50\x38\x4c\x27\x00\x00\x00" +
  b"\x2f\x04\xc0\x00\x00\xb9\x8c\xe8\x7f\xec\xca\x1f\xd1\xff\x00\x41" +
  b"\xb6\x0d\x40\x19\xc6\x7e\xdc\x2b\x88\x05\x93\x33\x84\xc1\x26\xff" +
  b"\x88\x93\x88\x9d\x24\xcb\x03\x00\x41\x4e\x4d\x46\x72\x00\x00\x00" +
  b"\x03\x00\x00\x02\x00\x00\x03\x00\x00\x02\x00\x00\x1e\x00\x00\x00" +
  b"\x56\x50\x38\x4c\x59\x00\x00\x00\x2f\x03\x80\x00\x10\x5f\x40\x16" +
  b"\x60\x02\xd0\xb7\x3f\x9c\xfc\x21\xc6\x90\x0b\x91\x00\x49\x74\x82" +
  b"\x0b\xfc\xbf\xcb\x46\xa5\x91\x05\x98\x10\x84\x11\x47\xea\x79\x24" +
  b"\xd0\x3f\x01\x03\x69\xdb\x50\x66\x6e\x92\xe6\xec\x16\xae\xaa\x04" +
  b"\x14\x45\x38\x8d\xf2\x4f\x45\x38\xca\x2b\x97\x9a\xd4\xdd\x32\x10" +
  b"\x64\xdb\x24\xc3\x18\xd0\x15\xae\x76\x8f\xcb\x46\xf4\x3f\x66\xc9" +
  b"\x01\x00\x41\x4e\x4d\x46\x70\x00\x00\x00\x00\x00\x00\x00\x00\x00" +
  b"\x09\x00\x00\x07\x00\x00\x14\x00\x00\x00\x56\x50\x38\x4c\x58\x00" +
  b"\x00\x00\x2f\x09\xc0\x01\x10\xb9\x8c\xe8\x7f\xec\x22\xa2\xff\x01" +
  b"\x45\x6d\x1b\x49\xef\x91\x31\x94\x3f\xd2\x39\x76\x11\x88\x05\x93" +
  b"\x33\x84\xf9\x03\xe5\x24\x10\x48\x43\x04\x63\x84\xb4\xd9\xb6\x4d" +
  b"\x94\x3e\xd5\xa9\xc0\xc8\x57\x88\xcf\xd5\xa6\x6d\xc0\xac\x76\xca" +
  b"\x1f\xf5\x8f\x85\x01\x80\x10\x34\xc0\xa6\xae\x1d\xc0\x20\xa5\x76" +
  b"\x00\xa0\x54\xa3\x41\x43\xa9\xf9\x85\xd1"

///|
let anim_mixed_frames : Array[Array[UInt]] = [
  [
    0xff293511, 0xff404036, 0xff574b5b, 0xff6e5680, 0xff8561a5, 0xff9c6cca, 0xffb377ef,
    0xffca8214, 0xffe18d39, 0xfff8985e, 0xff30521e, 0xff475d43, 0xff5e6868, 0xff75738d,
    0xff8c7eb2, 0xffa389d7, 0xffba94fc, 0xffd19f21, 0xffe8aa46, 0xffffb56b, 0xff376f2b,
    0xff4e7a50, 0xff658575, 0xff7c909a, 0xff939bbf, 0xffaaa6e4, 0xffc1b109, 0xffd8bc2e,
    0xffefc753, 0xff06d278, 0xff3e8c38, 0xff55975d, 0xff6ca282, 0xff83ada7, 0xff9ab8cc,
    0xffb1c3f1, 0xffc8ce16, 0xffdfd93b, 0xfff6e460, 0xff0def85, 0xff45a945, 0xff5cb46a,
    0xff73bf8f, 0xff8acab4, 0xffa1d5d9, 0xffb8e0fe, 0xffcfeb23, 0xffe6f648, 0xfffd016d,
    0xff140c92, 0xff4cc652, 0xff63d177, 0xff7adc9c, 0xff91e7c1, 0xffa8f2e6, 0xffbffd0b,
    0xffd60830, 0xffed1355, 0xff041e7a, 0xff1b299f, 0xff53e35f, 0xff6aee84, 0xff81f9a9,
    0xff9804ce, 0xffaf0ff3, 0xffc61a18, 0xffdd253d, 0xfff43062, 0xff0b3b87, 0xff2246ac,
    0xff5a006c, 0xff710b91, 0xff8816b6, 0xff9f21db, 0xffb62c00, 0xffcd3725, 0xffe4424a,
    0xfffb4d6f, 0xff125894, 0xff2963b9,
  ],
  [
    0xff293511, 0xff404036, 0xff574b5b, 0xff6e5680, 0xff8561a5, 0xff9c6cca, 0xffb377ef,
    0xffca8214, 0xffe18d39, 0xfff8985e, 0xff30521e, 0xff475d43, 0xff5e6868, 0xff75738d,
    0xff8c7eb2, 0xffa389d7, 0xffba94fc, 0xffd19f21, 0xffe8aa46, 0xffffb56b, 0xff376f2b,
    0xff4e7a50, 0xff658575, 0xff7c909a, 0xff929abd, 0xff9999bc, 0xffa0983a, 0xffb7a35f,
    0xffefc753, 0xff06d278, 0xff3e8c38, 0xff55975d, 0xff6ca282, 0xff83ada7, 0xff799f7d,
    0xff90aaa2, 0xff95a763, 0xff9ea89e, 0xfff6e460, 0xff0def85, 0xff45a945, 0xff5cb46a,
    0xff73bf8f, 0xff8acab4, 0xff6eae5d, 0xff77af61, 0xffcfeb23, 0xffe5f548, 0xfffd016d,
    0xff140c92, 0xff4cc652, 0xff63d177, 0xff7adc9c, 0xff91e7c1, 0xffa8f2e6, 0xffbffd0b,
    0xffd60830, 0xffed1355, 0xff041e7a, 0xff1b299f, 0xff53e35f, 0xff6aee84, 0xff81f9a9,
    0xff9804ce, 0xffaf0ff3, 0xffc61a18, 0xffdd253d, 0xfff43062, 0xff0b3b87, 0xff2246ac,
    0xff5a006c, 0xff710b91, 0xff8816b6, 0xff9f21db, 0xffb62c00, 0xffcd3725, 0xffe4424a,
    0xfffb4d6f, 0xff125894, 0xff2963b9,
  ],
  [
    0xff7b9f33, 0xff92aa58, 0xffa9b57d, 0xffc0c0a2, 0xffd7cbc7, 0xff9c6cca, 0xffb377ef,
    0xffca8214, 0xffe18d39, 0xfff8985e, 0xff82bc40, 0xff99c765, 0xffb0d28a, 0xffc7ddaf,
    0xffdee8d4, 0xffa389d7, 0xffba94fc, 0xffd19f21, 0xffe8aa46, 0xffffb56b, 0xff89d94d,
    0xffa0e472, 0xffb7ef97, 0xffcefabc, 0xffe505e1, 0xff9999bc, 0xffa0983a, 0xffb7a35f,
    0xffefc753, 0xff06d278, 0xff90f65a, 0xffa7017f, 0xffbe0ca4, 0xffd517c9, 0xffec22ee,
    0xff90aaa2, 0xff95a763, 0xff9ea89e, 0xfff6e460, 0xff0def85, 0xff45a945, 0xff5cb46a,
    0xff73bf8f, 0xff8acab4, 0xff6eae5d, 0xff77af61, 0xffcfeb23, 0xffe5f548, 0xfffd016d,
    0xff140c92, 0xff4cc652, 0xff63d177, 0xff7adc9c, 0xff91e7c1, 0xffa8f2e6, 0xffbffd0b,
    0xffd60830, 0xffed1355, 0xff041e7a, 0xff1b299f, 0xff53e35f, 0xff6aee84, 0xff81f9a9,
    0xff9804ce, 0xffaf0ff3, 0xffc61a18, 0xffdd253d, 0xfff43062, 0xff0b3b87, 0xff2246ac,
    0xff5a006c, 0xff710b91, 0xff8816b6, 0xff9f21db, 0xffb62c00, 0xffcd3725, 0xffe4424a,
    0xfffb4d6f, 0xff125894, 0xff2963b9,
  ],
  [
    0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0xff9c6cca, 0xffb377ef,
    0xffca8214, 0xffe18d39, 0xfff8985e, 0x00000000, 0x00000000, 0x00000000, 0x00000000,
    0x00000000, 0xffa389d7, 0xffba94fc, 0xffd19f21, 0xffe8aa46, 0xffffb56b, 0x00000000,
    0x00000000, 0x00000000, 0x00000000, 0x00000000, 0xff9999bc, 0xffa0983a, 0xffb7a35f,
    0xffefc753, 0xff06d278, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000,
    0xff90aaa2, 0xff95a763, 0xff9ea89e, 0xfff6e460, 0xff0def85, 0xff45a945, 0xff5cb46a,
    0xff73bf8f, 0xff8acab4, 0xff6eae5d, 0xff77af61, 0xffb9df33, 0xffcfe958, 0xffdbb786,
    0xffe9f5b3, 0xff4cc652, 0xff63d177, 0xff7adc9c, 0xff91e7c1, 0xffa8f2e6, 0xffbffd0b,
    0xffb4be49, 0xffc2fc76, 0xff041e7a, 0xff1b289f, 0xff53e35f, 0xff6aee84, 0xff81f9a9,
    0xff9804ce, 0xffaf0ff3, 0xffc61a18, 0xffdd253d, 0xfff32f62, 0xff0d3a87, 0xff5740b4,
    0xff5a006c, 0xff710b91, 0xff8816b6, 0xff9f21db, 0xffb62c00, 0xffcd3725, 0xffe4424a,
    0xfffb4d6f, 0xff125894, 0xff2963b9,
  ],
  [
    0x80cd0955, 0xc8e31379, 0xfffb1f9f, 0x00000000, 0x012935e9, 0xff9a6bc7, 0xff9b6bbf,
    0xff9c6c35, 0xffb2765b, 0xffaf7593, 0xffd42662, 0x00000000, 0x01023cac, 0x031846d0,
    0x403052f6, 0xff757379, 0xff8b7d9d, 0xff887c56, 0xff8c7e8a, 0xffffb56b, 0x01db436f,
    0x03f14d93, 0x400959b9, 0x7f1f63dd, 0x80376f03, 0xff5e8047, 0xff65854d, 0xffb7a35f,
    0xffeec653, 0xff07d178, 0x40e2607c, 0x7ff86aa0, 0x801076c6, 0xc82680ea, 0xff3e8c10,
    0xff90aaa2, 0xff94a662, 0xff9da89d, 0xffded871, 0xff5ed9a6, 0xff979267, 0xff13919f,
    0xff1793d3, 0xff8acab4, 0xff6dad5c, 0xff76af60, 0xffa7d640, 0xffacd971, 0xffbdc69b,
    0xffc2e4ce, 0xfff09a96, 0xff63d177, 0xff79db9c, 0xff8fe6be, 0xff90e6b6, 0xff91e72c,
    0xff96cd5e, 0xff9beb91, 0xffa8f2be, 0xff1b289f, 0xff53e25f, 0xff68ed84, 0xff69edba,
    0xff6a6d70, 0xff807994, 0xff7dc04d, 0xff81f981, 0xfff32f62, 0xff0d3987, 0xff583fb4,
    0xff83357d, 0xff4374b2, 0xff5980d8, 0xff56c747, 0xff5a0044, 0xffcd3725, 0xffe3414a,
    0xfff94c6f, 0xff3b4ca5, 0xff7a4dda,
  ],
]

///|
let anim_mixed_loop : Int = 3

///|
let anim_mixed_background : UInt = 0xff102030

///|
let anim_mixed_durations : Array[Int] = [100, 50, 70, 30, 20]

///|
let anim_key_file : Bytes = b"\x52\x49\x46\x46\x3e\x01\x00\x00\x57\x45\x42\x50\x56\x50\x38\x58" +
  b"\x0a\x00\x00\x00\x12\x00\x00\x00\x09\x00\x00\x07\x00\x00\x41\x4e" +
  b"\x49\x4d\x06\x00\x00\x00\xff\xff\xff\xff\x00\x00\x41\x4e\x4d\x46" +
  b"\x48\x00\x00\x00\x00\x00\x00\x00\x00\x00\x09\x00\x00\x07\x00\x00" +
  b"\x5a\x00\x00\x01\x56\x50\x38\x4c\x2f\x00\x00\x00\x2f\x09\xc0\x01" +
  b"\x00\xb9\x8c\xe8\x7f\xec\x22\xa2\xff\x01\xc2\x6c\x23\x80\x31\x4c" +
  b"\x65\xfe\x62\xf7\x3b\x00\x21\x41\x12\x99\xe0\xff\x93\x66\x81\x40" +
  b"\x1a\x22\x08\x63\xb5\x63\x02\x7a\x6a\xcb\x09\x00\x41\x4e\x4d\x46" +
  b"\x76\x00\x00\x00\x02\x00\x00\x01\x00\x00\x03\x00\x00\x02\x00\x00" +
  b"\x3c\x00\x00\x00\x56\x50\x38\x4c\x5d\x00\x00\x00\x2f\x03\x80\x00" +
  b"\x10\x5f\x60\xa4\x6d\x24\x01\xcf\x26\xe7\xfd\xe3\x57\xf0\xac\xa6" +
  b"\x8c\xb4\x8d\xe4\xe0\xe9\xd3\xd7\xf8\xca\x47\xcb\x8c\xb4\x8d\xf4" +
  b"\x3a\x9e\x3f\x7f\xff\x8a\xc6\x6b\xc0\x6c\xdb\x26\x6a\x1f\xab\xfa" +
  b"\x5b\x7f\x62\x85\x8d\xa7\x40\x71\x3f\x8b\xaa\x80\xc6\x54\xc4\x55" +
  b"\xc0\xef\xac\x67\x4f\x7f\x1f\x90\x49\xdb\x40\x2d\x54\xdc\x2c\xcc" +
  b"\xda\xfe\x89\x8d\xe8\x7f\xf4\x71\x00\x00\x41\x4e\x4d\x46\x44\x00" +
  b"\x00\x00\x00\x00\x00\x00\x00\x00\x04\x00\x00\x03\x00\x00\x28\x00" +
  b"\x00\x02\x56\x50\x38\x4c\x2b\x00\x00\x00\x2f\x04\xc0\x00\x00\xb9" +
  b"\x8c\xe8\x7f\xec\x22\xa2\xff\x01\x82\x6c\x1b\x80\x32\xcc\xff\xa6" +
  b"\x57\x10\x0b\xa6\xa1\x33\x84\x29\x25\x10\x48\x08\xc6\xc8\x75\xec" +
  b"\x88\x3d\x00\x54\x0f\x00"

///|
let anim_key_frames : Array[Array[UInt]] = [
  [
    0xfff63e66, 0xff0d498b, 0xff2454b0, 0xff3b5fd5, 0xff526afa, 0xff69751f, 0xff808044,
    0xff978b69, 0xffae968e, 0xffc5a1b3, 0xfffd5b73, 0xff146698, 0xff2b71bd, 0xff427ce2,
    0xff598707, 0xff70922c, 0xff879d51, 0xff9ea876, 0xffb5b39b, 0xffccbec0, 0xff047880,
    0xff1b83a5, 0xff328eca, 0xff4999ef, 0xff60a414, 0xff77af39, 0xff8eba5e, 0xffa5c583,
    0xffbcd0a8, 0xffd3dbcd, 0xff0b958d, 0xff22a0b2, 0xff39abd7, 0xff50b6fc, 0xff67c121,
    0xff7ecc46, 0xff95d76b, 0xfface290, 0xffc3edb5, 0xffdaf8da, 0xff12b29a, 0xff29bdbf,
    0xff40c8e4, 0xff57d309, 0xff6ede2e, 0xff85e953, 0xff9cf478, 0xffb3ff9d, 0xffca0ac2,
    0xffe115e7, 0xff19cfa7, 0xff30dacc, 0xff47e5f1, 0xff5ef016, 0xff75fb3b, 0xff8c0660,
    0xffa31185, 0xffba1caa, 0xffd127cf, 0xffe832f4, 0xff20ecb4, 0xff37f7d9, 0xff4e02fe,
    0xff650d23, 0xff7c1848, 0xff93236d, 0xffaa2e92, 0xffc139b7, 0xffd844dc, 0xffef4f01,
    0xff2709c1, 0xff3e14e6, 0xff551f0b, 0xff6c2a30, 0xff833555, 0xff9a407a, 0xffb14b9f,
    0xffc856c4, 0xffdf61e9, 0xfff66c0e,
  ],
  [
    0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000,
    0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000,
    0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000,
    0x00000000, 0x00000000, 0x00000000, 0xff1f7377, 0x00000000, 0x014d89c1, 0x036494e6,
    0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x01269084,
    0x033d9ba9, 0x4054a6ce, 0x7f6bb1f3, 0x00000000, 0x00000000, 0x00000000, 0x00000000,
    0x00000000, 0x00000000, 0x402dad91, 0x7f44b8b6, 0x805bc3db, 0xc872ce00, 0x00000000,
    0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000,
    0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000,
    0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000,
    0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000,
    0x00000000, 0x00000000, 0x00000000,
  ],
  [
    0xff48a888, 0xff5fb3ad, 0xff76bed2, 0xff8dc9f7, 0xffa4d41c, 0x00000000, 0x00000000,
    0x00000000, 0x00000000, 0x00000000, 0xff4fc595, 0xff66d0ba, 0xff7ddbdf, 0xff94e604,
    0xffabf129, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0xff56e2a2,
    0xff6dedc7, 0xff84f8ec, 0xff9b0311, 0xffb20e36, 0x00000000, 0x014d89c1, 0x036494e6,
    0x00000000, 0x00000000, 0xff5dffaf, 0xff740ad4, 0xff8b15f9, 0xffa2201e, 0xffb92b43,
    0x033d9ba9, 0x4054a6ce, 0x7f6bb1f3, 0x00000000, 0x00000000, 0x00000000, 0x00000000,
    0x00000000, 0x00000000, 0x402dad91, 0x7f44b8b6, 0x805bc3db, 0xc872ce00, 0x00000000,
    0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000,
    0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000,
    0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000,
    0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000,
    0x00000000, 0x00000000, 0x00000000,
  ],
]

///|
let anim_key_loop : Int = 0

///|
let anim_key_background : UInt = 0xffffffff

///|
let anim_key_durations : Array[Int] = [90, 60, 40]

///|
let anim_lossy_file : Bytes = b"\x52\x49\x46\x46\x38\x01\x00\x00\x57\x45\x42\x50\x56\x50\x38\x58" +
  b"\x0a\x00\x00\x00\x02\x00\x00\x00\x09\x00\x00\x07\x00\x00\x41\x4e" +
  b"\x49\x4d\x06\x00\x00\x00\xff\xff\xff\xff\x00\x00\x41\x4e\x4d\x46" +
  b"\x7c\x00\x00\x00\x00\x00\x00\x00\x00\x00\x09\x00\x00\x07\x00\x00" +
  b"\x64\x00\x00\x02\x56\x50\x38\x20\x64\x00\x00\x00\xd0\x01\x00\x9d" +
  b"\x01\x2a\x0a\x00\x08\x00\x02\x80\x42\x25\xb0\x02\x74\x00\xf2\x82" +
  b"\x18\x75\x08\x00\xfe\xf5\xfc\xa7\x95\xc4\x49\xbb\x99\x2e\x72\x40" +
  b"\x4a\x8b\x13\xa4\x86\x4e\x58\xe5\x00\xdd\xbe\x09\xfd\x2f\xa7\x61" +
  b"\xe0\x4c\xc0\x57\xc5\x59\x33\xb4\xa5\x85\x3f\x5d\xd0\x64\x94\xb9" +
  b"\xa3\xdf\xff\xb1\xc9\x96\x6f\x34\x24\x3c\x49\xfb\xb1\x1a\xb3\xc3" +
  b"\x8e\x07\xe4\x09\xff\x83\x92\x4d\xff\xfe\x3c\x39\xbc\x00\x00\x00" +
  b"\x41\x4e\x4d\x46\x88\x00\x00\x00\x00\x00\x00\x00\x00\x00\x09\x00" +
  b"\x00\x07\x00\x00\x64\x00\x00\x00\x56\x50\x38\x20\x70\x00\x00\x00" +
  b"\x34\x02\x00\x9d\x01\x2a\x0a\x00\x08\x00\x00\x00\x42\x25\xb0\x02" +
  b"\x74\x30\x40\x01\x8b\x0f\xee\x14\x25\x80\x00\xfe\xad\x9d\x36\xe6" +
  b"\x1a\xfa\x22\x42\xfd\x30\x57\x6e\x3a\xca\x08\x9e\x3e\x12\xae\xce" +
  b"\x05\xb8\xf0\x83\xce\x54\x1a\xb0\x66\xf6\x0d\x93\x3b\xad\x47\x61" +
  b"\x47\x01\x73\xcd\xb1\x88\x73\x7e\xbe\xa7\x26\x90\x16\xbf\xa7\xb6" +
  b"\xa2\x9f\xee\x6c\x7b\xfa\x9b\xf5\x20\x5e\xb2\xff\x8f\xf8\xc8\x64" +
  b"\x8b\x1e\xf4\x03\x87\xbf\xe0\x87\xfe\x98\xfc\xb0\x0d\xa0\x00\x00"

///|
let still_file : Bytes = b"\x52\x49\x46\x46\x3a\x00\x00\x00\x57\x45\x42\x50\x56\x50\x38\x4c" +
  b"\x2e\x00\x00\x00\x2f\x01\x40\x00\x00\x1f\x20\x16\x4c\xae\x04\xf2" +
  b"\xb7\x9b\x94\x90\x20\xf9\x9f\xbc\x6a\xa5\x89\x05\x13\x7f\xb6\x44" +
  b"\xfa\x27\x30\xff\x51\x85\x1f\x40\x41\xda\x06\x2c\xda\x5f\x44\xff" +
  b"\xe3\x02"

///|
let anim_no_anim : Bytes = b"\x52\x49\x46\x46\x64\x00\x00\x00\x57\x45\x42\x50\x56\x50\x38\x58" +
  b"\x0a\x00\x00\x00\x02\x00\x00\x00\x01\x00\x00\x01\x00\x00\x41\x4e" +
  b"\x4d\x46\x46\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x01" +
  b"\x00\x00\x0a\x00\x00\x00\x56\x50\x38\x4c\x2e\x00\x00\x00\x2f\x01" +
  b"\x40\x00\x00\x1f\x20\x16\x4c\xae\x04\xf2\xb7\x9b\x94\x90\x20\xf9" +
  b"\x9f\xbc\x6a\xa5\x89\x05\x13\x7f\xb6\x44\xfa\x27\x30\xff\x51\x85" +
  b"\x1f\x40\x41\xda\x06\x2c\xda\x5f\x44\xff\xe3\x02"

///|
let anim_short_anim : Bytes = b"\x52\x49\x46\x46\x70\x00\x00\x00\x57\x45\x42\x50\x56\x50\x38\x58" +
  b"\x0a\x00\x00\x00\x02\x00\x00\x00\x01\x00\x00\x01\x00\x00\x41\x4e" +
  b"\x49\x4d\x04\x00\x00\x00\x00\x00\x00\x00\x41\x4e\x4d\x46\x46\x00" +
  b"\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x01\x00\x00\x0a\x00" +
  b"\x00\x00\x56\x50\x38\x4c\x2e\x00\x00\x00\x2f\x01\x40\x00\x00\x1f" +
  b"\x20\x16\x4c\xae\x04\xf2\xb7\x9b\x94\x90\x20\xf9\x9f\xbc\x6a\xa5" +
  b"\x89\x05\x13\x7f\xb6\x44\xfa\x27\x30\xff\x51\x85\x1f\x40\x41\xda" +
  b"\x06\x2c\xda\x5f\x44\xff\xe3\x02"

///|
let anim_no_frames : Bytes = b"\x52\x49\x46\x46\x24\x00\x00\x00\x57\x45\x42\x50\x56\x50\x38\x58" +
  b"\x0a\x00\x00\x00\x02\x00\x00\x00\x01\x00\x00\x01\x00\x00\x41\x4e" +
  b"\x49\x4d\x06\x00\x00\x00\x00\x00\x00\x00\x00\x00"

///|
let anim_bad_rect : Bytes = b"\x52\x49\x46\x46\x56\x00\x00\x00\x57\x45\x42\x50\x56\x50\x38\x58" +
  b"\x0a\x00\x00\x00\x02\x00\x00\x00\x01\x00\x00\x01\x00\x00\x41\x4e" +
  b"\x49\x4d\x06\x00\x00\x00\x00\x00\x00\x00\x00\x00\x41\x4e\x4d\x46" +
  b"\x2a\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" +
  b"\x0a\x00\x00\x00\x56\x50\x38\x4c\x11\x00\x00\x00\x2f\x00\x00\x00" +
  b"\x00\x07\xd0\xee\xc6\x35\xb3\xff\x81\x88\xe8\x7f\x00\x00"

///|
let anim_frame_mismatch : Bytes = b"\x52\x49\x46\x46\x56\x00\x00\x00\x57\x45\x42\x50\x56\x50\x38\x58" +
  b"\x0a\x00\x00\x00\x02\x00\x00\x00\x01\x00\x00\x01\x00\x00\x41\x4e" +
  b"\x49\x4d\x06\x00\x00\x00\x00\x00\x00\x00\x00\x00\x41\x4e\x4d\x46" +
  b"\x2a\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x01\x00\x00" +
  b"\x0a\x00\x00\x00\x56\x50\x38\x4c\x11\x00\x00\x00\x2f\x00\x00\x00" +
  b"\x00\x07\xd0\xee\xc6\x35\xb3\xff\x81\x88\xe8\x7f\x00\x00"

///|
let anim_short_anmf : Bytes = b"\x52\x49\x46\x46\x38\x00\x00\x00\x57\x45\x42\x50\x56\x50\x38\x58" +
  b"\x0a\x00\x00\x00\x02\x00\x00\x00\x01\x00\x00\x01\x00\x00\x41\x4e" +
  b"\x49\x4d\x06\x00\x00\x00\x00\x00\x00\x00\x00\x00\x41\x4e\x4d\x46" +
  b"\x0c\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x01\x00\x00"

///|
let anim_no_image : Bytes = b"\x52\x49\x46\x46\x48\x00\x00\x00\x57\x45\x42\x50\x56\x50\x38\x58" +
  b"\x0a\x00\x00\x00\x02\x00\x00\x00\x01\x00\x00\x01\x00\x00\x41\x4e" +
  b"\x49\x4d\x06\x00\x00\x00\x00\x00\x00\x00\x00\x00\x41\x4e\x4d\x46" +
  b"\x1c\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x01\x00\x00" +
  b"\x0a\x00\x00\x00\x41\x4c\x50\x48\x04\x00\x00\x00\x00\x00\x00\x00"

///|
test "decodes an animation written by img2webp" {
  let animation = @webp.decode_animation(anim_tool_file)
  @test.assert_eq(animation.width, 10)
  @test.assert_eq(animation.height, 8)
  @test.assert_eq(animation.loop_count, anim_tool_loop)
  @test.assert_eq(animation.background_color, anim_tool_background)
  @test.assert_eq(animation.frames.length(), 3)
  for index in 0..<3 {
    @test.assert_eq(
      animation.frames[index].duration,
      anim_tool_durations[index],
    )
    @test.assert_eq(animation.frames[index].pixels, anim_tool_frames[index])
  }
}

///|
test "composites blended and disposed frames" {
  let animation = @webp.decode_animation(anim_mixed_file)
  @test.assert_eq(animation.width, 10)
  @test.assert_eq(animation.height, 8)
  @test.assert_eq(animation.loop_count, anim_mixed_loop)
  @test.assert_eq(animation.background_color, anim_mixed_background)
  @test.assert_eq(animation.frames.length(), 5)
  for index in 0..<5 {
    @test.assert_eq(
      animation.frames[index].duration,
      anim_mixed_durations[index],
    )
    @test.assert_eq(animation.frames[index].pixels, anim_mixed_frames[index])
  }
}

///|
test "skips blending on a frame that follows a disposed full canvas" {
  let animation = @webp.decode_animation(anim_key_file)
  @test.assert_eq(animation.loop_count, anim_key_loop)
  @test.assert_eq(animation.background_color, anim_key_background)
  @test.assert_eq(animation.frames.length(), 3)
  for index in 0..<3 {
    @test.assert_eq(animation.frames[index].duration, anim_key_durations[index])
    @test.assert_eq(animation.frames[index].pixels, anim_key_frames[index])
  }
}

///|
test "reports an animation's canvas and codec" {
  let info = @webp.webp_info(anim_mixed_file)
  @test.assert_eq(info.width, 10)
  @test.assert_eq(info.height, 8)
  @test.assert_eq(info.has_alpha, true)
  @test.assert_eq(info.has_animation, true)
  @test.assert_eq(info.is_lossless, true)
}

///|
test "reports a lossy animation without decoding it" {
  let info = @webp.webp_info(anim_lossy_file)
  @test.assert_eq(info.width, 10)
  @test.assert_eq(info.height, 8)
  @test.assert_eq(info.has_animation, true)
  @test.assert_eq(info.is_lossless, false)
  let err = @test.expect_error(() => @webp.decode_animation(anim_lossy_file))
  @test.assert_eq(err, @webp.DecodeError::UnsupportedLossyImage)
}

///|
test "rejects an animation where a still image is expected" {
  let err = @test.expect_error(() => @webp.decode_webp(anim_mixed_file))
  @test.assert_eq(err, @webp.DecodeError::AnimatedImage)
  let alpha_err = @test.expect_error(() => @webp.decode_alpha(anim_mixed_file))
  @test.assert_eq(alpha_err, @webp.DecodeError::AnimatedImage)
}

///|
test "rejects a still image where an animation is expected" {
  let err = @test.expect_error(() => @webp.decode_animation(still_file))
  @test.assert_eq(err, @webp.DecodeError::MissingAnimationFrame)
}

///|
test "rejects an animation without an ANIM chunk" {
  let err = @test.expect_error(() => @webp.decode_animation(anim_no_anim))
  @test.assert_eq(err, @webp.DecodeError::MissingAnimationHeader)
}

///|
test "rejects an ANIM chunk that is too short" {
  let err = @test.expect_error(() => @webp.decode_animation(anim_short_anim))
  @test.assert_eq(err, @webp.DecodeError::InvalidAnimationHeader(4U))
}

///|
test "rejects an animation without frames" {
  let err = @test.expect_error(() => @webp.decode_animation(anim_no_frames))
  @test.assert_eq(err, @webp.DecodeError::MissingAnimationFrame)
}

///|
test "rejects a frame rectangle that leaves the canvas" {
  let err = @test.expect_error(() => @webp.decode_animation(anim_bad_rect))
  @test.assert_eq(err, @webp.DecodeError::InvalidAnimationFrame)
}

///|
test "rejects a frame that disagrees with its image size" {
  let err = @test.expect_error(() => @webp.decode_animation(anim_frame_mismatch))
  @test.assert_eq(err, @webp.DecodeError::InvalidAnimationFrame)
}

///|
test "rejects a truncated ANMF header" {
  let err = @test.expect_error(() => @webp.decode_animation(anim_short_anmf))
  @test.assert_eq(err, @webp.DecodeError::InvalidAnimationFrame)
}

///|
test "rejects a frame without an image chunk" {
  let err = @test.expect_error(() => @webp.decode_animation(anim_no_image))
  @test.assert_eq(err, @webp.DecodeError::InvalidAnimationFrame)
}
