import Foundation

/// Single-sideband frequency shifter: moves every frequency by the same number of Hz (pitch shifting
/// scales them instead), which gives a metallic, detuned sound. The Hilbert transform is two allpass
/// chains ~90° apart (Olli Niemitalo's coefficients), mixed with a sine/cosine oscillator.
final class FrequencyShifter: @unchecked Sendable {
    // ponytail: set on the main thread, read on the audio thread without a lock; worst case one buffer uses the old value.
    var shift: Double = 0
    private let sampleRate: Double
    private var phase = 0.0
    private let left = Channel(), right = Channel()

    init(sampleRate: Double) { self.sampleRate = sampleRate }

    func process(_ l: UnsafeMutablePointer<Float>, _ r: UnsafeMutablePointer<Float>, frames: Int) {
        let shift = self.shift
        guard shift != 0 else { return }
        let step = 2 * Double.pi * shift / sampleRate
        for i in 0..<frames {
            let c = cos(phase), s = sin(phase)
            let (li, lq) = left.iq(Double(l[i]))
            let (ri, rq) = right.iq(Double(r[i]))
            l[i] = Float(li * c + lq * s)
            r[i] = Float(ri * c + rq * s)
            phase = (phase + step).truncatingRemainder(dividingBy: 2 * Double.pi)
        }
    }

    private final class Channel {
        static let a = [0.6923878, 0.9360654322959, 0.9882295226860, 0.9987488452737].map { $0 * $0 }
        static let b = [0.4021921162426, 0.8561710882420, 0.9722909545651, 0.9952884791278].map { $0 * $0 }
        var state = [Double](repeating: 0, count: 32)  // per stage: x[n-1], x[n-2], y[n-1], y[n-2]
        var bDelayed = 0.0

        /// In-phase and quadrature parts of x.
        func iq(_ x: Double) -> (Double, Double) {
            var i = x, q = x
            for k in 0..<4 {
                i = stage(k, i, Self.a[k])
                q = stage(4 + k, q, Self.b[k])
            }
            let out = (i, bDelayed)
            bDelayed = q
            return out
        }

        func stage(_ n: Int, _ x: Double, _ c: Double) -> Double {
            let o = n * 4
            let y = c * (x + state[o + 3]) - state[o + 1]
            state[o + 1] = state[o]; state[o] = x
            state[o + 3] = state[o + 2]; state[o + 2] = y
            return y
        }
    }
}
