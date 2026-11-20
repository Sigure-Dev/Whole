import SwiftUI
import AVFoundation

final class TonePlayer: ObservableObject {
    @Published var isPlaying = false

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    private var phase: Float = 0
    private var attached = false

    var volume: Float = 0.5 {
        didSet { engine.mainMixerNode.outputVolume = volume }
    }

    func play(frequency: Double) {
        if !attached {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            attached = true
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            if !engine.isRunning { try engine.start() }
            player.stop()
            let buffer = makeBuffer(frequency: frequency)
            player.scheduleBuffer(buffer, at: nil, options: .loops)
            if !player.isPlaying { player.play() }
            isPlaying = true
        } catch {
            isPlaying = false
        }
    }

    func stop() {
        player.stop()
        engine.stop()
        isPlaying = false
    }

    private func makeBuffer(frequency: Double) -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        if let data = buffer.floatChannelData?[0] {
            let delta = Float(2 * Double.pi * frequency / format.sampleRate)
            for i in 0..<Int(frames) {
                data[i] = 0.8 * sin(phase)
                phase += delta
                if phase >= 2 * Float.pi { phase -= 2 * Float.pi }
            }
        }
        return buffer
    }
}

struct ToneGeneratorView: View {
    @ObservedObject private var settings = Settings.shared
    @StateObject private var player = TonePlayer()
    @State private var frequency: Double = 440
    @State private var volume: Double = 0.5

    var body: some View {
        VStack(spacing: 24) {
            Text(String(format: "%.1f Hz", frequency))
                .font(.system(size: 44, weight: .semibold, design: .monospaced))
                .monospacedDigit()

            VStack(alignment: .leading, spacing: 4) {
                Text("周波数")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: $frequency, in: 50...2000, step: 1) { editing in
                    if !editing && player.isPlaying {
                        player.play(frequency: frequency)
                    }
                }
            }
            .padding(.horizontal)

            HStack(spacing: 12) {
                presetButton("440")
                presetButton("528")
                presetButton("1000")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("音量")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: $volume, in: 0...1)
                    .onChange(of: volume) { v in
                        player.volume = Float(v)
                    }
            }
            .padding(.horizontal)

            Button {
                if player.isPlaying {
                    player.stop()
                } else {
                    player.volume = Float(volume)
                    player.play(frequency: frequency)
                    haptic(.medium)
                }
            } label: {
                Label(player.isPlaying ? "停止" : "再生", systemImage: player.isPlaying ? "stop.fill" : "play.fill")
                    .font(.headline)
                    .frame(width: 180, height: 50)
                    .background(RoundedRectangle(cornerRadius: 25).fill(player.isPlaying ? Color.red.opacity(0.85) : Color.appAccent))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)

            Text("※ 音量にご注意ください")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.bottom, 72)
        .navigationTitle("トーン発生")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { player.stop() }
    }

    private func presetButton(_ hz: String) -> some View {
        Button {
            frequency = Double(hz) ?? frequency
            if player.isPlaying { player.play(frequency: frequency) }
            haptic(.light)
        } label: {
            Text("\(hz) Hz")
                .font(.subheadline)
                .frame(width: 84, height: 36)
        }
        .buttonStyle(.bordered)
    }
}
