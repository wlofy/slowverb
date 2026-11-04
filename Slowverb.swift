import SwiftUI
import AVFoundation
import CoreAudio

// MARK: - App

@main
struct SlowverbApp: App {
    private let engine = Engine()  // App is created once; no @State needed

    init() {
        // `Slowverb --iconset <dir>` renders the app icon PNGs (used by build.sh).
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--iconset"), i + 1 < args.count {
            Record.writeIconset(to: args[i + 1])
            exit(0)
        }
    }

    var body: some Scene {
        Window("Slowverb", id: "main") {
            Panel(engine: engine, inWindow: true)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 920, height: 600)

        MenuBarExtra {
            Panel(engine: engine, inWindow: false)
        } label: {
            MenuBarIcon(engine: engine)
        }
        .menuBarExtraStyle(.window)

        Settings { SettingsView(engine: engine) }
    }
}

// MARK: - UI

struct Panel: View {
    @Bindable var engine: Engine
    let inWindow: Bool
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        GlassGroup {
            if inWindow {
                // Regular desktop window: big record and song on the left, controls on the right.
                HStack(spacing: 44) {
                    VStack(spacing: 20) {
                        record.aspectRatio(1, contentMode: .fit)
                            .frame(maxWidth: 380, maxHeight: 380)
                            .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
                        VStack(spacing: 4) {
                            Text(title).font(.title.weight(.bold))
                            if let artist { Text(artist).font(.title3).foregroundStyle(.secondary) }
                        }
                        .lineLimit(1)
                        HStack(spacing: 12) {
                            PowerButton(isOn: engine.isOn, tint: engine.tint) { engine.setOn(!engine.isOn) }
                            statusText
                        }
                    }
                    .frame(maxWidth: .infinity)
                    VStack(spacing: 12) { controls }
                        .frame(width: 380)
                }
                .padding(.horizontal, 44).padding(.vertical, 36)
                .frame(minWidth: 820, maxWidth: .infinity, minHeight: 540, maxHeight: .infinity)
            } else {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        record.frame(width: 44, height: 44)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(title).font(.headline).lineLimit(1)
                            if let artist { Text(artist).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                            statusText
                        }
                        Spacer()
                        PowerButton(isOn: engine.isOn, tint: engine.tint) { engine.setOn(!engine.isOn) }
                    }
                    controls
                }
                .padding(12)
                .frame(width: 300)
            }
        }
        .background { Backdrop(art: engine.labelArt, tint: engine.tint) }
        .tint(engine.tint)
        .animation(.smooth(duration: 0.6), value: engine.tint)
        .onAppear {
            engine.sources = Source.running()
            engine.loadNowPlaying()
        }
    }

    /// Source, sliders, presets and footer; shared by the window and the menu bar panel.
    @ViewBuilder var controls: some View {
        Picker("Source", selection: $engine.source) {
            Label("All Audio", systemImage: "speaker.wave.2.fill").tag("")
            ForEach(engine.sources) { s in
                Label { Text(s.name) } icon: { Image(nsImage: s.icon) }.tag(s.id)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .padding(.horizontal, 6).padding(.vertical, 4)
        .glass(in: Capsule())

        VStack(spacing: 6) {
            FatSlider(icon: "tortoise.fill", label: "Speed", value: $engine.speed, range: 0.5...1, step: 0.01,
                      detents: [0.5, 0.75, 0.8, 0.85, 0.9, 1], reset: 1) { String(format: "%.2f×", $0) }
            FatSlider(icon: "tuningfork", label: "Pitch", value: $engine.pitch, range: -12...12, step: 0.1,
                      detents: [-12, -7, -5, -3, 0, 3, 5, 7, 12]) { String(format: "%+.1f st", $0) }
            FatSlider(icon: "water.waves", label: "Reverb", value: $engine.reverb, range: 0...100, step: 1,
                      detents: [0, 25, 50, 75, 100]) { "\(Int($0))%" }
            FatSlider(icon: "speaker.wave.3.fill", label: "Bass", value: $engine.bass, range: 0...12, step: 0.5,
                      detents: [0, 3, 6, 9, 12]) { String(format: "+%.1f dB", $0) }
            FatSlider(icon: "waveform.path", label: "Shift", value: $engine.shift, range: -200...200, step: 1,
                      detents: [-100, -50, 0, 50, 100]) { String(format: "%+.0f Hz", $0) }
            FatSlider(icon: "dial.low.fill", label: "Lo-fi", value: $engine.lofi, range: 0...100, step: 1,
                      detents: [0, 25, 50, 75, 100]) { "\(Int($0))%" }
            FatSlider(icon: "sparkles", label: "Crackle", value: $engine.crackle, range: 0...100, step: 1,
                      detents: [0, 25, 50, 75, 100]) { "\(Int($0))%" }
            FatSlider(icon: "cloud.rain.fill", label: "Rain", value: $engine.rain, range: 0...100, step: 1,
                      detents: [0, 25, 50, 75, 100]) { "\(Int($0))%" }
        }

        // Vinyl-style: pitch follows speed (12·log2(speed) semitones).
        Grid(horizontalSpacing: 6, verticalSpacing: 6) {
            GridRow {
                chip("Slowed + Reverb", speed: 0.85, pitch: -2.8, reverb: 45, bass: 4)
                chip("Lo-fi", speed: 0.92, pitch: -1.4, reverb: 25, bass: 3, lofi: 55, crackle: 40)
            }
            GridRow {
                chip("Pitched Up", speed: 1, pitch: 4, reverb: 10)
                chip("Reset", speed: 1, pitch: 0, reverb: 0)
            }
        }

        HStack(spacing: 14) {
            Button("Catch Up", systemImage: "forward.end.fill") { engine.catchUp() }
                .help("Skip the slowed backlog and jump to what's playing now")
            Spacer()
            if !inWindow {
                Button("Open Window", systemImage: "macwindow") {
                    openWindow(id: "main")
                    NSApp.activate()
                }
                .labelStyle(.iconOnly)
                .help("Open the Slowverb window")
            }
            SettingsLink { Image(systemName: "gearshape") }
                .help("Settings")
                .simultaneousGesture(TapGesture().onEnded { NSApp.activate() })
            if inWindow { MadeBy() } else { Button("Quit") { NSApp.terminate(nil) } }
        }
        .buttonStyle(.borderless)
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    var title: String { engine.showNowPlaying ? engine.song ?? "Slowverb" : "Slowverb" }
    var artist: String? { engine.showNowPlaying ? engine.artist : nil }

    var statusText: some View {
        Text(engine.error ?? status)
            .font(.caption)
            .foregroundStyle(engine.error == nil ? .secondary : Color.red)
            .lineLimit(2)
    }

    /// The record doubles as a play button.
    var record: some View {
        SpinningRecord(engine: engine)
            .contentShape(Circle())
            .onTapGesture { engine.setOn(!engine.isOn) }
            .accessibilityHidden(true)
    }

    var status: String {
        guard engine.isOn else { return "Off" }
        guard engine.synced else { return "Live — Catch Up if it drifts" }
        return "In sync with \(engine.sources.first { $0.id == engine.source }?.name ?? "app")"
    }

    func chip(_ title: String, speed: Double, pitch: Double, reverb: Double, bass: Double = 0, shift: Double = 0,
              lofi: Double = 0, crackle: Double = 0, rain: Double = 0) -> some View {
        let active = engine.speed == speed && engine.pitch == pitch && engine.reverb == reverb
            && engine.bass == bass && engine.shift == shift && engine.lofi == lofi && engine.crackle == crackle && engine.rain == rain
        return Button {
            withAnimation(.snappy) { engine.speed = speed; engine.pitch = pitch; engine.reverb = reverb; engine.bass = bass; engine.shift = shift
                engine.lofi = lofi; engine.crackle = crackle; engine.rain = rain }
        } label: {
            Text(title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(active ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .glass(active ? engine.tint : nil, interactive: true, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Blurred album art (or a soft accent gradient) for the glass to refract.
struct Backdrop: View {
    let art: NSImage?
    let tint: Color

    var body: some View {
        ZStack {
            LinearGradient(colors: [tint.opacity(0.45), tint.opacity(0.08)], startPoint: .top, endPoint: .bottom)
            if let art {
                Image(nsImage: art).resizable().scaledToFill().blur(radius: 50).opacity(0.65)
            }
        }
        .ignoresSafeArea()
        .clipped()
    }
}

/// Liquid Glass on macOS 26+, frosted fill before that.
extension View {
    @ViewBuilder func glass(_ tint: Color? = nil, interactive: Bool = false, in shape: some Shape) -> some View {
        if #available(macOS 26, *) {
            glassEffect(.regular.tint(tint).interactive(interactive), in: shape)
        } else {
            background(tint.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.quinary), in: shape)
        }
    }
}

/// Lets neighbouring glass shapes blend into each other, like Control Center.
struct GlassGroup<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: 10) { content }
        } else {
            content
        }
    }
}

/// Control Center–style round toggle: tinted glass when on.
struct PowerButton: View {
    let isOn: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "power")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(isOn ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                .frame(width: 36, height: 36)
                .glass(isOn ? tint : nil, interactive: true, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .animation(.snappy, value: isOn)
        .accessibilityLabel(isOn ? "Turn off" : "Turn on")
    }
}

/// Control Center–style glass capsule slider: drag anywhere on it, double-click to reset.
/// Snaps to `detents` (shown as dots) with a trackpad tick.
struct FatSlider: View {
    let icon: String, label: String
    @Binding var value: Double
    let range: ClosedRange<Double>, step: Double
    var detents: [Double] = []
    var reset: Double = 0
    let format: (Double) -> String

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(.tint.opacity(0.55)).frame(width: max(g.size.height, g.size.width * fraction(value)))
                ForEach(detents.filter { $0 > range.lowerBound && $0 < range.upperBound }, id: \.self) { d in
                    Circle().fill(.secondary.opacity(0.6)).frame(width: 3, height: 3)
                        .position(x: g.size.width * fraction(d), y: g.size.height - 4)
                }
                HStack(spacing: 6) {
                    Image(systemName: icon).frame(width: 16)
                    Text(label)
                    Spacer()
                    Text(format(value)).monospacedDigit().foregroundStyle(.secondary)
                }
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 12)
            }
            .glass(in: Capsule())
            .contentShape(Capsule())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                if NSApp.currentEvent?.clickCount == 2 {
                    withAnimation(.snappy) { value = reset }
                    return
                }
                set(range.lowerBound + v.location.x / g.size.width * (range.upperBound - range.lowerBound))
            })
        }
        .frame(height: 32)
        .help("Double-click to reset")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(format(value))
        .accessibilityAdjustableAction { set(value + ($0 == .increment ? step : -step)) }
        .accessibilityAction(named: "Reset") { value = reset }
    }

    func fraction(_ v: Double) -> Double { (v - range.lowerBound) / (range.upperBound - range.lowerBound) }

    func set(_ raw: Double) {
        var v = (raw / step).rounded() * step
        let pull = (range.upperBound - range.lowerBound) * 0.025
        if let d = detents.first(where: { abs($0 - v) <= pull }) {
            if value != d { NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now) }
            v = d
        }
        value = min(max(v, range.lowerBound), range.upperBound)
    }
}

/// The only views that read `engine.spin`, so each spin step redraws just the record,
/// not the panel, sliders and glass around it.
struct SpinningRecord: View {
    let engine: Engine
    var body: some View {
        Record(angle: engine.spin, vinyl: engine.vinyl, label: engine.tint, art: engine.labelArt)
    }
}

struct MenuBarIcon: View {
    let engine: Engine
    var body: some View {
        Image(nsImage: Record.menuFrames[engine.menuFrame])
    }
}

/// Spinning vinyl: the app logo, menu bar icon and Dock icon. The label shows album art when there is some.
struct Record: View {
    var angle: Double  // degrees
    var vinyl = Color(hex: Engine.defaultVinyl)
    var label = Color(hex: Engine.defaultAccent)
    var art: NSImage? = nil
    var template = false  // monochrome cut-out version for the menu bar

    var body: some View {
        Canvas { ctx, size in
            let r = min(size.width, size.height) / 2
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            func circle(_ radius: Double) -> Path {
                Path(ellipseIn: CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2))
            }
            func half(_ radius: Double) -> Path {
                var p = Path()
                p.addArc(center: c, radius: radius, startAngle: .zero, endAngle: .degrees(180), clockwise: false)
                p.closeSubpath()
                return p
            }

            ctx.fill(circle(r), with: .color(template ? .black : vinyl))
            if template {
                ctx.blendMode = .destinationOut
                ctx.stroke(circle(r * 0.68), with: .color(.black), lineWidth: max(1, r * 0.1))
            } else {
                for g in stride(from: 0.46, through: 0.94, by: 0.06) {
                    ctx.stroke(circle(r * g), with: .color(.white.opacity(0.07)), lineWidth: max(0.5, r * 0.008))
                }
                for start in [-60.0, 120.0] {  // light glinting off the vinyl; stays put while it spins
                    var p = Path()
                    p.move(to: c)
                    p.addArc(center: c, radius: r * 0.97, startAngle: .degrees(start), endAngle: .degrees(start + 28), clockwise: false)
                    p.closeSubpath()
                    ctx.fill(p, with: .color(.white.opacity(0.07)))
                }
            }

            ctx.translateBy(x: c.x, y: c.y)
            ctx.rotate(by: .degrees(angle))
            ctx.translateBy(x: -c.x, y: -c.y)
            if template {
                ctx.fill(half(r * 0.4), with: .color(.black))  // half-moon cut-out so the spin shows
            } else if let art {
                let lr = r * 0.42
                ctx.drawLayer { layer in
                    layer.clip(to: circle(lr))
                    layer.draw(Image(nsImage: art).resizable(), in: CGRect(x: c.x - lr, y: c.y - lr, width: lr * 2, height: lr * 2))
                }
                ctx.stroke(circle(lr), with: .color(.black.opacity(0.3)), lineWidth: max(0.5, r * 0.01))
            } else {
                ctx.fill(circle(r * 0.36), with: .color(label))
                ctx.fill(half(r * 0.36), with: .color(.black.opacity(0.2)))  // two-tone so the spin shows
            }
            ctx.blendMode = .destinationOut
            ctx.fill(circle(r * 0.05), with: .color(.black))
        }
    }

    /// Menu bar frames (10° apart), drawn once. Each status item update is a round trip to the system's
    /// menu bar process, so the icon only changes when the frame does (~4/s), not on every spin step.
    @MainActor static let menuFrames = (0..<36).map { image(size: 18, angle: Double($0) * 10) }

    @MainActor static func image(size: Double, angle: Double) -> NSImage {
        let renderer = ImageRenderer(content: Record(angle: angle, template: true).frame(width: size, height: size))
        renderer.scale = 2
        let image = renderer.nsImage ?? NSImage()
        image.isTemplate = true
        return image
    }

    @MainActor static func writeIconset(to dir: String) {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        for points in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let renderer = ImageRenderer(content: AppIcon().frame(width: Double(points * scale), height: Double(points * scale)))
                guard let cg = renderer.cgImage,
                      let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else { continue }
                let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
                try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent(name))
            }
        }
    }
}

/// Dock and Finder icon: a minimal record on a dark squircle, drawn on the standard macOS icon grid
/// (824/1024 shape, continuous corners) so macOS 26 shows it as-is rather than inside a grey tile.
struct AppIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width, c = CGPoint(x: s / 2, y: s / 2)
            func circle(_ r: Double) -> Path { Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)) }
            let inset = s * (1 - 0.8047) / 2
            let tile = Path(roundedRect: CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2),
                            cornerRadius: s * 0.181, style: .continuous)

            var shadowed = ctx
            shadowed.addFilter(.shadow(color: .black.opacity(0.3), radius: s * 0.012, y: s * 0.01))
            shadowed.fill(tile, with: .linearGradient(Gradient(colors: [Color(hex: "3A3A3C"), Color(hex: "121214")]),
                                                      startPoint: CGPoint(x: c.x, y: inset), endPoint: CGPoint(x: c.x, y: s - inset)))
            ctx.stroke(tile, with: .color(.white.opacity(0.08)), lineWidth: max(1, s * 0.003))

            ctx.fill(circle(s * 0.3), with: .color(Color(hex: "0A0A0B")))
            for g in [0.27, 0.235, 0.2, 0.165] {
                ctx.stroke(circle(s * g), with: .color(.white.opacity(0.1)), lineWidth: max(0.5, s * 0.003))
            }
            ctx.fill(circle(s * 0.1), with: .color(Color(hex: Engine.defaultAccent)))
            ctx.fill(circle(s * 0.014), with: .color(Color(hex: "121214")))
        }
    }
}

struct SettingsView: View {
    @Bindable var engine: Engine
    static let swatches = ["AF52DE", "FF2D55", "FF3B30", "FF9500", "FFCC00", "34C759", "00C7BE", "30B0C7", "007AFF", "5856D6"]

    var body: some View {
        Form {
            Section {
                SpinningRecord(engine: engine)
                    .frame(width: 110, height: 110)
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            Section("Now Playing") {
                Toggle("Show song and album art", isOn: $engine.showNowPlaying)
                Toggle("Match colors to album art", isOn: $engine.matchArtwork)
                Text("Works with Spotify and Music.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Colors") {
                HStack(spacing: 8) {
                    ForEach(Self.swatches, id: \.self) { hex in
                        Circle().fill(Color(hex: hex)).frame(width: 20, height: 20)
                            .overlay {
                                if engine.accent.hex == hex {
                                    Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                                }
                            }
                            .onTapGesture { engine.accent = Color(hex: hex) }
                            .accessibilityAddTraits(.isButton)
                            .accessibilityLabel("Accent \(hex)")
                    }
                }
                ColorPicker("Accent & label", selection: $engine.accent, supportsOpacity: false)
                ColorPicker("Vinyl", selection: $engine.vinyl, supportsOpacity: false)
                if engine.matchArtwork, engine.artworkColor != nil {
                    Text("The accent follows the album art while it's playing.").font(.caption).foregroundStyle(.secondary)
                }
                Button("Reset Colors") {
                    engine.accent = Color(hex: Engine.defaultAccent)
                    engine.vinyl = Color(hex: Engine.defaultVinyl)
                }
            }
            Section {
                LabeledContent("Slowverb", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                MadeBy()
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .tint(engine.tint)
    }
}

struct MadeBy: View {
    var body: some View {
        Link("Free & open source · Made by wlofy", destination: URL(string: "https://github.com/wlofy/slowverb")!)
            .font(.caption)
            .help("Contribute at github.com/wlofy/slowverb")
    }
}

extension Color {
    init(hex: String) {
        let v = UInt32(hex, radix: 16) ?? 0
        self.init(red: Double(v >> 16 & 0xFF) / 255, green: Double(v >> 8 & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }

    var hex: String {
        let c = NSColor(self).usingColorSpace(.sRGB) ?? .black
        return String(format: "%02X%02X%02X", Int((c.redComponent * 255).rounded()),
                      Int((c.greenComponent * 255).rounded()), Int((c.blueComponent * 255).rounded()))
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
    private(set) var spin = 0.0  // degrees; turns the record logo while playing
    private(set) var menuFrame = 0  // index into Record.menuFrames; set only when it changes
    var accent = Color(hex: UserDefaults.standard.string(forKey: "accent") ?? Engine.defaultAccent) {
        didSet { UserDefaults.standard.set(accent.hex, forKey: "accent") }
    }
    var vinyl = Color(hex: UserDefaults.standard.string(forKey: "vinyl") ?? Engine.defaultVinyl) {
        didSet { UserDefaults.standard.set(vinyl.hex, forKey: "vinyl") }
    }
    static let defaultAccent = "AF52DE", defaultVinyl = "1C1C1E"
    static let spotify = "com.spotify.client", music = "com.apple.Music"

    // Now playing (Spotify / Music)
    var showNowPlaying = UserDefaults.standard.object(forKey: "showNowPlaying") as? Bool ?? true {
        didSet { UserDefaults.standard.set(showNowPlaying, forKey: "showNowPlaying") }
    }
    var matchArtwork = UserDefaults.standard.object(forKey: "matchArtwork") as? Bool ?? true {
        didSet { UserDefaults.standard.set(matchArtwork, forKey: "matchArtwork") }
    }
    private(set) var song: String?
    private(set) var artist: String?
    private(set) var artwork: NSImage? {
        didSet { artworkColor = artwork?.vividColor.map(Color.init(nsColor:)) }
    }
    private(set) var artworkColor: Color?
    /// The accent in use: the album art's color when matching is on, otherwise the chosen accent.
    var tint: Color { matchArtwork ? artworkColor ?? accent : accent }
    /// Album art for the record label, if the user wants it shown.
    var labelArt: NSImage? { showNowPlaying ? artwork : nil }
    private(set) var synced = false  // we pause/resume the source app so slowed audio never falls behind
    var sources: [Source] = []
    var source = UserDefaults.standard.string(forKey: "source") ?? "" {
        didSet {
            UserDefaults.standard.set(source, forKey: "source")
            if isOn { stop(); start() }
        }
    }
    var speed = min(Engine.saved("speed", 1), 1) { didSet { apply() } }
    var pitch = Engine.saved("pitch", 0) { didSet { apply() } }
    var reverb = Engine.saved("reverb", 0) { didSet { apply() } }
    var bass = Engine.saved("bass", 0) { didSet { apply() } }
    var shift = Engine.saved("shift", 0) { didSet { apply() } }
    var lofi = Engine.saved("lofi", 0) { didSet { apply() } }
    var crackle = Engine.saved("crackle", 0) { didSet { apply() } }
    var rain = Engine.saved("rain", 0) { didSet { apply() } }

    @ObservationIgnored private let av = AVAudioEngine()
    @ObservationIgnored private let timePitch = AVAudioUnitTimePitch()
    @ObservationIgnored private let verb = AVAudioUnitReverb()
    @ObservationIgnored private let eq = AVAudioUnitEQ(numberOfBands: 2)  // bass shelf, lo-fi low-pass
    @ObservationIgnored private var shifter: FrequencyShifter?
    @ObservationIgnored private var ambience: Ambience?
    @ObservationIgnored private var ambienceNode: AVAudioSourceNode?
    // Rain is a real recording looped seamlessly ("Rain (loopable)" by Ylmir, CC0, opengameart.org).
    @ObservationIgnored private let rainPlayer = AVAudioPlayerNode()
    @ObservationIgnored private let rainLoop: AVAudioPCMBuffer? = Bundle.main.url(forResource: "Rain", withExtension: "caf").flatMap(Engine.load)
    @ObservationIgnored private var node: AVAudioSourceNode?
    @ObservationIgnored private var ring: Ring?
    @ObservationIgnored private var tap = AudioObjectID(kAudioObjectUnknown)
    @ObservationIgnored private var agg = AudioObjectID(kAudioObjectUnknown)
    @ObservationIgnored private var proc: AudioDeviceIOProcID?
    @ObservationIgnored private var pacer: Timer?
    @ObservationIgnored private var spinner: Timer?
    @ObservationIgnored private var pausedSource = false
    @ObservationIgnored private var restartTrack = false  // held at a song change: resume the new song from 0:00
    typealias Track = (id: String, length: Double, position: Double, at: Date, playing: Bool)
    @ObservationIgnored private var track: Track?

    static func load(_ url: URL) -> AVAudioPCMBuffer? {
        guard let file = try? AVAudioFile(forReading: url),
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: buffer)) != nil else { return nil }
        return buffer
    }

    static func saved(_ key: String, _ fallback: Double) -> Double {
        UserDefaults.standard.object(forKey: key) as? Double ?? fallback
    }

    init() {
        av.attach(timePitch)
        av.attach(verb)
        av.attach(eq)
        av.attach(rainPlayer)
        if let rainLoop {  // the mixer converts it to the output device's sample rate
            av.connect(rainPlayer, to: av.mainMixerNode, fromBus: 0, toBus: av.mainMixerNode.nextAvailableInputBus, format: rainLoop.format)
        }
        eq.bands[0].filterType = .lowShelf
        eq.bands[0].frequency = 120
        eq.bands[0].bypass = false
        eq.bands[1].filterType = .lowPass
        verb.loadFactoryPreset(.largeHall2)
        apply()
        for name in ["com.spotify.client.PlaybackStateChanged", "com.apple.Music.playerInfo"] {
            let player = name.hasPrefix(Engine.spotify) ? Engine.spotify : Engine.music
            DistributedNotificationCenter.default().addObserver(forName: .init(name), object: nil, queue: .main) { [weak self] in
                self?.playerChanged($0.userInfo ?? [:], from: player)
            }
        }
    }

    private func playerChanged(_ info: [AnyHashable: Any], from player: String) {
        guard let name = info["Name"] as? String else { return }  // e.g. Spotify's "Stopped" carries no track
        let length = ((info["Duration"] ?? info["Total Time"]) as? NSNumber)?.doubleValue ?? 0  // ms
        nowPlaying(song: name, artist: info["Artist"] as? String, length: length / 1000,
                   position: (info["Playback Position"] as? NSNumber)?.doubleValue,
                   playing: info["Player State"] as? String == "Playing", from: player)
    }

    /// Asks the player what's playing (when the panel opens or Slowverb turns on), so the first skip
    /// is handled even before the player has sent any update.
    func loadNowPlaying() {
        guard let player = [source, Engine.spotify, Engine.music].first(where: {
            ($0 == Engine.spotify || $0 == Engine.music) && !NSRunningApplication.runningApplications(withBundleIdentifier: $0).isEmpty
        }), let info = Engine.script(player, """
            return {name of current track, artist of current track, duration of current track, player position, player state as text}
            """), let name = info.atIndex(1)?.stringValue else { return }
        let duration = info.atIndex(3)?.doubleValue ?? 0
        nowPlaying(song: name, artist: info.atIndex(2)?.stringValue,
                   length: player == Engine.spotify ? duration / 1000 : duration,  // Spotify reports ms, Music seconds
                   position: info.atIndex(4)?.doubleValue, playing: info.atIndex(5)?.stringValue == "playing", from: player)
    }

    /// When the user skips to another song, drop what's left of the old one (and its reverb tail) instead of
    /// finishing it. A song that ended on its own keeps its ending.
    private func nowPlaying(song: String, artist: String?, length: Double, position reported: Double?, playing: Bool, from player: String) {
        let id = song + "|" + (artist ?? "")
        let now = Date()
        // ponytail: position is estimated between updates; scrubbing in Music (which doesn't report it) can misjudge a skip.
        func position(_ t: Track) -> Double { t.position + (t.playing ? now.timeIntervalSince(t.at) : 0) }
        if isOn, let t = track, t.id != id {
            if t.length == 0 || position(t) < t.length - 3 {
                catchUp()
            } else if synced, !pausedSource, let ring, ring.backlog > 1 {
                // The song ended on its own but we're still playing its slowed version. Hold the next song
                // until we're done, then start it from the top. Pausing here means the player's pause/play
                // fades land on the first moments of a song, not in the middle of one.
                // ponytail: 0.4 s covers the notification arriving a little after the new song starts.
                ring.hold(droppingNewest: 0.4)
                if tell("pause") { pausedSource = true; restartTrack = true } else { ring.resume() }
            }
        }
        if track?.id != id { loadArtwork(from: player) }
        self.song = song
        self.artist = artist
        let carried = track.flatMap { $0.id == id ? position($0) : nil } ?? 0
        track = (id, length, reported ?? carried, now, playing)
    }

    private func loadArtwork(from player: String) {
        // ponytail: AppleScript runs on the main thread; Music's artwork can take ~100ms. Move off-main if it ever stutters.
        if player == Engine.spotify {
            guard let url = Engine.script(player, "return artwork url of current track")?.stringValue.flatMap(URL.init(string:)) else { return }
            URLSession.shared.dataTask(with: url) { data, _, _ in
                let image = data.flatMap(NSImage.init(data:))
                DispatchQueue.main.async { self.artwork = image }
            }.resume()
        } else {
            artwork = Engine.script(player, "return data of artwork 1 of current track").flatMap { NSImage(data: $0.data) }
        }
    }

    func setOn(_ on: Bool) { on ? start() : stop() }
    /// Drops the backlog and the effects' tails, so only what's playing now is heard.
    func catchUp() {
        ring?.catchUp()
        timePitch.reset()
        verb.reset()
    }

    private func apply() {
        timePitch.rate = Float(speed)
        timePitch.pitch = Float(pitch * 100)
        verb.wetDryMix = Float(reverb)
        eq.bands[0].gain = Float(bass)
        eq.globalGain = Float(-bass / 2)  // leave headroom so the boost doesn't clip
        shifter?.shift = shift
        // Lo-fi muffles the top end: 0% = off, 100% = a 2.5 kHz low-pass, like an old cassette.
        eq.bands[1].bypass = lofi == 0
        eq.bands[1].frequency = Float(20000 * pow(0.125, lofi / 100))
        ambience?.crackle = Float(crackle / 100)
        rainPlayer.volume = Float(rain / 100)
        for (k, v) in [("speed", speed), ("pitch", pitch), ("reverb", reverb), ("bass", bass), ("shift", shift),
                       ("lofi", lofi), ("crackle", crackle), ("rain", rain)] { UserDefaults.standard.set(v, forKey: k) }
    }

    private func start() {
        do {
            try startTap()
            isOn = true
            error = nil
            synced = !source.isEmpty
            loadNowPlaying()
            // A calm 7.5 rpm (45°/s), slowed along with the music.
            let spinner = Timer(timeInterval: 1.0 / 24, repeats: true) { [weak self] _ in
                guard let self else { return }
                spin = (spin + 45.0 / 24 * speed).truncatingRemainder(dividingBy: 360)
                let frame = Int(spin / 10) % 36
                if frame != menuFrame { menuFrame = frame }
            }
            RunLoop.main.add(spinner, forMode: .common)  // keep spinning while menus are open
            self.spinner = spinner
            if synced { pacer = .scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.pace() } }
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
        // The IO proc delivers audio at the device's rate, which can differ from the tap's reported format
        // (e.g. 44.1 kHz MacBook speakers vs a 48 kHz tap). Using the wrong one detunes and starves playback.
        var rate = asbd.mSampleRate
        size = UInt32(MemoryLayout<Double>.size)
        addr = CA.address(kAudioDevicePropertyNominalSampleRate)
        AudioObjectGetPropertyData(agg, &addr, 0, nil, &size, &rate)

        let ring = Ring(sampleRate: rate)
        let shifter = FrequencyShifter(sampleRate: rate)
        shifter.shift = shift
        self.shifter = shifter
        self.ring = ring
        try CA.check(AudioDeviceCreateIOProcIDWithBlock(&proc, agg, nil) { _, input, _, _, _ in
            ring.write(input, nonInterleaved: nonInterleaved)
        }, "Couldn't read tap")

        // Ring → frequency shift → time/pitch → reverb → bass + lo-fi → speakers. TimePitch pulls faster/slower than live depending on speed.
        let fmt = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2)!
        let node = AVAudioSourceNode(format: fmt) { _, _, frames, out in
            ring.read(out, Int(frames))
            let bufs = UnsafeMutableAudioBufferListPointer(out)
            shifter.process(bufs[0].mData!.assumingMemoryBound(to: Float.self),
                            bufs[1].mData!.assumingMemoryBound(to: Float.self), frames: Int(frames))
            return noErr
        }
        self.node = node
        av.attach(node)
        av.connect(node, to: timePitch, format: fmt)
        av.connect(timePitch, to: verb, format: fmt)
        av.connect(verb, to: eq, format: fmt)
        av.connect(eq, to: av.mainMixerNode, format: fmt)

        // Crackle (and rain, connected in init) go straight to the mixer, so they aren't slowed down or washed out by the reverb.
        let ambience = Ambience(sampleRate: rate)
        ambience.crackle = Float(crackle / 100)
        self.ambience = ambience
        let ambienceNode = AVAudioSourceNode(format: fmt) { _, _, frames, out in
            let bufs = UnsafeMutableAudioBufferListPointer(out)
            ambience.render(bufs[0].mData!.assumingMemoryBound(to: Float.self),
                            bufs[1].mData!.assumingMemoryBound(to: Float.self), frames: Int(frames))
            return noErr
        }
        self.ambienceNode = ambienceNode
        av.attach(ambienceNode)
        av.connect(ambienceNode, to: av.mainMixerNode, fromBus: 0, toBus: av.mainMixerNode.nextAvailableInputBus, format: fmt)
        try av.start()
        if let rainLoop {
            rainPlayer.scheduleBuffer(rainLoop, at: nil, options: .loops)
            rainPlayer.play()
        }
        try CA.check(AudioDeviceStart(agg, proc), "Couldn't start tap")
    }

    /// Slowed audio drains slower than the app plays it. Within a song we just fall behind (the buffer holds
    /// 3 minutes); the app is paused at song changes (see nowPlaying) and, as a last resort, when the backlog
    /// nears the limit. Each pause costs a short fade dip, so they're kept rare. The app is muted anyway.
    private func pace() {
        guard let ring else { return }
        let backlog = ring.backlog
        if !pausedSource, backlog > 150 {
            if tell("pause") { pausedSource = true } else { synced = false; pacer?.invalidate() }
        } else if pausedSource, backlog < 1 {
            if restartTrack { _ = tell("set player position to 0") }
            ring.resume()
            _ = tell("play")
            pausedSource = false
            restartTrack = false
        }
    }

    /// Works for scriptable players (Spotify, Music…). Fails for others, e.g. browsers, which stay live.
    private func tell(_ command: String) -> Bool {
        Engine.script(source, command) != nil
    }

    static func script(_ app: String, _ command: String) -> NSAppleEventDescriptor? {
        var err: NSDictionary?
        let result = NSAppleScript(source: "tell application id \"\(app)\" to \(command)")?.executeAndReturnError(&err)
        return err == nil ? result : nil
    }

    private func stop() {
        pacer?.invalidate()
        pacer = nil
        spinner?.invalidate()
        spinner = nil
        if pausedSource { _ = tell("play") }
        pausedSource = false
        restartTrack = false
        synced = false
        if let proc {
            AudioDeviceStop(agg, proc)
            AudioDeviceDestroyIOProcID(agg, proc)
        }
        proc = nil
        if agg != kAudioObjectUnknown { AudioHardwareDestroyAggregateDevice(agg) }
        if tap != kAudioObjectUnknown { AudioHardwareDestroyProcessTap(tap) }
        agg = AudioObjectID(kAudioObjectUnknown)
        tap = AudioObjectID(kAudioObjectUnknown)
        rainPlayer.stop()
        av.stop()
        if let node { av.detach(node) }
        if let ambienceNode { av.detach(ambienceNode) }
        node = nil
        ambienceNode = nil
        ambience = nil
        ring = nil
        shifter = nil
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
