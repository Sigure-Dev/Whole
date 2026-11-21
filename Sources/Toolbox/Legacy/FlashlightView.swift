import SwiftUI
import AVFoundation

struct FlashlightView: View {
    @State private var isOn = false
    @State private var level: Double = 0.8
    @Environment(\.scenePhase) private var scenePhase

    private var hasTorch: Bool {
        AVCaptureDevice.default(for: .video)?.hasTorch ?? false
    }

    var body: some View {
        VStack(spacing: 28) {
            if hasTorch {
                Button {
                    isOn.toggle()
                    apply()
                    haptic(.medium)
                } label: {
                    ZStack {
                        Circle()
                            .fill(isOn ? Color.yellow : Color(.systemGray5))
                            .frame(width: 140, height: 140)
                            .shadow(color: isOn ? .yellow.opacity(0.5) : .black.opacity(0.1), radius: 10)
                        Image(systemName: isOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .font(.system(size: 48))
                            .foregroundColor(isOn ? .black : .primary)
                    }
                }
                .buttonStyle(.plain)

                VStack(spacing: 8) {
                    HStack {
                        Text("明るさ")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(level * 100))%")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $level, in: 0.1...1)
                        .disabled(!isOn)
                        .onChange(of: level) { _ in
                            if isOn { apply() }
                        }
                }
                .padding(.horizontal, 48)

                Text(isOn ? "点灯中" : "消灯中")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "flashlight.off.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("この端末ではライトを使用できません")
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 72)
        .navigationTitle("懐中電灯")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            if isOn {
                setTorch(false)
                isOn = false
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active && isOn {
                setTorch(false)
                isOn = false
            }
        }
    }

    private func apply() {
        setTorch(isOn, level: Float(level))
    }

    private func setTorch(_ on: Bool, level: Float = 1) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            if on {
                try device.setTorchModeOn(level: max(0.1, min(1, level)))
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
        } catch {
            // 失敗時は無視
        }
    }
}
