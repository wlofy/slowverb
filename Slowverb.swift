import SwiftUI
import AVFoundation
import CoreAudio

// MARK: - App

@main
struct SlowverbApp: App {
    private let engine = Engine()  // App is created once; no @State needed

    var body: some Scene {
        MenuBarExtra {
            Panel(engine: engine)
        } label: {
            Image(systemName: engine.isOn ? "waveform.circle.fill" : "waveform.circle")
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - UI

struct Panel: View {
    @Bindable var engine: Engine

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(engine.isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .symbolEffect(.variableColor.iterative, isActive: engine.isOn)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Slowverb").font(.headline)
                    Text(engine.error ?? (engine.isOn ? "Live" : "Off"))
                        .font(.caption)
                        .foregroundStyle(engine.error == nil ? .secondary : Color.red)
                        .lineLimit(2)
                }
                Spacer()
                Toggle("Enable", isOn: Binding(get: { engine.isOn }, set: { engine.setOn($0) }))
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            Module {
                Picker("Source", selection: $engine.source) {
                    Label("All Audio", systemImage: "speaker.wave.2.fill").tag("")
                    ForEach(engine.sources) { s in
                        Label { Text(s.name) } icon: { Image(nsImage: s.icon) }.tag(s.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            Module {
                FatSlider(icon: "tortoise.fill", label: "Speed", value: $engine.speed,
                          range: 0.5...1.5, step: 0.01) { String(format: "%.2f×", $0) }
                FatSlider(icon: "tuningfork", label: "Pitch", value: $engine.pitch,
                          range: -12...12, step: 0.1) { String(format: "%+.1f st", $0) }
                FatSlider(icon: "water.waves", label: "Reverb", value: $engine.reverb,
                          range: 0...100, step: 1) { "\(Int($0))%" }
            }

            HStack(spacing: 6) {
                // Vinyl-style presets: pitch follows speed (12·log2(speed) semitones).
                chip("Slowed + Reverb", speed: 0.85, pitch: -2.8, reverb: 45)
                chip("Nightcore", speed: 1.25, pitch: 3.9, reverb: 10)
                chip("Reset", speed: 1, pitch: 0, reverb: 0)
            }

            HStack {
                Button("Catch Up", systemImage: "forward.end.fill") { engine.catchUp() }
                    .help("Jump back to live audio (slowing builds up a delay)")
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: 300)
        .tint(.purple)
        .onAppear { engine.sources = Source.running() }
    }

    func chip(_ title: String, speed: Double, pitch: Double, reverb: Double) -> some View {
        let active = engine.speed == speed && engine.pitch == pitch && engine.reverb == reverb
        return Button {
            withAnimation(.snappy) { engine.speed = speed; engine.pitch = pitch; engine.reverb = reverb }
        } label: {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(active ? AnyShapeStyle(.tint.opacity(0.35)) : AnyShapeStyle(.quinary), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct Module<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 8) { content }
            .padding(10)
            .background(.quinary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Control Center–style capsule slider: drag anywhere on it.
struct FatSlider: View {
    let icon: String, label: String
    @Binding var value: Double
    let range: ClosedRange<Double>, step: Double
    let format: (Double) -> String

    var body: some View {
        GeometryReader { g in
            let f = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule().fill(.tint.opacity(0.45)).frame(width: max(g.size.height, g.size.width * f))
                HStack(spacing: 6) {
                    Image(systemName: icon).frame(width: 16)
                    Text(label)
                    Spacer()
                    Text(format(value)).monospacedDigit().foregroundStyle(.secondary)
                }
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
            }
            .contentShape(Capsule())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                set(range.lowerBound + v.location.x / g.size.width * (range.upperBound - range.lowerBound))
            })
        }
        .frame(height: 30)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(format(value))
        .accessibilityAdjustableAction { set(value + ($0 == .increment ? step : -step)) }
    }

    func set(_ v: Double) {
        value = min(max((v / step).rounded() * step, range.lowerBound), range.upperBound)
    }
}

struct Source: Identifiable {
    let id: String   // bundle ID
    let name: String
    let icon: NSImage

    /// Running apps that currently have a Core Audio client (helpers included, e.g. Chrome's).
    static func running() -> [Source] {
        let bundles = CA.processes().compactMap(CA.bundleID)
        return NSWorkspace.shared.runningApplications.compactMap { app in
            guard app.activationPolicy == .regular, let id = app.bundleIdentifier,
                  id != Bundle.main.bundleIdentifier,
                  bundles.contains(where: { $0.hasPrefix(id) }) else { return nil }
            let icon = (app.icon?.copy() as? NSImage) ?? NSImage()
            icon.size = NSSize(width: 16, height: 16)
            return Source(id: id, name: app.localizedName ?? id, icon: icon)
        }
    }
}

// MARK: - Audio

struct Failure: Error { let message: String }

@Observable
final class Engine {
    private(set) var isOn = false
    private(set) var error: String?
    var sources: [Source] = []
    var source = UserDefaults.standard.string(forKey: "source") ?? "" {
        didSet {
            UserDefaults.standard.set(source, forKey: "source")
            if isOn { stop(); start() }
        }
    }
    var speed = Engine.saved("speed", 1) { didSet { apply() } }
    var pitch = Engine.saved("pitch", 0) { didSet { apply() } }
    var reverb = Engine.saved("reverb", 0) { didSet { apply() } }

    @ObservationIgnored private let av = AVAudioEngine()
    @ObservationIgnored private let timePitch = AVAudioUnitTimePitch()
    @ObservationIgnored private let verb = AVAudioUnitReverb()
    @ObservationIgnored private var node: AVAudioSourceNode?
    @ObservationIgnored private var ring: Ring?
    @ObservationIgnored private var tap = AudioObjectID(kAudioObjectUnknown)
    @ObservationIgnored private var agg = AudioObjectID(kAudioObjectUnknown)
    @ObservationIgnored private var proc: AudioDeviceIOProcID?

    static func saved(_ key: String, _ fallback: Double) -> Double {
        UserDefaults.standard.object(forKey: key) as? Double ?? fallback
    }

    init() {
        av.attach(timePitch)
        av.attach(verb)
        verb.loadFactoryPreset(.largeHall2)
        apply()
    }

    func setOn(_ on: Bool) { on ? start() : stop() }
    func catchUp() { ring?.catchUp() }

    private func apply() {
        timePitch.rate = Float(speed)
        timePitch.pitch = Float(pitch * 100)
        verb.wetDryMix = Float(reverb)
        for (k, v) in [("speed", speed), ("pitch", pitch), ("reverb", reverb)] { UserDefaults.standard.set(v, forKey: k) }
    }

    private func start() {
        do {
            try startTap()
            isOn = true
            error = nil
        } catch {
            stop()
            self.error = (error as? Failure)?.message ?? error.localizedDescription
        }
    }

    private func startTap() throws {
        // Tap the chosen app (or everything except us) and mute the original so only our version plays.
        let desc: CATapDescription
        if source.isEmpty {
            desc = CATapDescription(stereoGlobalTapButExcludeProcesses: [CA.ownProcess()])
        } else {
            let procs = CA.processes().filter { (CA.bundleID($0) ?? "").hasPrefix(source) }
            guard !procs.isEmpty else { throw Failure(message: "That app isn't playing audio yet") }
            desc = CATapDescription(stereoMixdownOfProcesses: procs)
        }
        desc.muteBehavior = .mutedWhenTapped
        desc.isPrivate = true
        try CA.check(AudioHardwareCreateProcessTap(desc, &tap),
                     "Allow Slowverb in Privacy & Security › Screen & System Audio Recording")

        let outUID = try CA.string(CA.defaultOutput(), kAudioDevicePropertyDeviceUID)
        let config: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Slowverb Tap",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: outUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outUID]],
            kAudioAggregateDeviceTapListKey: [[kAudioSubTapDriftCompensationKey: true,
                                               kAudioSubTapUIDKey: desc.uuid.uuidString]],
        ]
        try CA.check(AudioHardwareCreateAggregateDevice(config as CFDictionary, &agg), "Couldn't create tap device")

        var asbd = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        var addr = CA.address(kAudioTapPropertyFormat)
        try CA.check(AudioObjectGetPropertyData(tap, &addr, 0, nil, &size, &asbd), "Couldn't read tap format")
        let nonInterleaved = asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved != 0

        let ring = Ring(sampleRate: asbd.mSampleRate)
        self.ring = ring
        try CA.check(AudioDeviceCreateIOProcIDWithBlock(&proc, agg, nil) { _, input, _, _, _ in
            ring.write(input, nonInterleaved: nonInterleaved)
        }, "Couldn't read tap")

        // Ring → time/pitch → reverb → speakers. TimePitch pulls faster/slower than live depending on speed.
        let fmt = AVAudioFormat(standardFormatWithSampleRate: asbd.mSampleRate, channels: 2)!
        let node = AVAudioSourceNode(format: fmt) { _, _, frames, out in
            ring.read(out, Int(frames))
            return noErr
        }
        self.node = node
        av.attach(node)
        av.connect(node, to: timePitch, format: fmt)
        av.connect(timePitch, to: verb, format: fmt)
        av.connect(verb, to: av.mainMixerNode, format: fmt)
        try av.start()
        try CA.check(AudioDeviceStart(agg, proc), "Couldn't start tap")
    }

    private func stop() {
        if let proc {
            AudioDeviceStop(agg, proc)
            AudioDeviceDestroyIOProcID(agg, proc)
        }
        proc = nil
        if agg != kAudioObjectUnknown { AudioHardwareDestroyAggregateDevice(agg) }
        if tap != kAudioObjectUnknown { AudioHardwareDestroyProcessTap(tap) }
        agg = AudioObjectID(kAudioObjectUnknown)
        tap = AudioObjectID(kAudioObjectUnknown)
        av.stop()
        if let node { av.detach(node) }
        node = nil
        ring = nil
        isOn = false
    }
}

/// Thin Core Audio property helpers.
enum CA {
    static let system = AudioObjectID(kAudioObjectSystemObject)

    static func address(_ sel: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: sel, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    }

    static func check(_ status: OSStatus, _ message: String) throws {
        if status != noErr { throw Failure(message: message) }
    }

    static func processes() -> [AudioObjectID] {
        var addr = address(kAudioHardwarePropertyProcessObjectList)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &addr, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    static func bundleID(_ process: AudioObjectID) -> String? {
        try? string(process, kAudioProcessPropertyBundleID)
    }

    static func string(_ obj: AudioObjectID, _ sel: AudioObjectPropertySelector) throws -> String {
        var addr = address(sel)
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var value: Unmanaged<CFString>?
        try check(AudioObjectGetPropertyData(obj, &addr, 0, nil, &size, &value), "Couldn't read audio property")
        guard let value else { throw Failure(message: "Missing audio property") }
        return value.takeRetainedValue() as String
    }

    static func defaultOutput() throws -> AudioObjectID {
        var addr = address(kAudioHardwarePropertyDefaultOutputDevice)
        var id = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        try check(AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &id), "No output device")
        return id
    }

    static func ownProcess() -> AudioObjectID {
        var addr = address(kAudioHardwarePropertyTranslatePIDToProcessObject)
        var pid = getpid()
        var id = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        AudioObjectGetPropertyData(system, &addr, UInt32(MemoryLayout<pid_t>.size), &pid, &size, &id)
        return id
    }
}
