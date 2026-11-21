import SwiftUI
import CoreLocation
import CoreNFC

// MARK: - モジュールカテゴリ

enum ModuleCategory: String, CaseIterable, Identifiable {
    case tools = "Tools"
    case network = "Network"
    case nfc = "NFC"
    case security = "Security"
    case developer = "Developer"
    case media = "Media"
    case hardware = "Hardware"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .tools: return "wrench.and.screwdriver"
        case .network: return "wifi"
        case .nfc: return "dot.radiowaves.left.and.right"
        case .security: return "lock.shield"
        case .developer: return "hammer"
        case .media: return "photo.on.rectangle.angled"
        case .hardware: return "memorychip"
        }
    }

    var color: Color {
        switch self {
        case .tools: return Color(red: 0.96, green: 0.62, blue: 0.14)
        case .network: return Color(red: 0.10, green: 0.55, blue: 0.95)
        case .nfc: return Color(red: 0.10, green: 0.72, blue: 0.40)
        case .security: return Color(red: 0.95, green: 0.30, blue: 0.38)
        case .developer: return Color(red: 0.98, green: 0.55, blue: 0.05)
        case .media: return Color(red: 0.62, green: 0.36, blue: 0.92)
        case .hardware: return Color(red: 0.05, green: 0.70, blue: 0.65)
        }
    }

    var summary: String {
        switch self {
        case .tools: return "電卓・変換・QR・メモ・時間"
        case .network: return "接続・HTTP・DNS"
        case .nfc: return "タグ読み取り・IDm"
        case .security: return "Keychain・ハッシュ・暗号"
        case .developer: return "ビルド情報・署名・検証"
        case .media: return "音・触覚・画像情報"
        case .hardware: return "センサー・電源・端末"
        }
    }
}

// MARK: - 権限要件

struct PermissionRequirement: Identifiable {
    let name: String
    let detail: String
    let statusCheck: () -> PermissionStatus
    var id: String { name }
}

enum PermissionStatus {
    case granted
    case denied
    case unknown

    var label: String {
        switch self {
        case .granted: return "許可"
        case .denied: return "制限あり"
        case .unknown: return "未確認"
        }
    }

    var color: Color {
        switch self {
        case .granted: return .green
        case .denied: return .orange
        case .unknown: return .gray
        }
    }
}

// MARK: - モジュール定義

struct ToolboxModule: Identifiable {
    let id: String
    let title: String
    let summary: String
    let icon: String
    let category: ModuleCategory
    var permissions: [PermissionRequirement]
    /// 遅延生成:画面を開いた瞬間までビューは生成されない
    let makeView: () -> AnyView
}

// MARK: - モジュールレジストリ

enum ModuleRegistry {
    /// 全モジュール。makeView は遅延なのでここでは軽量(メタデータのみ)。
    static let modules: [ToolboxModule] = [
        // Tools(旧実績ビュー)
        toolsCalculator,
        toolsUnits,
        toolsQRGen,
        toolsQRScan,
        toolsText,
        toolsColor,
        toolsNotes,
        toolsRandom,
        toolsCounter,
        toolsStopwatch,
        toolsTimer,
        toolsWorldClock,
        toolsFlashlight,
        // Network
        networkConnection,
        networkHTTP,
        networkDNS,
        networkState,
        networkSpeed,
        // NFC
        nfcTagReader,
        // Security
        securityKeychain,
        securityHash,
        securityPassword,
        securityAES,
        securityStrength,
        // Developer
        developerBuildInfo,
        developerHaptics,
        developerURLScheme,
        developerFonts,
        developerSigner,
        // Media
        mediaTone,
        mediaHapticPattern,
        mediaBrightness,
        mediaEXIF,
        // Hardware
        hardwareDevice,
        hardwareBattery,
        hardwareMotion,
        hardwareCompass,
        hardwarePedometer,
    ]

    static func modules(in category: ModuleCategory) -> [ToolboxModule] {
        modules.filter { $0.category == category }
    }

    static func search(_ query: String) -> [ToolboxModule] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        return modules.filter {
            $0.title.localizedCaseInsensitiveContains(q)
                || $0.summary.localizedCaseInsensitiveContains(q)
                || $0.category.rawValue.localizedCaseInsensitiveContains(q)
        }
    }
}

// MARK: - モジュールランタイム(ライフサイクル)

final class ModuleRuntime: ObservableObject {
    static let shared = ModuleRuntime()

    enum State: String {
        case idle, active, released
    }

    struct LogEntry: Identifiable {
        let id = UUID()
        let time: Date
        let text: String
    }

    @Published private(set) var states: [String: State] = [:]
    @Published private(set) var log: [LogEntry] = []

    /// 軽量モード:センサーの更新間隔を落とし、不要な初期化を抑制する
    @Published var lightweightMode: Bool {
        didSet { UserDefaults.standard.set(lightweightMode, forKey: "runtime.lightweight") }
    }

    private init() {
        lightweightMode = UserDefaults.standard.bool(forKey: "runtime.lightweight")
    }

    func transition(_ moduleID: String, to newState: State) {
        DispatchQueue.main.async {
            self.states[moduleID] = newState
            self.appendLog("\(moduleID) → \(newState.rawValue)")
        }
    }

    var activeIDs: [String] {
        states.filter { $0.value == .active }.map(\.key).sorted()
    }

    func appendLog(_ text: String) {
        DispatchQueue.main.async {
            self.log.insert(LogEntry(time: Date(), text: text), at: 0)
            if self.log.count > 40 { self.log.removeLast(self.log.count - 40) }
        }
    }
}

// MARK: - 権限センター

enum PermissionCenter {
    static func location() -> PermissionStatus {
        guard CLLocationManager.locationServicesEnabled() else { return .denied }
        switch CLLocationManager().authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: return .granted
        case .denied, .restricted: return .denied
        case .notDetermined: return .unknown
        @unknown default: return .unknown
        }
    }

    static var nfcSupported: Bool {
        NFCNDEFReaderSession.readingAvailable
    }
}

// MARK: - 共通UI(小型コンポーネント)

struct ModuleIcon: View {
    let systemName: String
    let color: Color
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.28).fill(color))
    }
}

/// モジュール内のツール用コンテナ(セクション型)
struct ToolSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.appAccent)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
    }
}

struct KeyValueRow: View {
    let key: String
    let value: String
    var mono = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 12, weight: .medium, design: mono ? .monospaced : .default))
                .multilineTextAlignment(.trailing)
                .contextMenu { Text(value) }
        }
    }
}
