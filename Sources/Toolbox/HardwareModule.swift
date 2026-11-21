import SwiftUI
import CoreMotion
import CoreLocation
import os

// MARK: - Hardware モジュール

/// デバイス情報
private struct DeviceInfoToolView: View {
    @State private var machine = Self.machineValue()

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ToolSection(title: "端末", icon: "iphone") {
                    KeyValueRow(key: "モデル識別子", value: machine, mono: true)
                    KeyValueRow(key: "推定名称", value: Self.friendlyName(machine), mono: false)
                    KeyValueRow(key: "iOS", value: UIDevice.current.systemVersion)
                    KeyValueRow(key: "名称", value: UIDevice.current.name)
                    KeyValueRow(key: "画面", value: "\(Int(UIScreen.main.bounds.width))×\(Int(UIScreen.main.bounds.height)) @\(Int(UIScreen.main.scale))x")
                }
                ToolSection(title: "リソース", icon: "cpu") {
                    KeyValueRow(key: "CPUコア", value: "\(ProcessInfo.processInfo.processorCount)")
                    KeyValueRow(key: "実メモリ", value: ByteCountFormatter.string(fromByteCount: Int64(ProcessInfo.processInfo.physicalMemory), countStyle: .binary))
                    KeyValueRow(key: "物理メモリ空き", value: ByteCountFormatter.string(fromByteCount: Int64(os_proc_available_memory()), countStyle: .binary))
                    diskRows
                }
            }
            .padding(12)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear { machine = Self.machineValue() }
    }

    @ViewBuilder private var diskRows: some View {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        if let values = try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]) {
            KeyValueRow(key: "ディスク空き", value: ByteCountFormatter.string(fromByteCount: values.volumeAvailableCapacityForImportantUsage ?? 0, countStyle: .binary))
            KeyValueRow(key: "ディスク全体", value: ByteCountFormatter.string(fromByteCount: Int64(values.volumeTotalCapacity ?? 0), countStyle: .binary))
        }
    }

    static func machineValue() -> String {
        var sys = utsname()
        uname(&sys)
        return withUnsafePointer(to: &sys.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }

    static func friendlyName(_ machine: String) -> String {
        let map: [String: String] = [
            "iPhone8,4": "iPhone SE", "iPhone12,8": "iPhone SE2", "iPhone14,6": "iPhone SE3",
            "iPhone13,1": "iPhone 12 mini", "iPhone13,2": "iPhone 12", "iPhone13,3": "iPhone 12 Pro",
            "iPhone13,4": "iPhone 12 Pro Max", "iPhone14,4": "iPhone 13 mini", "iPhone14,5": "iPhone 13",
            "iPhone14,2": "iPhone 13 Pro", "iPhone14,3": "iPhone 13 Pro Max",
            "iPhone14,7": "iPhone 14", "iPhone14,8": "iPhone 14 Plus",
            "iPhone15,2": "iPhone 14 Pro", "iPhone15,3": "iPhone 14 Pro Max",
            "iPhone15,4": "iPhone 15", "iPhone15,5": "iPhone 15 Plus",
            "iPhone16,1": "iPhone 15 Pro", "iPhone16,2": "iPhone 15 Pro Max",
            "iPhone16,2x": "", "iPhone17,3": "iPhone 16", "iPhone17,4": "iPhone 16 Plus",
            "iPhone17,1": "iPhone 16 Pro", "iPhone17,2": "iPhone 16 Pro Max",
        ]
        return map[machine] ?? machine
    }
}

/// バッテリー
private struct BatteryToolView: View {
    @State private var level = 0
    @State private var stateText = ""
    @State private var lowPower = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ToolSection(title: "バッテリー", icon: "battery.100") {
                    Text("\(level)%")
                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    KeyValueRow(key: "状態", value: stateText)
                    KeyValueRow(key: "低電力モード", value: lowPower ? "ON" : "OFF")
                    Text("UIBatteryView等の内部APIは使わず公開情報のみ表示")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
            }
            .padding(12)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear {
            UIDevice.current.isBatteryMonitoringEnabled = true
            refresh()
        }
        .onDisappear { UIDevice.current.isBatteryMonitoringEnabled = false }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)) { _ in refresh() }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification)) { _ in refresh() }
    }

    private func refresh() {
        let d = UIDevice.current
        level = Int(max(0, d.batteryLevel) * 100)
        lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        switch d.batteryState {
        case .charging: stateText = "充電中"
        case .full: stateText = "満充電"
        case .unplugged: stateText = "電池駆動"
        default: stateText = "不明"
        }
    }
}

/// モーションセンサー(離脱時に停止 → 省電力)
private struct MotionToolView: View {
    @State private var accX: Double = 0
    @State private var accY: Double = 0
    @State private var accZ: Double = 0
    @State private var gyroX: Double = 0
    @State private var gyroY: Double = 0
    @State private var gyroZ: Double = 0
    @State private var pitch: Double = 0
    @State private var roll: Double = 0
    @State private var running = false

    private let motion = CMMotionManager()

    private var interval: TimeInterval {
        ModuleRuntime.shared.lightweightMode ? 0.25 : 0.05
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ToolSection(title: "加速度 (g)", icon: "arrow.up.arrow.down") {
                    valueGrid([("X", accX), ("Y", accY), ("Z", accZ)])
                }
                ToolSection(title: "ジャイロ (rad/s)", icon: "rotate.3d") {
                    valueGrid([("X", gyroX), ("Y", gyroY), ("Z", gyroZ)])
                }
                ToolSection(title: "傾き", icon: "level") {
                    KeyValueRow(key: "Pitch", value: String(format: "%.1f°", pitch))
                    KeyValueRow(key: "Roll", value: String(format: "%.1f°", roll))
                }
                Button {
                    running ? stop() : start()
                    running.toggle()
                } label: {
                    Label(running ? "停止" : "計測開始", systemImage: running ? "stop.fill" : "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.appAccent.opacity(0.18)))
                }
                .buttonStyle(.plain)
                Text(ModuleRuntime.shared.lightweightMode ? "軽量モード: 更新間隔 \(Int(interval * 1000))ms" : "更新間隔 \(Int(interval * 1000))ms")
                    .font(.system(size: 11)).foregroundColor(.secondary)
            }
            .padding(12)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear { start(); running = true }
        .onDisappear { stop(); running = false }
    }

    private func valueGrid(_ items: [(String, Double)]) -> some View {
        HStack {
            ForEach(items, id: \.0) { item in
                VStack(spacing: 2) {
                    Text(item.0).font(.system(size: 10)).foregroundColor(.secondary)
                    Text(String(format: "%.2f", item.1))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func start() {
        guard motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = interval
        motion.startDeviceMotionUpdates(to: .main) { dm, _ in
            guard let dm = dm else { return }
            accX = dm.userAcceleration.x
            accY = dm.userAcceleration.y
            accZ = dm.userAcceleration.z
            gyroX = dm.rotationRate.x
            gyroY = dm.rotationRate.y
            gyroZ = dm.rotationRate.z
            pitch = dm.attitude.pitch * 180 / .pi
            roll = dm.attitude.roll * 180 / .pi
        }
        ModuleRuntime.shared.appendLog("hardware: motion start (\(Int(interval * 1000))ms)")
    }

    private func stop() {
        motion.stopDeviceMotionUpdates()
    }
}

/// コンパス(CLLocationManager heading)
private struct CompassToolView: View {
    @State private var heading: Double = 0
    @State private var status = ""
    private let manager = CLLocationManager()
    @State private var delegateBox: CompassDelegate?

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ToolSection(title: "方位", icon: "safari") {
                    ZStack {
                        Circle().stroke(Color.appAccent.opacity(0.25), lineWidth: 8)
                            .frame(width: 140, height: 140)
                        VStack {
                            Text(String(format: "%.0f°", heading))
                                .font(.system(size: 30, weight: .bold, design: .monospaced))
                            Text(cardinal(heading))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.appAccent)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    KeyValueRow(key: "権限", value: status)
                }
                Text("北向きに端末を平たく持ってください")
                    .font(.system(size: 11)).foregroundColor(.secondary)
            }
            .padding(12)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear { start() }
        .onDisappear {
            manager.stopUpdatingHeading()
            ModuleRuntime.shared.appendLog("hardware: compass stop")
        }
    }

    private func cardinal(_ deg: Double) -> String {
        let dirs = ["北", "北東", "東", "南東", "南", "南西", "西", "北西"]
        let idx = Int(((deg + 22.5).truncatingRemainder(dividingBy: 360)) / 45)
        return dirs[max(0, idx)]
    }

    private func start() {
        let box = CompassDelegate { h, auth in
            if let h = h { heading = h }
            if let auth = auth {
                switch auth {
                case .authorizedAlways, .authorizedWhenInUse: status = "許可"
                case .denied, .restricted: status = "拒否(設定で許可してください)"
                case .notDetermined:
                    status = "要求中…"
                    manager.requestWhenInUseAuthorization()
                @unknown default: status = "不明"
                }
            }
        }
        delegateBox = box
        manager.delegate = box
        manager.headingFilter = 2
        let auth = CLLocationManager().authorizationStatus
        if auth == .notDetermined {
            manager.requestWhenInUseAuthorization()
            status = "要求中…"
        }
        manager.startUpdatingHeading()
        ModuleRuntime.shared.appendLog("hardware: compass start")
    }
}

final class CompassDelegate: NSObject, CLLocationManagerDelegate {
    let onUpdate: (Double?, CLAuthorizationStatus?) -> Void
    init(onUpdate: @escaping (Double?, CLAuthorizationStatus?) -> Void) { self.onUpdate = onUpdate }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        onUpdate(newHeading.magneticHeading, nil)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        onUpdate(nil, manager.authorizationStatus)
    }
}

// MARK: - モジュール登録

let hardwareDevice = ToolboxModule(
    id: "hardware.device", title: "デバイス情報", summary: "機種・メモリ・ディスク",
    icon: "iphone", category: .hardware, permissions: [],
    makeView: { AnyView(DeviceInfoToolView()) }
)

let hardwareBattery = ToolboxModule(
    id: "hardware.battery", title: "バッテリー", summary: "残量・状態・低電力",
    icon: "battery.100", category: .hardware, permissions: [],
    makeView: { AnyView(BatteryToolView()) }
)

let hardwareMotion = ToolboxModule(
    id: "hardware.motion", title: "モーション", summary: "加速度・ジャイロ・傾き",
    icon: "move.3d", category: .hardware, permissions: [],
    makeView: { AnyView(MotionToolView()) }
)

let hardwareCompass = ToolboxModule(
    id: "hardware.compass", title: "コンパス", summary: "磁北方角",
    icon: "safari", category: .hardware,
    permissions: [
        PermissionRequirement(name: "位置情報", detail: "方位表示に必要") {
            PermissionCenter.location() == .granted ? .granted : .denied
        }
    ],
    makeView: { AnyView(CompassToolView()) }
)
