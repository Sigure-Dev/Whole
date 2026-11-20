import SwiftUI

// MARK: - データモデル

struct Feature: Identifiable {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let view: AnyView
    var id: String { title }
}

struct FeatureSectionData: Identifiable {
    let header: String
    let features: [Feature]
    var id: String { header }
}

enum FeatureData {
    static let convertCalc: [Feature] = [
        Feature(icon: "plus.forwardslash.minus", title: "電卓", subtitle: "四則演算・パーセント", color: .orange, view: AnyView(CalculatorView())),
        Feature(icon: "arrow.left.arrow.right", title: "単位変換", subtitle: "長さ・重さ・温度・データなど", color: .blue, view: AnyView(UnitConverterView())),
    ]
    static let convertCode: [Feature] = [
        Feature(icon: "qrcode", title: "QRコード生成", subtitle: "テキストからQRを作成", color: .gray, view: AnyView(QRGeneratorView())),
        Feature(icon: "qrcode.viewfinder", title: "QRスキャナー", subtitle: "カメラでQR・バーコード読み取り", color: .teal, view: AnyView(QRScannerView())),
        Feature(icon: "textformat", title: "テキストツール", subtitle: "文字数・Base64・変換", color: .purple, view: AnyView(TextToolView())),
        Feature(icon: "paintpalette", title: "カラーツール", subtitle: "カラーピッカーとHEX", color: .pink, view: AnyView(ColorToolView())),
    ]
    static let toolsBasics: [Feature] = [
        Feature(icon: "note.text", title: "メモ", subtitle: "端末内に保存", color: .orange, view: AnyView(NotesView())),
        Feature(icon: "dice", title: "ランダム", subtitle: "ダイス・コイン・乱数", color: .brown, view: AnyView(RandomToolsView())),
        Feature(icon: "number", title: "カウンタ", subtitle: "タップして数を数える", color: .mint, view: AnyView(CounterView())),
    ]
    static let toolsLightSound: [Feature] = [
        Feature(icon: "speaker.wave.3", title: "トーン発生", subtitle: "テスト音を鳴らす", color: .cyan, view: AnyView(ToneGeneratorView())),
        Feature(icon: "flashlight.on.fill", title: "懐中電灯", subtitle: "ライト点灯・明るさ調整", color: .yellow, view: AnyView(FlashlightView())),
    ]
    static let measureTime: [Feature] = [
        Feature(icon: "stopwatch", title: "ストップウォッチ", subtitle: "ラップ付き計測", color: .green, view: AnyView(StopwatchView())),
        Feature(icon: "timer", title: "タイマー", subtitle: "カウントダウン", color: .red, view: AnyView(TimerToolView())),
        Feature(icon: "clock", title: "世界時計", subtitle: "主要都市の現在時刻", color: .indigo, view: AnyView(WorldClockView())),
    ]
    static let measureDevice: [Feature] = [
        Feature(icon: "iphone", title: "デバイス情報", subtitle: "機種・バッテリー・容量", color: .blue, view: AnyView(DeviceInfoView())),
        Feature(icon: "move.3d", title: "モーション", subtitle: "加速度・ジャイロ・水準器", color: .orange, view: AnyView(MotionView())),
        Feature(icon: "safari", title: "コンパス", subtitle: "方位を表示", color: .red, view: AnyView(CompassView())),
    ]

    static let homeSections: [FeatureSectionData] = [
        FeatureSectionData(header: "変換・コード", features: convertCalc + convertCode),
        FeatureSectionData(header: "ツール", features: toolsBasics + toolsLightSound),
        FeatureSectionData(header: "計測・デバイス", features: measureTime + measureDevice),
    ]
}

// MARK: - 共通パーツ

struct FeatureIcon: View {
    let systemName: String
    let color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 34, height: 34)
            .background(RoundedRectangle(cornerRadius: 8).fill(color))
    }
}

struct FeatureRow: View {
    let feature: Feature

    var body: some View {
        HStack(spacing: 12) {
            FeatureIcon(systemName: feature.icon, color: feature.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                Text(feature.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - ルート(Liquid Glass ドックバー)

struct RootView: View {
    @State private var tab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            tabContent
            GlassTabBar(selection: $tab)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    @ViewBuilder private var tabContent: some View {
        ZStack {
            switch tab {
            case 0:
                HomeTab().transition(.opacity)
            case 1:
                FeatureListTab(title: "ツール", sections: [
                    FeatureSectionData(header: "ツール", features: FeatureData.toolsBasics),
                    FeatureSectionData(header: "音と光", features: FeatureData.toolsLightSound),
                ])
                .transition(.opacity)
            case 2:
                FeatureListTab(title: "計測", sections: [
                    FeatureSectionData(header: "時間", features: FeatureData.measureTime),
                    FeatureSectionData(header: "デバイス", features: FeatureData.measureDevice),
                ])
                .transition(.opacity)
            case 3:
                FeatureListTab(title: "変換", sections: [
                    FeatureSectionData(header: "計算", features: FeatureData.convertCalc),
                    FeatureSectionData(header: "コード・テキスト", features: FeatureData.convertCode),
                ])
                .transition(.opacity)
            default:
                SettingsView().transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: tab)
    }
}

// MARK: - ホーム(ランチャー)

struct HomeTab: View {
    @ObservedObject private var settings = Settings.shared

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(FeatureData.homeSections) { section in
                        Text(section.header)
                            .font(.headline)
                            .padding(.horizontal, 4)
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: settings.homeColumns),
                            spacing: 12
                        ) {
                            ForEach(section.features) { f in
                                NavigationLink(destination: f.view) {
                                    HomeCard(feature: f)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 6)
                .padding(.bottom, 90)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Whole")
        }
        .navigationViewStyle(.stack)
    }
}

struct HomeCard: View {
    let feature: Feature

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FeatureIcon(systemName: feature.icon, color: feature.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(feature.subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
    }
}

// MARK: - リスト型タブ

struct FeatureListTab: View {
    let title: String
    let sections: [FeatureSectionData]

    var body: some View {
        NavigationView {
            List {
                ForEach(sections) { section in
                    Section(header: Text(section.header)) {
                        ForEach(section.features) { f in
                            NavigationLink {
                                f.view
                            } label: {
                                FeatureRow(feature: f)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 72)
            }
            .navigationTitle(title)
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - Liquid Glass タブバー

struct GlassTabBar: View {
    @Binding var selection: Int
    @Namespace private var ns
    @ObservedObject private var settings = Settings.shared

    private let items: [(icon: String, label: String)] = [
        ("house.fill", "ホーム"),
        ("wrench.and.screwdriver.fill", "ツール"),
        ("timer", "計測"),
        ("arrow.left.arrow.right", "変換"),
        ("gearshape.fill", "設定"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                tabButton(i)
            }
        }
        .padding(6)
        .background(glassBackground)
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
    }

    private func tabButton(_ i: Int) -> some View {
        let selected = selection == i
        return Button {
            guard selection != i else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                selection = i
            }
            haptic(.light)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: items[i].icon)
                    .font(.system(size: 20, weight: .semibold))
                    .frame(height: 24)
                Text(items[i].label)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(selected ? Color.appAccent : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background {
                if selected {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.appAccent.opacity(0.34), Color.appAccent.opacity(0.14)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 0.8)
                        )
                        .matchedGeometryEffect(id: "tabPill", in: ns)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var glassBackground: some View {
        Capsule()
            .fill(.ultraThinMaterial)
            .overlay(
                Capsule().strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.65), Color.white.opacity(0.08)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            )
            .shadow(color: Color.black.opacity(0.22), radius: 14, x: 0, y: 8)
    }
}
