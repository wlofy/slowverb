// Self-check for Ring: ./test.sh (main.swift so top-level code runs)
import Foundation
import CoreAudio
// interleaved stereo write of n frames with L=i+1, R=-(i+1) (non-zero, so not skipped as silence)
func push(_ ring: Ring, _ start: Int, _ n: Int) {
    var data = (0..<n).flatMap { [Float(start+$0+1), -Float(start+$0+1)] }
    data.withUnsafeMutableBytes { raw in
        var abl = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: 2, mDataByteSize: UInt32(n*8), mData: raw.baseAddress))
        ring.write(&abl, nonInterleaved: false)
    }
}
func pull(_ ring: Ring, _ n: Int) -> ([Float],[Float]) {
    var l = [Float](repeating: 9, count: n), r = l
    l.withUnsafeMutableBytes { lb in r.withUnsafeMutableBytes { rb in
        let abl = AudioBufferList.allocate(maximumBuffers: 2)
        abl[0] = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(n*4), mData: lb.baseAddress)
        abl[1] = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(n*4), mData: rb.baseAddress)
        ring.read(abl.unsafeMutablePointer, n); free(abl.unsafeMutablePointer)
    }}
    return (l, r)
}
let ring = Ring(sampleRate: 1000, seconds: 1)  // cap 1000, prime 50
push(ring, 0, 30); assert(pull(ring, 10).0.allSatisfy { $0 == 0 }, "primes silence on underrun")
push(ring, 30, 100)
let (l, r) = pull(ring, 10); assert(l == (1...10).map(Float.init) && r == l.map { -$0 }, "plays in order")
push(ring, 130, 2000)  // overflow: keeps newest 1000
let (l2, _) = pull(ring, 5); assert(l2.first == 1131, "drops oldest when full: \(l2)")
ring.catchUp(); push(ring, 0, 5); assert(pull(ring, 5).0.allSatisfy { $0 == 0 }, "catchUp empties + reprimes")
assert(abs(ring.backlog - 0.005) < 1e-9, "backlog in seconds: \(ring.backlog)")
var zeros = [Float](repeating: 0, count: 200)
zeros.withUnsafeMutableBytes { raw in
    var abl = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: 2, mDataByteSize: 800, mData: raw.baseAddress))
    ring.write(&abl, nonInterleaved: false)
}
assert(abs(ring.backlog - 0.005) < 1e-9, "silence is skipped")
print("ring ok")
