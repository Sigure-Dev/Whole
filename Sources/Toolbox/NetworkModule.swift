import SwiftUI
import Foundation
import SystemConfiguration

// MARK: - Network モジュール

/// 接続情報:インターフェース / IP / SSID
private struct ConnectionInfoView: View {
    @State private var interfaces: [(name: String, ip: String)] = []
    @State private var ssid: String = "—"
    @State private var locationNote: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ToolSection(title: "Wi-Fi", icon: "wifi") {
                    KeyValueRow(key: "SSID", value: ssid, mono: true)
                    KeyValueRow(key: "位置情報権限", value: PermissionCenter.location().label)
                    if !locationNote.isEmpty {
                        Text(locationNote)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                ToolSection(title: "インターフェース / IP", icon: "number.square") {
                    if interfaces.isEmpty {
                        Text("取得ボタンを押してください")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    ForEach(interfaces.indices, id: \.self) { i in
                        KeyValueRow(key: interfaces[i].name, value: interfaces[i].ip, mono: true)
                    }
                }
                Button {
                    refresh()
                } label: {
                    Label("再取得", systemImage: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.appAccent.opacity(0.15)))
                }
                .buttonStyle(.plain)
            }
            .padding(12)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear { refresh() }
    }

    private func refresh() {
        interfaces = Self.localAddresses()
        ssid = Self.currentSSID() ?? "取得できません"
        locationNote = PermissionCenter.location() == .granted
            ? ""
            : "SSIDの取得には位置情報の許可が必要です(iOSの仕様)"
        ModuleRuntime.shared.appendLog("network: addresses \(interfaces.count)件")
    }

    static func localAddresses() -> [(name: String, ip: String)] {
        var result: [(String, String)] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return [] }
        defer { freeifaddrs(ifaddr) }
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let p = ptr {
            let ifa = p.pointee
            if let sa = ifa.ifa_addr {
                let family = sa.pointee.sa_family
                if family == AF_INET || family == AF_INET6 {
                    var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(sa, socklen_t(sa.pointee.sa_len), &host, socklen_t(host.count),
                                   nil, 0, NI_NUMERICHOST) == 0 {
                        var ip = String(cString: host)
                        // IPv6はスコープID(%en0)を分離
                        if let r = ip.firstIndex(of: "%") { ip = String(ip[..<r]) }
                        let name = String(cString: ifa.ifa_name)
                        result.append((name, ip))
                    }
                }
            }
            ptr = ifa.ifa_next
        }
        return result
    }

    static func currentSSID() -> String? {
        guard let ifs = CNCopySupportedInterfaces() as? [String] else { return nil }
        for ifn in ifs {
            if let dict = CNCopyCurrentNetworkInfo(ifn as CFString) as? [String: Any],
               let s = dict[kCNNetworkInfoKeySSID as String] as? String {
                return s
            }
        }
        return nil
    }
}

/// HTTPテスター
private struct HTTPTesterView: View {
    enum Method: String, CaseIterable { case GET, POST, HEAD, PUT, DELETE }

    @State private var urlString = "https://httpbin.org/get"
    @State private var method: Method = .GET
    @State private var bodyText = ""
    @State private var running = false
    @State private var result: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ToolSection(title: "リクエスト", icon: "paperplane") {
                    TextField("https://…", text: $urlString)
                        .font(.system(size: 12, design: .monospaced))
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.tertiarySystemFill)))
                    Picker("", selection: $method) {
                        ForEach(Method.allCases, id: \.self) { Text($0.rawValue).font(.system(size: 12)) }
                    }
                    .pickerStyle(.segmented)
                    if method == .POST || method == .PUT {
                        TextField("body", text: $bodyText)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(8)
                            .frame(height: 64, alignment: .top)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color(.tertiarySystemFill)))
                    }
                    Button {
                        run()
                    } label: {
                        if running {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Label("送信", systemImage: "paperplane.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.appAccent.opacity(0.18)))
                    .disabled(running)
                }
                if !result.isEmpty {
                    ToolSection(title: "レスポンス", icon: "doc.text") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(result)
                                .font(.system(size: 11, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .padding(12)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private func run() {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespaces)) else {
            result = "URLが不正です"
            return
        }
        running = true
        result = ""
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        req.httpMethod = method.rawValue
        if method == .POST || method == .PUT { req.httpBody = bodyText.data(using: .utf8) }
        let start = CFAbsoluteTimeGetCurrent()
        URLSession.shared.dataTask(with: req) { data, resp, error in
            defer { DispatchQueue.main.async { self.running = false } }
            let elapsed = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            var out = "経過: \(elapsed)ms\n"
            if let http = resp as? HTTPURLResponse {
                out += "status: \(http.statusCode)\n"
                out += "\n-- headers --\n"
                for (k, v) in http.allHeaderFields.sorted(by: { "\($0.key)" < "\($1.key)" }) {
                    out += "\(k): \(v)\n"
                }
            } else if let error = error {
                out += "error: \(error.localizedDescription)\n"
            }
            if let data = data, let text = String(data: data.prefix(3000), encoding: .utf8) {
                out += "\n-- body(先頭3000B) --\n\(text)"
            }
            DispatchQueue.main.async {
                self.result = out
                ModuleRuntime.shared.appendLog("network: HTTP \(method.rawValue) → \(elapsed)ms")
            }
        }.resume()
    }
}

/// DNS解決
private struct DNSLookupView: View {
    @State private var host = "github.com"
    @State private var results: [String] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ToolSection(title: "ホスト名", icon: "globe") {
                    TextField("example.com", text: $host)
                        .font(.system(size: 12, design: .monospaced))
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.tertiarySystemFill)))
                    Button {
                        results = Self.resolve(host.trimmingCharacters(in: .whitespaces))
                        ModuleRuntime.shared.appendLog("network: DNS \(host) → \(results.count)件")
                    } label: {
                        Label("解決", systemImage: "magnifyingglass")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.appAccent.opacity(0.18)))
                    }
                    .buttonStyle(.plain)
                }
                ToolSection(title: "結果", icon: "list.bullet") {
                    if results.isEmpty {
                        Text("未解決")
                            .font(.system(size: 12)).foregroundColor(.secondary)
                    }
                    ForEach(results, id: \.self) { Text($0).font(.system(size: 12, design: .monospaced)) }
                }
            }
            .padding(12)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    static func resolve(_ host: String) -> [String] {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        var res: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &res) == 0, let first = res else { return [] }
        defer { freeaddrinfo(res) }
        var out: [String] = []
        var ptr: UnsafeMutablePointer<addrinfo>? = first
        while let p = ptr {
            var hostBuf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(p.pointee.ai_addr, p.pointee.ai_addrlen, &hostBuf, socklen_t(hostBuf.count),
                           nil, 0, NI_NUMERICHOST) == 0 {
                out.append(String(cString: hostBuf))
            }
            ptr = p.pointee.ai_next
        }
        return out
    }
}

// MARK: - モジュール登録

let networkConnection = ToolboxModule(
    id: "network.connection", title: "接続情報", summary: "IP・SSID・インターフェース",
    icon: "wifi", category: .network,
    permissions: [
        PermissionRequirement(name: "位置情報(Wi-Fi SSID用)", detail: "iOSの仕様でSSID取得に必要") {
            PermissionCenter.location() == .granted
        }
    ],
    makeView: { AnyView(ConnectionInfoView()) }
)

let networkHTTP = ToolboxModule(
    id: "network.http", title: "HTTPテスター", summary: "GET/POST・ヘッダー・応答",
    icon: "paperplane", category: .network, permissions: [],
    makeView: { AnyView(HTTPTesterView()) }
)

let networkDNS = ToolboxModule(
    id: "network.dns", title: "DNS解決", summary: "ホスト→IPアドレス一覧",
    icon: "globe", category: .network, permissions: [],
    makeView: { AnyView(DNSLookupView()) }
)
