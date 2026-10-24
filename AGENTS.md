# AGENTS

MoonBit project. Packages are directories with a `moon.pkg`; test files
end in `_test.mbt` (blackbox) or `_wbtest.mbt` (whitebox).

## Rules

- One package: `webp`. The format layers (RIFF, VP8L bitstream,
  container) are modules inside it, not separate packages.
- Decode functions return errors, never panic.
- Commit messages are short imperative feature summaries (e.g. "Add
  RIFF container parsing"), never batch numbers.
- Comments in English.
