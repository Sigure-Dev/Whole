import SwiftUI
import Darwin

struct DeviceInfoView: View {
    @State private var batteryLevelText = "不明"
    @State private var batteryStateText = "不明"

    var body: some View {
        Form {
            Section(header: Text("デバイス")) {
                row("名前", UIDevice.current.name)
                row("機種", UIDevice.current.model)
                row("機種ID", machineID())
                row("OS", "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
                row("識別子", UIDevice.current.identifierForVendor?.uuidString ?? "-")
            }

            Section(header: Text("バッテリー")) {
                row("レベル", batteryLevelText)
                row("状態", batteryStateText)
            }

            Section(header: Text("メモリ・ストレージ")) {
                row("物理メモリ", gb(Double(ProcessInfo.processInfo.physicalMemory)))
                row("CPUコア", "\(ProcessInfo.processInfo.processorCount)")
                row("空き容量", storageInfo?.free ?? "-")
                row("合計容量", storageInfo?.total ?? "-")
            }

            Section(header: Text("ディスプレイ")) {
                let b = UIScreen.main.bounds
                let scale = UIScreen.main.scale
                row("論理サイズ", "\(Int(b.width)) × \(Int(b.height)) pt")
                row("スケール", "x\(Int(scale))")
                row("ピクセル", "\(Int(b.width * scale)) × \(Int(b.height * scale)) px")
            }
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 72)
        }
        .navigationTitle("デバイス情報")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { refreshBattery() }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private func refreshBattery() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        batteryLevelText = level >= 0 ? "\(Int(round(level * 100)))%" : "不明"
        switch UIDevice.current.batteryState {
        case .charging: batteryStateText = "充電中"
        case .full: batteryStateText = "満充電"
        case .unplugged: batteryStateText = "放電中"
        default: batteryStateText = "不明"
        }
    }

    private var storageInfo: (free: String, total: String)? {
        let url = URL(fileURLWithPath: "/")
        guard let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]) else {
            return nil
        }
        let free = Double(values.volumeAvailableCapacityForImportantUsage ?? 0)
        let total = Double(values.volumeTotalCapacity ?? 0)
        return (gb(free), gb(total))
    }

    private func gb(_ bytes: Double) -> String {
        String(format: "%.1f GB", bytes / 1_000_000_000)
    }

    private func machineID() -> String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        guard size > 0 else { return "-" }
        var value = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &value, &size, nil, 0)
        return String(cString: value)
    }
}
