import Foundation
import CoreAudio

/// Stereo FIFO between the tap's IO thread and the engine's render thread.
/// Holds up to 3 minutes so slowed playback can fall behind live for a whole song; when full, the oldest
/// audio is dropped. ~65 MB at 48 kHz.
/// Silent buffers are skipped, so a paused source doesn't pad the backlog with silence.
final class Ring: @unchecked Sendable {
    // ponytail: NSLock on audio threads is fine at these buffer sizes; go lock-free SPSC if you ever hear dropouts.
    private let lock = NSLock()
    private let cap: Int, prime: Int, sampleRate: Double
    private let l: UnsafeMutablePointer<Float>, r: UnsafeMutablePointer<Float>
    private var head = 0, count = 0, priming = true
    private var accepting = true  // false while the source is held at a song change (see hold)

    init(sampleRate: Double, seconds: Double = 180) {
        self.sampleRate = sampleRate
        cap = Int(sampleRate * seconds)
        prime = Int(sampleRate * 0.05)
        l = .allocate(capacity: cap)
        r = .allocate(capacity: cap)
    }
    deinit { l.deallocate(); r.deallocate() }

    func write(_ abl: UnsafePointer<AudioBufferList>, nonInterleaved: Bool) {
        let bufs = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: abl))
        // Tap buffers come last (after any input channels of the output device).
        guard let last = bufs.last, let lastData = last.mData else { return }
        let left: UnsafePointer<Float>, right: UnsafePointer<Float>, stride: Int, frames: Int
        if nonInterleaved, bufs.count >= 2, let ld = bufs[bufs.count - 2].mData {
            left = UnsafePointer(ld.assumingMemoryBound(to: Float.self))
            right = UnsafePointer(lastData.assumingMemoryBound(to: Float.self))
            stride = 1
            frames = Int(last.mDataByteSize) / 4
        } else {
            let ch = max(Int(last.mNumberChannels), 1)
            left = UnsafePointer(lastData.assumingMemoryBound(to: Float.self))
            right = left + (ch > 1 ? 1 : 0)
            stride = ch
            frames = Int(last.mDataByteSize) / 4 / ch
        }
        guard (0..<frames).contains(where: { left[$0 * stride] != 0 || right[$0 * stride] != 0 }) else { return }
        lock.lock(); defer { lock.unlock() }
        guard accepting else { return }
        for i in 0..<frames {
            let tail = (head + count) % cap
            l[tail] = left[i * stride]
            r[tail] = right[i * stride]
            if count == cap { head = (head + 1) % cap } else { count += 1 }
        }
    }

    func read(_ abl: UnsafeMutablePointer<AudioBufferList>, _ frames: Int) {
        let bufs = UnsafeMutableAudioBufferListPointer(abl)
        let outL = bufs[0].mData!.assumingMemoryBound(to: Float.self)
        let outR = bufs[1].mData!.assumingMemoryBound(to: Float.self)
        lock.lock(); defer { lock.unlock() }
        // On underrun, play silence until a little audio has built up again, instead of crackling.
        if count < frames { priming = true }
        if priming, count >= prime + frames { priming = false }
        for i in 0..<frames {
            if priming { outL[i] = 0; outR[i] = 0; continue }
            outL[i] = l[head]
            outR[i] = r[head]
            head = (head + 1) % cap
            count -= 1
        }
    }

    /// Stops taking audio and drops the newest `seconds`: used when the next song starts while we're still
    /// playing the previous one, so its first moments (and the player's pause fade) never get in.
    func hold(droppingNewest seconds: Double) {
        lock.lock(); defer { lock.unlock() }
        accepting = false
        count -= min(count, Int(seconds * sampleRate))
    }

    func resume() {
        lock.lock(); defer { lock.unlock() }
        accepting = true
    }

    /// Seconds of audio waiting to be played.
    var backlog: Double {
        lock.lock(); defer { lock.unlock() }
        return Double(count) / sampleRate
    }

    func catchUp() {
        lock.lock(); defer { lock.unlock() }
        head = (head + count) % cap
        count = 0
        priming = true
    }
}
