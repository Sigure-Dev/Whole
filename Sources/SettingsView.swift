import SwiftUI
import UIKit

// MARK: - 設定ストア

final class Settings: ObservableObject {
    static let shared = Settings()
    private let ud = UserDefaults.standard

    @Published var appearance: Int {
        didSet { ud.set(appearance, forKey: "settings.appearance") }
    }
    @Published var accentIndex: Int {
        didSet { ud.set(accentIndex, forKey: "settings.accentIndex") }
    }
    @Published var hapticsOn: Bool {
        didSet { ud.set(hapticsOn, forKey: "settings.hapticsOn") }
    }
    @Published var soundOn: Bool {
        didSet { ud.set(soundOn, forKey: "settings.soundOn") }
    }
    @Published var homeColumns: Int {
        didSet { ud.set(homeColumns, forKey: "settings.homeColumns") }
    }

    private init() {
        appearance = ud.object(forKey: "settings.appearance") as? Int ?? 0
        accentIndex = ud.object(forKey: "settings.accentIndex") as? Int ?? 0
        hapticsOn = ud.object(forKey: "settings.hapticsOn") as? Bool ?? true
        soundOn = ud.object(forKey: "settings.soundOn") as? Bool ?? true
        homeColumns = ud.object(forKey: "settings.homeColumns") as? Int ?? 3
    }

    var colorScheme: ColorScheme? {
        switch appearance {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }

    static let accentColors: [(name: String, color: Color)] = [
        ("シー", Color(red: 0.15, green: 0.62, blue: 0.87)),
        ("ブルー", Color(red: 0.04, green: 0.52, blue: 1.00)),
        ("グリーン", Color(red: 0.20, green: 0.78, blue: 0.35)),
        ("パープル", Color(red: 0.69, green: 0.32, blue: 0.87)),
        ("オレンジ", Color(red: 1.00, green: 0.58, blue: 0.00)),
        ("ピンク", Color(red: 1.00, green: 0.18, blue: 0.33)),
    ]

    var accentColor: Color {
        guard Settings.accentColors.indices.contains(accentIndex) else {
            return Settings.accentColors[0].color
        }
        return Settings.accentColors[accentIndex].color
    }

    func reset() {
        appearance = 0
        accentIndex = 0
        hapticsOn = true
        soundOn = true
        homeColumns = 3
        UIApplication.shared.setAlternateIconName(nil) { _ in }
    }
}

// MARK: - アイコン候補

struct IconVariant: Identifiable {
    let name: String
    let alternateName: String? // nil = デフォルトに戻す
    let previewAsset: String
    var id: String { name }

    static let all: [IconVariant] = [
        IconVariant(name: "デフォルト", alternateName: nil, previewAsset: "IconPreview-Default"),
        IconVariant(name: "ヨコ", alternateName: "AppIcon-Yoko", previewAsset: "IconPreview-Yoko"),
        IconVariant(name: "ヨコヨコ", alternateName: "AppIcon-YokoYoko", previewAsset: "IconPreview-YokoYoko"),
    ]
}

// MARK: - 設定画面

struct SettingsView: View {
    @ObservedObject private var settings = Settings.shared
    @State private var iconRefresh = 0
    @State private var iconErrorText: String? = nil
    @State private var showIconError = false
    @State private var showResetConfirm = false

    var body: some View {
        Form {
            appearanceSection
            iconSection
            behaviorSection
            homeSection
            aboutSection
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 72)
        }
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        .alert("アイコンを変更できません", isPresented: $showIconError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(iconErrorText ?? "")
        }
        .alert("設定をリセットしますか?", isPresented: $showResetConfirm) {
            Button("リセット", role: .destructive) { settings.reset() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("外観・アイコン・動作設定を初期状態に戻します。\nメモなどのデータは消えません。")
        }
    }

    // MARK: アピアランス

    private var appearanceSection: some View {
        Section(header: Text("アピアランス")) {
            Picker("外観モード", selection: $settings.appearance) {
                Text("システム").tag(0)
                Text("ライト").tag(1)
                Text("ダーク").tag(2)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("アクセントカラー")
                HStack(spacing: 16) {
                    ForEach(Settings.accentColors.indices, id: \.self) { i in
                        Button {
                            settings.accentIndex = i
                            haptic(.light)
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Settings.accentColors[i].color)
                                    .frame(width: 34, height: 34)
                                if settings.accentIndex == i {
                                    Circle()
                                        .strokeBorder(Color.primary.opacity(0.6), lineWidth: 1.5)
                                        .frame(width: 42, height: 42)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: アプリアイコン

    private var iconSection: some View {
        Section(
            header: Text("アプリアイコン"),
            footer: Text("変更するとiOSの確認ダイアログが表示されます。ホーム画面で反映をご確認ください。")
        ) {
            iconGrid(current: currentIconName(iconRefresh))
        }
    }

    private func currentIconName(_: Int) -> String? {
        UIApplication.shared.alternateIconName
    }

    private func iconGrid(current: String?) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                ForEach(IconVariant.all) { v in
                    let isCurrent = (v.alternateName == nil) ? (current == nil) : (current == v.alternateName)
                    Button {
                        applyIcon(v)
                    } label: {
                        VStack(spacing: 6) {
                            Image(v.previewAsset)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .strokeBorder(
                                            isCurrent ? Color.appAccent : Color.secondary.opacity(0.25),
                                            lineWidth: isCurrent ? 2.5 : 1
                                        )
                                )
                                .overlay(alignment: .bottomTrailing) {
                                    if isCurrent {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.body)
                                            .foregroundColor(Color.appAccent)
                                            .background(Circle().fill(Color(.systemBackground)))
                                            .offset(x: 4, y: 4)
                                    }
                                }
                            Text(v.name)
                                .font(.caption2)
                                .foregroundColor(isCurrent ? Color.appAccent : .primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func applyIcon(_ variant: IconVariant) {
        haptic(.medium)
        UIApplication.shared.setAlternateIconName(variant.alternateName) { error in
            DispatchQueue.main.async {
                if let error = error {
                    iconErrorText = error.localizedDescription
                    showIconError = true
                } else {
                    iconRefresh += 1
                }
            }
        }
    }

    // MARK: 動作

    private var behaviorSection: some View {
        Section(header: Text("動作")) {
            Toggle("ハプティクス(振動)", isOn: $settings.hapticsOn)
            Toggle("効果音(タイマー終了)", isOn: $settings.soundOn)
        }
    }

    // MARK: ホーム画面

    private var homeSection: some View {
        Section(header: Text("ホーム画面")) {
            Picker("カードの列数", selection: $settings.homeColumns) {
                Text("2列").tag(2)
                Text("3列").tag(3)
                Text("4列").tag(4)
            }
        }
    }

    // MARK: 情報

    private var aboutSection: some View {
        Section(header: Text("情報")) {
            HStack {
                Text("バージョン")
                Spacer()
                Text("v\(AppInfo.version) (\(AppInfo.build))")
                    .foregroundColor(.secondary)
            }
            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                Text("設定をリセット")
            }
        }
    }
}
