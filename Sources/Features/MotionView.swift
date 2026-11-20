import SwiftUI
import CoreMotion

struct Motion3: Equatable {
    var x = 0.0
    var y = 0.0
    var z = 0.0
}

final class MotionModel: ObservableObject {
    @Published var userAcc = Motion3()
    @Published var rotation = Motion3()
    @Published var gravity = Motion3()
    @Published var pitch = 0.0
    @Published var roll = 0.0
    @Published var available = true

    private let manager = CMMotionManager()

    func start() {
        guard manager.isDeviceMotionAvailable else {
            available = false
            return
        }
        manager.deviceMotionUpdateInterval = 1.0 / 30
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self = self, let motion = motion else { return }
            self.userAcc = Motion3(x: motion.userAcceleration.x, y: motion.userAcceleration.y, z: motion.userAcceleration.z)
            self.rotation = Motion3(x: motion.rotationRate.x, y: motion.rotationRate.y, z: motion.rotationRate.z)
            self.gravity = Motion3(x: motion.gravity.x, y: motion.gravity.y, z: motion.gravity.z)
            self.pitch = motion.attitude.pitch * 180 / .pi
            self.roll = motion.attitude.roll * 180 / .pi
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}

struct MotionView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case acc = "加速度"
        case gyro = "ジャイロ"
        case level = "水準器"
        var id: String { rawValue }
    }

    @StateObject private var model = MotionModel()
    @ObservedObject private var settings = Settings.shared
    @State private var tab: Tab = .acc

    var body: some View {
        VStack(spacing: 12) {
            Picker("種類", selection: $tab) {
                ForEach(Tab.allCases) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if !model.available {
                VStack(spacing: 8) {
                    Image(systemName: "move.3d")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary)
                    Text("モーションセンサーを利用できません")
                        .foregroundColor(.secondary)
                    Text("シミュレータでは動作しません")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                switch tab {
                case .acc: sensorList(values: model.userAcc, unit: "G", maxAbs: 2.0)
                case .gyro: sensorList(values: model.rotation, unit: "rad/s", maxAbs: 10.0)
                case .level: levelView
                }
            }
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
        .padding(.bottom, 72)
        .navigationTitle("モーション")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sensorList(values: Motion3, unit: String, maxAbs: Double) -> some View {
        VStack(spacing: 18) {
            sensorRow("X", values.x, unit: unit, maxAbs: maxAbs)
            sensorRow("Y", values.y, unit: unit, maxAbs: maxAbs)
            sensorRow("Z", values.z, unit: unit, maxAbs: maxAbs)
            Spacer()
        }
        .padding(.top, 20)
        .padding(.horizontal)
    }

    private func sensorRow(_ label: String, _ v: Double, unit: String, maxAbs: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.headline)
                Spacer()
                Text(String(format: "%+.3f %@", v, unit))
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5))
                    Capsule()
                        .fill(Color.appAccent)
                        .frame(width: geo.size.width * CGFloat(min(1, abs(v) / maxAbs)))
                }
            }
            .frame(height: 6)
        }
    }

    private var levelView: some View {
        VStack(spacing: 16) {
            let dx = -model.gravity.x * 120
            let dy = model.gravity.y * 120
            let len = sqrt(dx * dx + dy * dy)
            let cap = 100.0
            let clampedX = len > cap ? dx / len * cap : dx
            let clampedY = len > cap ? dy / len * cap : dy

            ZStack {
                Circle().stroke(Color(.systemGray4), lineWidth: 2).frame(width: 250, height: 250)
                Circle().stroke(Color.appAccent.opacity(0.5), lineWidth: 1.5).frame(width: 170, height: 170)
                Circle().stroke(Color.appAccent, lineWidth: 1.5).frame(width: 90, height: 90)
                Circle().fill(Color.appAccent.opacity(0.15)).frame(width: 90, height: 90)
                Circle()
                    .fill(Color.yellow)
                    .overlay(Circle().stroke(Color.orange, lineWidth: 1))
                    .frame(width: 34, height: 34)
                    .offset(x: CGFloat(clampedX), y: CGFloat(clampedY))
            }

            HStack(spacing: 24) {
                Text(String(format: "前後 %.1f°", model.pitch))
                    .monospacedDigit()
                Text(String(format: "左右 %.1f°", model.roll))
                    .monospacedDigit()
            }
            .font(.footnote)
            .foregroundColor(.secondary)

            Text("端末を水平にしてバブルを中央へ")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.top, 16)
    }
}
