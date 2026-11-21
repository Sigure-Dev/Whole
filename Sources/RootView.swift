import SwiftUI

// MARK: - ルート(Application Shell)

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
                RuntimeTab().transition(.opacity)
            default:
                SettingsView().transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: tab)
    }
}

// MARK: - ホーム(モジュールディレクトリ + 検索)

struct HomeTab: View {
    @ObservedObject private var settings = Settings.shared
    @State private var query = ""

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    searchBar
                    if query.isEmpty {
                        ForEach(ModuleCategory.allCases) { category in
                            categorySection(category)
                        }
                    } else {
                        resultSection
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 84)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Whole")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            TextField("モジュールを検索", text: $query)
                .font(.system(size: 13))
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color(.secondarySystemGroupedBackground)))
    }

    private func categorySection(_ category: ModuleCategory) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: category.icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(category.color)
                Text(category.rawValue)
                    .font(.system(size: 13, weight: .bold))
                Text(category.summary)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 2)
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: settings.homeColumns),
                spacing: 8
            ) {
                ForEach(ModuleRegistry.modules(in: category)) { module in
                    NavigationLink(destination: ModulePage(module: module)) {
                        ModuleCard(module: module)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var resultSection: some View {
        let results = ModuleRegistry.search(query)
        return VStack(alignment: .leading, spacing: 6) {
            if results.isEmpty {
                Text("「\(query)」に一致するモジュールはありません")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.top, 20)
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: settings.homeColumns),
                    spacing: 8
                ) {
                    ForEach(results) { module in
                        NavigationLink(destination: ModulePage(module: module)) {
                            ModuleCard(module: module)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - コンパクトカード

struct ModuleCard: View {
    let module: ToolboxModule

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ModuleIcon(systemName: module.icon, color: module.category.color, size: 26)
            Text(module.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
            Text(module.summary)
                .font(.system(size: 9.5))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))
    }
}

// MARK: - モジュールページ(遅延ロード + ライフサイクル)

struct ModulePage: View {
    let module: ToolboxModule
    @State private var loaded = false

    var body: some View {
        Group {
            if loaded {
                module.makeView()
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("モジュール読込中…")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(module.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !loaded else { return }
            ModuleRuntime.shared.transition(module.id, to: .active)
            // 1フレーム遅らせて実体化 = 遅延ロード
            DispatchQueue.main.async { loaded = true }
        }
        .onDisappear {
            if loaded {
                ModuleRuntime.shared.transition(module.id, to: .released)
            }
            loaded = false
        }
    }
}

// MARK: - Liquid Glass タブバー(コンパクト・アイコンのみ)

struct GlassTabBar: View {
    @Binding var selection: Int
    @Namespace private var ns

    private let icons: [String] = [
        "house.fill",
        "cpu",
        "gearshape.fill",
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(icons.indices, id: \.self) { i in
                tabButton(i)
            }
        }
        .padding(4)
        .background(glassBackground)
        .padding(.horizontal, 56)
        .padding(.bottom, 5)
    }

    private func tabButton(_ i: Int) -> some View {
        let selected = selection == i
        return Button {
            guard selection != i else { return }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                selection = i
            }
            haptic(.light)
        } label: {
            Image(systemName: icons[i])
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(selected ? Color.appAccent : .secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background {
                    if selected {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.appAccent.opacity(0.32), Color.appAccent.opacity(0.12)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .overlay(
                                Capsule().strokeBorder(Color.white.opacity(0.3), lineWidth: 0.7)
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
                        colors: [Color.white.opacity(0.6), Color.white.opacity(0.08)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
            )
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 6)
    }
}
