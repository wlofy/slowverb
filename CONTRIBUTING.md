# Contributing to Slowverb

Thanks for helping make Slowverb better! It's free and open source, and anyone can contribute.

## Getting started

You only need macOS 14.4+ and the Xcode Command Line Tools (`xcode-select --install`).

```sh
./build.sh && open build/Slowverb.app   # build and run
./test.sh                               # self-checks
```

## Where things live

| File | What it does |
|------|--------------|
| `Slowverb.swift` | App, UI (window, menu bar panel, settings), audio engine, Core Audio helpers |
| `Ring.swift` | Buffer between the captured audio and playback |
| `FrequencyShifter.swift` | Frequency shift effect |
| `Artwork.swift` | Picks an accent color from album art |
| `Ambience.swift` | Vinyl crackle generator |
| `Resources/Rain.caf` | Rain recording (CC0), looped by the engine |
| `Tests/main.swift` | Self-checks run by `./test.sh` |

## Ideas

New effects (for example echo, tape wow and flutter, or a bitcrusher), more presets, support for more players, and accessibility improvements are all good places to start. Check the [issues](https://github.com/wlofy/slowverb/issues) too.

## Pull requests

- Keep changes focused, and match the existing style: simple code, no new dependencies unless they really pay off.
- If you change audio or buffer logic, add a check to `Tests/main.swift` and make sure `./test.sh` passes.
- Describe what you changed and how you tested it, including what you listened to.

By contributing, you agree that your work is released under the MIT License.
