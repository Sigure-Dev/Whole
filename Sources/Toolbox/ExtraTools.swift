import SwiftUI
import Network
import CoreMotion
import CryptoKit

// MARK: - 追加ツール(Network / Security / Hardware)

/// ネットワーク接続状態(NWPathMonitor)
private struct NetworkStateView: View {
    @State private var pathType = "確認中…"
    @State private var constrained = "—"
    @State private var expensive = "—"
    @State private var monitor: NWPathMonitor?
    @State private var dnsOK = "—"

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ToolSection(title: "接続状態", icon: "antenna.radiowaves.left.and.right") {
                    KeyValueRow(key: "経路", value: pathType, mono: true)
                    KeyValueRow(key: "低データモード", value: constrained)
                    KeyValueRow(key: "従量制限", value: expensive)
                    KeyValueRow(key: "DNS到達", value: dnsOK)
                }
                Text("監視は画面を開いている間だけ動作します")
                    .font(.system(size: 11)).foregroundColor(.secondary)
            }
            .padding(12)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear { start() }
        .onDisappear {
            monitor?.cancel()
            monitor = nil
        }
    }

    private func start() {
        let m = NWPathMonitor()
        monitor = m
        m.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                switch path.usesInterfaceType(.wifi) {
                case true: pathType = "Wi-Fi"
                default:
                    if path.usesInterfaceType(.cellular) { pathType = "モバイル通信" }
                    else if path.usesInterfaceType(.wiredEthernet) { pathType = "有線" }
                    else { pathType = path.status == .satisfied ? "接続あり" : "オフライン" }
                }
                constrained = path.isConstrained ? "ON" : "OFF"
                expensive = path.isExpensive ? "ON" : "OFF"
            }
        }
        m.start(queue: .global(qos: .utility))
        // DNS到達テスト
        URLSession.shared.dataTask(with: URL(string: "https://example.com")!) { _, resp, err in
            DispatchQueue.main.async {
                dnsOK = (resp as? HTTPURLResponse != nil) ? "OK" : (err == nil ? "OK" : "失敗")
            }
        }.resume()
    }
}

/// 簡易スピードテスト(ダウンロード実測)
private struct SpeedTestView: View {
    @State private var running = false
    @State private var mbps: Double?
    @State private var detail = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ToolSection(title: "ダウンロード計測", icon: "speedometer") {
                    if let m = mbps {
                        Text(String(format: "%.1f Mbps", m))
                            .font(.system(size: 26, weight: .bold, design: .monospaced))
                            .frame(maxWidth: .infinity)
                    }
                    if !detail.isEmpty {
                        Text(detail).font(.system(size: 11)).foregroundColor(.secondary)
                    }
                    Button {
                        run()
                    } label: {
                        if running {
                            HStack { ProgressView(); Text("計測中…") }
                                .font(.system(size: 13, weight: .semibold))
                        } else {
                            Label("計測開始", systemImage: "play.fill")
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.appAccent.opacity(0.18)))
                    .disabled(running)
                }
            }
            .padding(12)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private func run() {
        guard let url = URL(string: "https://speed.cloudflare.com/__down?bytes=5000000") else { return }
        running = true
        mbps = nil
        detail = "5MBをダウンロードして実測…"
        let start = CFAbsoluteTimeGetCurrent()
        URLSession.shared.dataTask(with: url) { data, resp, err in
            defer { DispatchQueue.main.async { running = false } }
            let secs = CFAbsoluteTimeGetCurrent() - start
            if let data = data, secs > 0 {
                let bits = Double(data.count) * 8
                let m = bits / secs / 1_000_000
                DispatchQueue.main.async {
                    mbps = m
                    detail = "\(data.count / 1024)KB / \(String(format: "%.2f", secs))秒"
                    ModuleRuntime.shared.appendLog(String(format: "network: %.1f Mbps", m))
                }
            } else {
                DispatchQueue.main.async {
                    detail = "エラー: \(err?.localizedDescription ?? "不明")"
                }
            }
        }.resume()
    }
}

/// AES-GCM暗号化ツール
private struct AESCipherView: View {
    @State private var mode = 0 // 0=暗号化 1=復号
    @State private var input = ""
    @State private var password = ""
    @State private var output = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ToolSection(title: "AES-256-GCM", icon: "lock.rotation") {
                    Picker("", selection: $mode) {
                        Text("暗号化").tag(0)
                        Text("復号").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: mode) { _ in output = "" }
                    TextField(mode == 0 ? "平文" : "base64データ", text: $input)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(8)
                        .frame(minHeight: 56, alignment: .top)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.tertiarySystemFill)))
                    SecureField("パスワード", text: $password)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.tertiarySystemFill)))
                    Button {
                        process()
                    } label: {
                        Text(mode == 0 ? "暗号化" : "復号")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.appAccent.opacity(0.18)))
                    }
                    .buttonStyle(.plain)
                }
                if !output.isEmpty {
                    ToolSection(title: "結果", icon: "doc.text") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(output)
                                .font(.system(size: 11, design: .monospaced))
                                .textSelection(.enabled)
                        }
                        Button {
                            UIPasteboard.general.string = output
                        } label: {
                            Label("コピー", systemImage: "doc.on.doc")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(12)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private func derivedKey() -> SymmetricKey {
        let hash = SHA256.hash(data: Data(password.utf8))
        return SymmetricKey(data: hash)
    }

    private func process() {
        guard !password.isEmpty else {
            output = "パスワードを入力してください"
            return
        }
        let key = derivedKey()
        do {
            if mode == 0 {
                let sealed = try AES.GCM.seal(Data(input.utf8), using: key)
                guard let combined = sealed.combined else {
                    output = "シール失敗"
                    return
                }
                output = combined.base64EncodedString()
            } else {
                guard let data = Data(base64Encoded: input.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                    output = "base64が不正です"
                    return
                }
                let box = try AES.GCM.SealedBox(combined: data)
                let plain = try AES.GCM.open(box, using: key)
                output = String(data: plain, encoding: .utf8) ?? "(バイナリ \(plain.count)B)"
            }
        } catch {
            output = "エラー: \(error.localizedDescription)"
        }
    }
}

/// パスワード強度チェック
private struct StrengthCheckView: View {
    @State private var password = ""
    @State private var result: (bits: Int, verdict: String, color: Color)?

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ToolSection(title: "パスワード", icon: "shield.lefthalf.filled") {
                    SecureField("パスワード", text: $password)
                        .font(.system(size: 13, design: .monospaced))
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.tertiarySystemFill)))
                        .onChange(of: password) { _ in evaluate() }
                    if let r = result {
                        Text("\(r.bits) bits")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .frame(maxWidth: .infinity)
                        Text(r.verdict)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(r.color)
                            .frame(maxWidth: .infinity)
                    }
                    Text("文字種別ごとの組み合わせ爆発から概算(実際の強度は使い方次第)")
                        .font(.system(size: 10.5)).foregroundColor(.secondary)
                }
            }
            .padding(12)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private func evaluate() {
        guard !password.isEmpty else {
            result = nil
            return
        }
        var pool = 0
        if password.range(of: "[a-z]", options: .regularExpression) != nil { pool += 26 }
        if password.range(of: "[A-Z]", options: .regularExpression) != nil { pool += 26 }
        if password.range(of: "[0-9]", options: .regularExpression) != nil { pool += 10 }
        if password.range(of: "[^a-zA-Z0-9]", options: .regularExpression) != nil { pool += 32 }
        guard pool > 0 else {
            result = (0, "構成なし", .orange)
            return
        }
        let bits = Int(Double(password.count) * log2(Double(pool)))
        let verdict: String
        let color: Color
        switch bits {
        case ..<40: verdict = "弱い"; color = .red
        case ..<60: verdict = "まあまあ"; color = .orange
        case ..<80: verdict = "強い"; color = .yellow
        default: verdict = "非常に強い"; color = .green
        }
        result = (bits, verdict, color)
    }
}

/// 歩数計(CMPedometer)
private struct PedometerView: View {
    @State private var steps: Int?
    @State private var distance: Double?
    @State private var status = ""
    private let pedometer = CMPedometer()

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ToolSection(title: "今日の歩数", icon: "figure.walk") {
                    if let s = steps {
                        Text("\(s) 歩")
                            .font(.system(size: 26, weight: .bold, design: .monospaced))
                            .frame(maxWidth: .infinity)
                        if let d = distance {
                            KeyValueRow(key: "距離", value: String(format: "%.0f m", d))
                        }
                    } else {
                        Text(status.isEmpty ? "更新ボタンで取得" : status)
                            .font(.system(size: 12)).foregroundColor(.secondary)
                    }
                    Button {
                        query()
                    } label: {
                        Label("更新", systemImage: "arrow.clockwise")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.appAccent.opacity(0.18)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear { query() }
    }

    private func query() {
        guard CMPedometer.isStepCountingAvailable() else {
            status = "この端末は歩数カウント非対応"
            return
        }
        let auth = CMPedometer.authorizationStatus()
        if auth == .notDetermined {
            status = "モーション権限の要求中…"
        } else if auth == .denied || auth == .restricted {
            status = "モーション権限が拒否されています(設定 > プライバシー)"
            return
        }
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        pedometer.queryPedometerData(from: start, to: Date()) { data, err in
            DispatchQueue.main.async {
                if let data = data {
                    steps = data.numberOfSteps.intValue
                    distance = data.distance?.doubleValue
                    status = ""
                } else {
                    status = "エラー: \(err?.localizedDescription ?? "不明")"
                }
            }
        }
    }
}

// MARK: - モジュール登録

let networkState = ToolboxModule(
    id: "network.state", title: "接続状態", summary: "経路・制限・DNS監視",
    icon: "antenna.radiowaves.left.and.right", category: .network, permissions: [],
    makeView: { AnyView(NetworkStateView()) }
)

let networkSpeed = ToolboxModule(
    id: "network.speed", title: "スピードテスト", summary: "ダウンロード実測",
    icon: "speedometer", category: .network, permissions: [],
    makeView: { AnyView(SpeedTestView()) }
)

let securityAES = ToolboxModule(
    id: "security.aes", title: "AES暗号", summary: "AES-256-GCM暗号化",
    icon: "lock.rotation", category: .security, permissions: [],
    makeView: { AnyView(AESCipherView()) }
)

let securityStrength = ToolboxModule(
    id: "security.strength", title: "強度チェック", summary: "パスワードの推定強度",
    icon: "shield.lefthalf.filled", category: .security, permissions: [],
    makeView: { AnyView(StrengthCheckView()) }
)

let hardwarePedometer = ToolboxModule(
    id: "hardware.pedometer", title: "歩数計", summary: "今日の歩数・距離",
    icon: "figure.walk", category: .hardware,
    permissions: [
        PermissionRequirement(name: "モーション", detail: "歩数取得に必要") {
            CMPedometer.authorizationStatus() == .authorized ? .granted : .denied
        }
    ],
    makeView: { AnyView(PedometerView()) }
)
