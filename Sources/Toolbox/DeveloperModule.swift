import SwiftUI
import UIKit

// MARK: - Developer モジュール

/// ビルド/バンドル情報
private struct BuildInfoView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ToolSection(title: "バンドル", icon: "shippingbox") {
                    KeyValueRow(key: "Bundle ID", value: Bundle.main.bundleIdentifier ?? "—", mono: true)
                    KeyValueRow(key: "バージョン", value: AppInfo.version)
                    KeyValueRow(key: "ビルド", value: AppInfo.build)
                    KeyValueRow(key: "表示名", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "—")
                    KeyValueRow(key: "最小iOS", value: Bundle.main.object(forInfoDictionaryKey: "MinimumOSVersion") as? String ?? "—")
                }
                ToolSection(title: "実行環境", icon: "terminal") {
                    KeyValueRow(key: "サンドボックス", value: NSHomeDirectory(), mono: true)
                    KeyValueRow(key: "実行ファイル", value: Bundle.main.executablePath?.split(separator: "/").last.map(String.init) ?? "—", mono: true)
                    KeyValueRow(key: "稼働時間", value: String(format: "%.0f秒", ProcessInfo.processInfo.systemUptime))
                }
            }
            .padding(12)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

/// ハプティクステスト
private struct HapticTestView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ToolSection(title: "UIImpactFeedbackGenerator", icon: "hand.tap") {
                    VStack(spacing: 8) {
                        impactRow("light")
                        impactRow("medium")
                        impactRow("heavy")
                        impactRow("soft")
                        impactRow("rigid")
                    }
                }
                ToolSection(title: "通知フィードバック", icon: "bell") {
                    VStack(spacing: 8) {
                        notifyRow("success", .success)
                        notifyRow("warning", .warning)
                        notifyRow("error", .error)
                    }
                }
                ToolSection(title: "選択変更", icon: "slider.horizontal.3") {
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        Text("selectionChanged()")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.appAccent.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private func impactRow(_ name: String) -> some View {
        Button {
            let style: UIImpactFeedbackGenerator.FeedbackStyle
            switch name {
            case "light": style = .light
            case "heavy": style = .heavy
            case "soft": style = .soft
            case "rigid": style = .rigid
            default: style = .medium
            }
            haptic(style)
        } label: {
            Text("impactOccurred(\(name))")
                .font(.system(size: 12, design: .monospaced))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.appAccent.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }

    private func notifyRow(_ name: String, _ type: UINotificationFeedbackGenerator.FeedbackType) -> some View {
        Button {
            notifyHaptic(type)
        } label: {
            Text("notificationOccurred(\(name))")
                .font(.system(size: 12, design: .monospaced))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.appAccent.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }
}

/// URLスキーム起動
private struct URLSchemeView: View {
    @State private var scheme = "https://www.apple.com"
    @State private var result = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ToolSection(title: "URL", icon: "link") {
                    TextField("scheme://…", text: $scheme)
                        .font(.system(size: 12, design: .monospaced))
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.tertiarySystemFill)))
                    Button {
                        open()
                    } label: {
                        Label("開く", systemImage: "arrow.up.forward.app")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.appAccent.opacity(0.18)))
                    }
                    .buttonStyle(.plain)
                }
                if !result.isEmpty {
                    ToolSection(title: "結果", icon: "info.circle") {
                        Text(result).font(.system(size: 12)).foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private func open() {
        guard let url = URL(string: scheme.trimmingCharacters(in: .whitespaces)) else {
            result = "URLが不正です"
            return
        }
        let can = UIApplication.shared.canOpenURL(url)
        if can {
            UIApplication.shared.open(url) { ok in
                result = ok ? "開きました" : "open失敗"
            }
        } else {
            result = "canOpenURL = false(スキーム未登録または無効)"
        }
    }
}

/// フォント一覧
private struct FontListView: View {
    var body: some View {
        List {
            ForEach(UIFont.familyNames.sorted(), id: \.self) { family in
                Section(header: Text(family).font(.system(size: 12, weight: .semibold))) {
                    ForEach(UIFont.fontNames(forFamilyName: family), id: \.self) { name in
                        Text(name)
                            .font(.system(size: 13, design: .monospaced))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - モジュール登録

let developerBuildInfo = ToolboxModule(
    id: "developer.buildinfo", title: "ビルド情報", summary: "バンドル・実行環境",
    icon: "shippingbox", category: .developer, permissions: [],
    makeView: { AnyView(BuildInfoView()) }
)

let developerHaptics = ToolboxModule(
    id: "developer.haptics", title: "ハプティクス", summary: "触覚APIのテスト",
    icon: "hand.tap", category: .developer, permissions: [],
    makeView: { AnyView(HapticTestView()) }
)

let developerURLScheme = ToolboxModule(
    id: "developer.urlscheme", title: "URLスキーム", summary: "他アプリの起動",
    icon: "arrow.up.forward.app", category: .developer, permissions: [],
    makeView: { AnyView(URLSchemeView()) }
)

let developerFonts = ToolboxModule(
    id: "developer.fonts", title: "フォント一覧", summary: "端末内フォント閲覧",
    icon: "textformat", category: .developer, permissions: [],
    makeView: { AnyView(FontListView()) }
)
