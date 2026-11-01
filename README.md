# Slowverb

Make a slowed + reverb version of any song, live, from your Mac's menu bar. Slowverb captures audio from one app (Spotify, Chrome/YouTube, Music…) or the whole system, mutes the original, and plays it back with your own speed, pitch and reverb.

- Control Center–style sliders for **Speed**, **Pitch** and **Reverb**
- One-tap presets: **Slowed + Reverb**, **Nightcore**, **Reset**
- Choose which app to capture, or use **All Audio**
- Settings are remembered between launches
- One Swift file, no dependencies, builds without Xcode

## Requirements

macOS 14.4 or later (uses Core Audio process taps) and the Xcode Command Line Tools (`xcode-select --install`).

## Build & run

```sh
./build.sh
open build/Slowverb.app
```

Click the waveform icon in the menu bar and turn on the switch. The first time you do this, macOS asks for permission to record system audio. If you deny it, you can allow it later in **System Settings › Privacy & Security › Screen & System Audio Recording**.

To run the ring buffer self-check: `./test.sh`.

## How it works

`CATapDescription` + `AudioHardwareCreateProcessTap` capture the selected app's audio and mute it at the source. The captured audio goes into a ring buffer, then through `AVAudioEngine`: `AVAudioUnitTimePitch` (speed and pitch) → `AVAudioUnitReverb` → speakers.

## Limitations

- **Speed on live audio adds a delay.** Slowing a live stream means Slowverb plays more slowly than the source sends audio, so it falls behind (up to 60 s, after which the oldest audio is dropped). Press **Catch Up** to jump back to live audio. Above 1× there isn't enough audio to keep up, so you'll hear short gaps.
- **Safari** plays audio through a WebKit helper process, so it doesn't appear in the app list. Use **All Audio** instead.
- **Control Center:** third-party Control Center controls only support toggles and buttons, not sliders, so the full controls live in the menu bar.

## License

MIT
