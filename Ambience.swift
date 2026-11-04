import Foundation

/// Vinyl crackle, generated live: a soft hiss, frequent tiny ticks and the odd louder pop.
/// Mixed in after the effects, so it isn't slowed down or smeared by the reverb.
/// (Rain is a looped recording, played by the engine: generated rain sounded metallic.)
final class Ambience: @unchecked Sendable {
    // ponytail: set on the main thread, read on the audio thread without a lock (same as FrequencyShifter.shift).
    var crackle: Float = 0  // 0...1
    private let sampleRate: Float
    private var seed: UInt32 = 0x9E37_79B9
    private var hiss: Float = 0, tick: Float = 0, pop: Float = 0

    init(sampleRate: Double) { self.sampleRate = Float(sampleRate) }

    func render(_ l: UnsafeMutablePointer<Float>, _ r: UnsafeMutablePointer<Float>, frames: Int) {
        let level = crackle
        guard level > 0 else {
            l.update(repeating: 0, count: frames)
            r.update(repeating: 0, count: frames)
            return
        }
        let tickChance = 40 / sampleRate   // ~40 ticks a second
        let popChance = 0.7 / sampleRate   // a louder pop every ~1.5 s
        for i in 0..<frames {
            hiss = hiss * 0.6 + noise() * 0.4  // softened white noise
            if uniform() < tickChance { tick += noise() * 0.3 }
            if uniform() < popChance { pop += (noise() > 0 ? 0.35 : -0.35) }
            tick *= 0.5   // gone within a few samples: a sharp tick
            pop *= 0.93   // ~0.3 ms: a duller pop
            let s = (hiss * 0.012 + tick + pop) * level
            l[i] = s
            r[i] = s * 0.85 + hiss * 0.004 * level  // slightly different per side, like a real stylus
        }
    }

    // xorshift32: cheap and allocation-free, fine for noise on the audio thread.
    private func next() -> UInt32 {
        seed ^= seed << 13; seed ^= seed >> 17; seed ^= seed << 5
        return seed
    }
    private func uniform() -> Float { Float(next()) / Float(UInt32.max) }
    private func noise() -> Float { uniform() * 2 - 1 }
}
