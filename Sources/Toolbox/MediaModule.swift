import SwiftUI
import AVFoundation
import CoreHaptics
import PhotosUI
import UniformTypeIdentifiers
import ImageIO

// MARK: - Media モジュール

/// トーンジェネレーター(AVAudioEngine + 正弦波)
private struct ToneToolView: View {
    @State private var frequency: Double = 440
    @State private var volume: Double = 0.3
    @State private var playing = false
    @State private var player: TonePlayer?

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ToolSection(title: "トーン", icon: "speaker.wave.3") {
                    HStack {
                        Text("\(Int(frequency)) Hz").font(.system(size: 12, design: .monospaced))
                        Slider(value: $frequency, in: 20...8000, step: 1)
                            .onChange(of: frequency) { _ in player?.setFrequency(frequency) }
                    }
                    HStack {
                        Text("音量").font(.system(size: 12))
                        Slider(value: $volume, in: 0...1)
                            .onChange(of: volume) { _ in player?.setVolume(Float(volume)) }
                    }
                    Button {
                        toggle()
                    } label: {
                        Label(playing ? "停止" : "再生", systemImage: playing ? "stop.fill" : "play.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.appAccent.opacity(0.18)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onDisappear { stop() }
    }

    private func toggle() {
        playing ? stop() : play()
        playing.toggle()
    }

    private func play() {
        if player == nil { player = TonePlayer() }
        do {
            try player?.start(frequency: frequency, volume: Float(volume))
        } catch {
            playing = false
        }
    }

    private func stop() {
        player?.stop()
    }
}

/// 正弦波プレイヤー(離脱時に確実に停止して省電力)
final class TonePlayer {
    private let engine = AVAudioEngine()
    private var node: AVAudioSourceNode?
    private var attached = false
    private var phase: Double = 0
    private var frequency: Double = 440
    private var amplitude: Float = 0.3
    private var sampleRate: Double = 44100

    func start(frequency: Double, volume: Float) throws {
        self.frequency = frequency
        self.amplitude = volume
        guard !engine.isRunning else { return }
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        sampleRate = format.sampleRate
        if !attached {
            let n = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList in
                guard let self = self else { return noErr }
                let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
                for buf in abl {
                    guard let data = buf.mData else { continue }
                    let f = data.assumingMemoryBound(to: Float.self)
                    let count = Int(buf.mDataByteSize) / MemoryLayout<Float>.size
                    for i in 0..<count {
                        f[i] = self.amplitude * Float(sin(self.phase))
                        self.phase += 2 * .pi * self.frequency / self.sampleRate
                        if self.phase > 2 * .pi { self.phase -= 2 * .pi }
                    }
                }
                return noErr
            }
            node = n
            engine.attach(n)
            engine.connect(n, to: engine.mainMixerNode, format: format)
            attached = true
        }
        try engine.start()
    }

    func setFrequency(_ f: Double) { frequency = f }
    func setVolume(_ v: Float) { amplitude = v }

    func stop() {
        engine.stop()
    }
}

/// 触覚パターン(CoreHaptics)
private struct HapticPatternView: View {
    @State private var engine: CHHapticEngine?
    @State private var supported = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if !supported {
                    ToolSection(title: "非対応", icon: "exclamationmark.triangle") {
                        Text("この端末はCoreHaptics非対応です").font(.system(size: 12)).foregroundColor(.secondary)
                    }
                } else {
                    ToolSection(title: "パターン再生", icon: "waveform") {
                        VStack(spacing: 8) {
                            patternButton("短打", pattern: .short)
                            patternButton("ロング", pattern: .long)
                            patternButton("心拍", pattern: .heartbeat)
                            patternButton("スイープ", pattern: .sweep)
                        }
                    }
                }
            }
            .padding(12)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onDisappear { engine?.stop() }
    }

    private func patternButton(_ title: String, pattern: HapticPatternKind) -> some View {
        Button {
            play(pattern)
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.appAccent.opacity(0.15)))
        }
        .buttonStyle(.plain)
    }

    private enum HapticPatternKind { case short, long, heartbeat, sweep }

    private func play(_ kind: HapticPatternKind) {
        do {
            if engine == nil { engine = try CHHapticEngine() }
            try engine?.start()
            let events: [CHHapticEvent]
            switch kind {
            case .short:
                events = [CHHapticEvent(eventType: .hapticTransient, parameters: [], relativeTime: 0)]
            case .long:
                events = [CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                ], relativeTime: 0, duration: 0.6)]
            case .heartbeat:
                events = [
                    CHHapticEvent(eventType: .hapticTransient, parameters: [], relativeTime: 0),
                    CHHapticEvent(eventType: .hapticTransient, parameters: [], relativeTime: 0.18),
                    CHHapticEvent(eventType: .hapticTransient, parameters: [], relativeTime: 1.0),
                    CHHapticEvent(eventType: .hapticTransient, parameters: [], relativeTime: 1.18),
                ]
            case .sweep:
                events = [
                    CHHapticEvent(eventType: .hapticContinuous, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.2),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1),
                    ], relativeTime: 0, duration: 0.8),
                ]
            }
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            // 再生失敗は無視(ツール)
        }
    }
}

/// 画面の明るさ
private struct BrightnessView: View {
    @State private var brightness = UIScreen.main.brightness

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ToolSection(title: "明るさ", icon: "sun.max") {
                    Text("\(Int(brightness * 100))%")
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    Slider(value: Binding(
                        get: { brightness },
                        set: {
                            brightness = $0
                            UIScreen.main.brightness = $0
                        }
                    ), in: 0...1)
                    Text("アプリを閉じても端末設定が優先されます")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
            }
            .padding(12)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

/// EXIFビューア(PHPicker・権限不要)
private struct EXIFViewerView: View {
    @State private var showPicker = false
    @State private var entries: [(key: String, value: String)] = []
    @State private var fileName: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ToolSection(title: "写真を選択", icon: "photo") {
                    Button {
                        showPicker = true
                    } label: {
                        Label("ピッカーを開く", systemImage: "photo.on.rectangle")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.appAccent.opacity(0.18)))
                    }
                    .buttonStyle(.plain)
                    Text("PHPickerは写真ライブラリ権限が不要です")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
                if !entries.isEmpty {
                    ToolSection(title: "EXIF / メタデータ \(fileName)", icon: "info.circle") {
                        ForEach(entries.indices, id: \.self) { i in
                            KeyValueRow(key: entries[i].key, value: entries[i].value, mono: true)
                        }
                    }
                }
            }
            .padding(12)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .sheet(isPresented: $showPicker) {
            EXIFPhotoPicker { data in
                parse(data)
            }
        }
    }

    private func parse(_ data: Data) {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [String: Any] else { return }
        var out: [(String, String)] = []
        func flatten(_ dict: [String: Any], prefix: String) {
            for (k, v) in dict.sorted(by: { $0.key < $1.key }) {
                if let sub = v as? [String: Any] {
                    flatten(sub, prefix: prefix.isEmpty ? k : "\(prefix).\(k)")
                } else {
                    out.append((prefix.isEmpty ? k : "\(prefix).\(k)", "\(v)"))
                }
            }
        }
        flatten(props, prefix: "")
        entries = out
    }
}

private struct EXIFPhotoPicker: UIViewControllerRepresentable {
    var onPick: (Data) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (Data) -> Void
        init(onPick: @escaping (Data) -> Void) { self.onPick = onPick }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider else { return }
            provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, _ in
                guard let url, let data = try? Data(contentsOf: url) else { return }
                DispatchQueue.main.async { self.onPick(data) }
            }
        }
    }
}

// MARK: - モジュール登録

let mediaTone = ToolboxModule(
    id: "media.tone", title: "トーン生成", summary: "20Hz〜8kHz 正弦波",
    icon: "speaker.wave.3", category: .media, permissions: [],
    makeView: { AnyView(ToneToolView()) }
)

let mediaHapticPattern = ToolboxModule(
    id: "media.haptic", title: "触覚パターン", summary: "CoreHaptics波形",
    icon: "waveform", category: .media, permissions: [],
    makeView: { AnyView(HapticPatternView()) }
)

let mediaBrightness = ToolboxModule(
    id: "media.brightness", title: "明るさ", summary: "画面輝度の直接制御",
    icon: "sun.max", category: .media, permissions: [],
    makeView: { AnyView(BrightnessView()) }
)

let mediaEXIF = ToolboxModule(
    id: "media.exif", title: "EXIFビューア", summary: "写真のメタデータ解析",
    icon: "info.circle", category: .media, permissions: [],
    makeView: { AnyView(EXIFViewerView()) }
)
