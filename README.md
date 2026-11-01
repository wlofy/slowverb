# Slowverb

Make a slowed + reverb version of any song, live, from your Mac's menu bar. Slowverb captures audio from one app (Spotify, Chrome/YouTube, Music…) or the whole system, mutes the original, and plays it back with your own speed, pitch and reverb.

- Control Center–style sliders for **Speed**, **Pitch** and **Reverb**
- One-tap presets: **Slowed + Reverb**, **Pitched Up**, **Reset**
- Stays in sync with Spotify and Music, so songs never get cut off or overlap
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

## Staying in sync

Slowed audio plays back more slowly than the app sends it. With **Spotify** or **Music** as the source, Slowverb pauses the app whenever it gets 4 s ahead and resumes it at 1 s. Because the original is muted, you never hear this, and every song plays in full, in order. The first time this happens, macOS asks you to let Slowverb control the app.

If you skip a song partway through, the rest of the old song is dropped. If a song ends on its own, its ending still plays.

## Limitations

- **Speed tops out at 1×.** Live audio can't be played faster than it arrives. For a "sped up" sound, use **Pitched Up**.
- **Browsers and All Audio aren't kept in sync**: they can't be paused remotely, so slowed audio falls behind (up to 60 s). Press **Catch Up** to jump back to live audio.
- **Safari** plays audio through a WebKit helper process, so it doesn't appear in the app list. Use **All Audio** instead.
- **Control Center:** third-party Control Center controls only support toggles and buttons, not sliders, so the full controls live in the menu bar.

## License

MIT
