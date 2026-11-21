import SwiftUI

// MARK: - ランタイム(Module Runtime / Registry / Lifecycle / Permissions)

struct RuntimeTab: View {
    @ObservedObject private var runtime = ModuleRuntime.shared

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 10) {
                    registrySection
                    lifecycleSection
                    powerSection
                    permissionSection
                }
                .padding(12)
                .padding(.bottom, 84)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("ランタイム")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }

    // MARK: レジストリ

    private var registrySection: some View {
        ToolSection(title: "モジュールレジストリ", icon: "square.grid.3x3") {
            KeyValueRow(key: "登録済みツール", value: "\(ModuleRegistry.modules.count)個")
            KeyValueRow(key: "カテゴリ", value: "\(ModuleCategory.allCases.count)種")
            KeyValueRow(key: "実行中", value: runtime.activeIDs.isEmpty ? "なし" : "\(runtime.activeIDs.count)個")
            if !runtime.activeIDs.isEmpty {
                Text(runtime.activeIDs.joined(separator: ", "))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.appAccent)
            }
            Text("ツールのビューは画面を開いた瞬間に生成され、閉じると解放されます(遅延ロード)")
                .font(.system(size: 10.5))
                .foregroundColor(.secondary)
        }
    }

    // MARK: ライフサイクルログ

    private var lifecycleSection: some View {
        ToolSection(title: "ライフサイクル", icon: "clock.arrow.circlepath") {
            if runtime.log.isEmpty {
                Text("まだイベントはありません").font(.system(size: 12)).foregroundColor(.secondary)
            }
            ForEach(runtime.log.prefix(12)) { entry in
                HStack(alignment: .firstTextBaseline) {
                    Text(Self.timeFormatter.string(from: entry.time))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                    Text(entry.text)
                        .font(.system(size: 11.5, design: .monospaced))
                }
            }
        }
    }

    // MARK: 電源/軽量モード

    private var powerSection: some View {
        ToolSection(title: "電源管理", icon: "leaf") {
            Toggle(isOn: $runtime.lightweightMode) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("軽量モード")
                        .font(.system(size: 13, weight: .semibold))
                    Text("センサーの更新間隔を引き下げ、不要な処理を抑制してバッテリーを節約します")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: Color.appAccent))
        }
    }

    // MARK: 権限

    private var permissionSection: some View {
        ToolSection(title: "権限", icon: "lock.shield") {
            ForEach([
                PermissionRequirement(name: "位置情報", detail: "コンパス・SSID取得") {
                    PermissionCenter.location()
                },
                PermissionRequirement(name: "NFC", detail: "タグ読み取り") {
                    PermissionStatus(PermissionCenter.nfcSupported)
                },
            ]) { req in
                let status = req.statusCheck()
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(req.name).font(.system(size: 12.5, weight: .semibold))
                        Text(req.detail).font(.system(size: 10)).foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(status.label)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(status.color))
                }
            }
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
}

private extension PermissionStatus {
    init(_ bool: Bool) {
        self = bool ? .granted : .denied
    }
}
