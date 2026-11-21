import SwiftUI
import UniformTypeIdentifiers
import ZIPFoundation
import Zsign
import Darwin

// MARK: - 証明書ストア

final class SignerStore: ObservableObject {
    static let shared = SignerStore()

    @Published var p12URL: URL?
    @Published var profileURL: URL?
    @Published var password: String {
        didSet { UserDefaults.standard.set(password, forKey: "signer.password") }
    }

    private(set) var certsDir: URL

    private init() {
        password = UserDefaults.standard.string(forKey: "signer.password") ?? ""
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        certsDir = docs.appendingPathComponent("SignerCerts", isDirectory: true)
        try? FileManager.default.createDirectory(at: certsDir, withIntermediateDirectories: true)
        let p12 = certsDir.appendingPathComponent("cert.p12")
        let prof = certsDir.appendingPathComponent("profile.mobileprovision")
        if FileManager.default.fileExists(atPath: p12.path) { p12URL = p12 }
        if FileManager.default.fileExists(atPath: prof.path) { profileURL = prof }
    }

    func saveFromSecurityScoped(url: URL, as kind: String) throws -> URL {
        let dest = certsDir.appendingPathComponent(kind)
        guard url.startAccessingSecurityScopedResource() else {
            throw NSError(domain: "Signer", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "ファイルアクセスが拒否されました"])
        }
        defer { url.stopAccessingSecurityScopedResource() }
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: url, to: dest)
        return dest
    }

    var isReady: Bool { p12URL != nil && profileURL != nil && !password.isEmpty }

    /// プロファイルからバンドルIDを取得
    var profileBundleID: String? {
        guard let profileURL,
              let data = try? Data(contentsOf: profileURL) else { return nil }
        return SignerEngine.profileInfo(data)?.bundleID
    }

    var profileExpiration: Date? {
        guard let profileURL,
              let data = try? Data(contentsOf: profileURL) else { return nil }
        return SignerEngine.profileInfo(data)?.expiration
    }
}

// MARK: - 署名エンジン

enum SignerEngine {
    struct ProfileInfo {
        var bundleID: String?
        var expiration: Date?
    }

    /// mobileprovision 内のXML plistから情報を取り出す
    static func profileInfo(_ data: Data) -> ProfileInfo? {
        guard let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8)) else { return nil }
        guard start.lowerBound < end.upperBound else { return nil }
        let plistData = data.subdata(in: start.lowerBound..<end.upperBound)
        guard let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil)
                as? [String: Any] else { return nil }
        var bundleID = plist["application-identifier"] as? String
        // "TEAMID.bundle.id" 形式からteam IDを除去
        if let raw = bundleID, let dot = raw.firstIndex(of: ".") {
            bundleID = String(raw[raw.index(after: dot)...])
        }
        return ProfileInfo(
            bundleID: bundleID,
            expiration: plist["ExpirationDate"] as? Date
        )
    }

    /// Entitlements 辞書をXML plistとして書き出す
    static func writeEntitlements(profileData: Data, to url: URL) throws {
        guard let start = profileData.range(of: Data("<?xml".utf8)),
              let end = profileData.range(of: Data("</plist>".utf8)) else {
            throw NSError(domain: "Signer", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "プロファイル解析失敗"])
        }
        guard start.lowerBound < end.upperBound else {
            throw NSError(domain: "Signer", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "プロファイル解析失敗"])
        }
        let plistData = profileData.subdata(in: start.lowerBound..<end.upperBound)
        guard let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil)
                as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any] else {
            throw NSError(domain: "Signer", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Entitlementsが見つかりません"])
        }
        let out = try PropertyListSerialization.data(fromPropertyList: entitlements, format: .xml, options: 0)
        try out.write(to: url)
    }

    /// IPAを署名してIPAとして書き出す
    /// - Returns: 署名済みIPAのURL
    static func sign(
        ipaURL: URL,
        p12URL: URL,
        profileURL: URL,
        password: String,
        bundleID: String?,
        displayName: String?,
        version: String?,
        adhoc: Bool,
        progress: @escaping (String) -> Void
    ) throws -> URL {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let outDir = docs.appendingPathComponent("SignedIPAs", isDirectory: true)
        try fm.createDirectory(at: outDir, withIntermediateDirectories: true)

        let work = docs.appendingPathComponent("signing-\(UUID().uuidString.prefix(6))", isDirectory: true)
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }

        progress("IPA展開中…")
        // セキュリティスコープ付きアクセス
        let scoped = ipaURL.startAccessingSecurityScopedResource()
        defer { if scoped { ipaURL.stopAccessingSecurityScopedResource() } }
        try fm.unzipItem(at: ipaURL, to: work)

        // Payload/<X>.app を探す
        let payload = work.appendingPathComponent("Payload", isDirectory: true)
        let apps = try fm.contentsOfDirectory(at: payload, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "app" }
        guard let app = apps.first else {
            throw NSError(domain: "Signer", code: 4,
                          userInfo: [NSLocalizedDescriptionKey: "Payload内に.appが見つかりません"])
        }

        progress("Info.plist 更新中…")
        // 事前クリーンアップ(zsignは古い署名を置き換えない)
        let codeSig = app.appendingPathComponent("_CodeSignature", isDirectory: true)
        if fm.fileExists(atPath: codeSig.path) { try fm.removeItem(at: codeSig) }
        let oldProv = app.appendingPathComponent("embedded.mobileprovision")
        if fm.fileExists(atPath: oldProv.path) { try fm.removeItem(at: oldProv) }

        // Info.plist の書き換え(詳細設定)
        let infoURL = app.appendingPathComponent("Info.plist")
        if var info = try? PropertyListSerialization.propertyList(from: Data(contentsOf: infoURL), format: nil)
                as? [String: Any] {
            if let bundleID, !bundleID.isEmpty { info["CFBundleIdentifier"] = bundleID }
            if let displayName, !displayName.isEmpty { info["CFBundleDisplayName"] = displayName }
            if let version, !version.isEmpty {
                info["CFBundleShortVersionString"] = version
                info["CFBundleVersion"] = version
            }
            try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
                .write(to: infoURL)
        }

        progress("Entitlements 抽出中…")
        let profileData = try Data(contentsOf: profileURL)
        let entURL = work.appendingPathComponent("entitlements.plist")
        try writeEntitlements(profileData: profileData, to: entURL)

        // 補助ファイルをワークディレクトリへ
        let p12Copy = work.appendingPathComponent("cert.p12")
        let profCopy = work.appendingPathComponent("profile.mobileprovision")
        try fm.copyItem(at: p12URL, to: p12Copy)
        try fm.copyItem(at: profileURL, to: profCopy)

        progress("Zsign 署名中…")
        // zsignは相対パスで受ける → chdirしてから相対パス指定
        let savedCWD = fm.currentDirectoryPath
        guard chdir(work.path) == 0 else {
            throw NSError(domain: "Signer", code: 5,
                          userInfo: [NSLocalizedDescriptionKey: "作業ディレクトリへ移動できません"])
        }
        defer { chdir(savedCWD) }

        let relApp = "Payload/\(app.lastPathComponent)"
        var signed = false
        let sem = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            signed = Zsign.sign(
                appPath: relApp,
                provisionPath: "profile.mobileprovision",
                p12Path: "cert.p12",
                p12Password: password,
                entitlementsPath: "entitlements.plist",
                customIdentifier: bundleID ?? "",
                customName: displayName ?? "",
                customVersion: version ?? "",
                adhoc: adhoc,
                removeProvision: false,
                completion: { _ in sem.signal() }
            )
        }
        _ = sem.wait(timeout: .now() + 600)
        guard signed, fm.fileExists(atPath: oldProv.path) else {
            throw NSError(domain: "Signer", code: 6,
                          userInfo: [NSLocalizedDescriptionKey: "署名に失敗しました(証明書/パスワード/プロファイルを確認)"])
        }

        progress("IPA再パッケージ中…")
        let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "_")
        let outURL = outDir.appendingPathComponent("signed-\(stamp).ipa")
        if fm.fileExists(atPath: outURL.path) { try fm.removeItem(at: outURL) }
        try fm.zipItem(at: payload, to: outURL)
        ModuleRuntime.shared.appendLog("signer: signed → \(outURL.lastPathComponent)")
        return outURL
    }

    /// 端末内インストール試行(非公開API・失敗時は書き出し案内)
    static func attemptInstall(appAtPayload: URL, bundleID: String) -> String {
        guard let cls = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
              let ws = cls.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() else {
            return "LSApplicationWorkspace が取得できません"
        }
        let options = [
            "CFBundleIdentifier": bundleID,
            "AllowInstallLocalProvisioned": NSNumber(value: true),
        ] as [String: Any]
        for name in ["installApplication:withOptions:error:", "installApplication:withOptions:"] {
            let sel = NSSelectorFromString(name)
            if ws.responds(to: sel) {
                _ = ws.perform(sel, with: NSURL(fileURLWithPath: appAtPayload.path), with: options)
                return "インストール要求を送信しました(ホーム画面を確認)"
            }
        }
        return "installApplication API 不在"
    }
}

// MARK: - 署名ツールUI

private struct IPASignerView: View {
    @ObservedObject private var store = SignerStore.shared
    @State private var importKind = ""
    @State private var showCertPicker = false
    @State private var showIPAPicker = false
    @State private var ipaName = ""
    @State private var ipaURL: URL?
    @State private var bundleID = ""
    @State private var displayName = ""
    @State private var version = ""
    @State private var adhoc = false
    @State private var status = ""
    @State private var working = false
    @State private var signedURL: URL?
    @State private var shareURL: URL?

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                certSection
                ipaSection
                optionsSection
                runSection
                outputSection
            }
            .padding(12)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .fileImporter(isPresented: $showCertPicker,
                      allowedContentTypes: [UTType(filenameExtension: "p12") ?? .data,
                                            UTType(filenameExtension: "mobileprovision") ?? .data,
                                            .data],
                      allowsMultipleSelection: false)
        { result in
            handleCertImport(result)
        }
        .fileImporter(isPresented: $showIPAPicker,
                      allowedContentTypes: [UTType(filenameExtension: "ipa") ?? .archive, .archive],
                      allowsMultipleSelection: false)
        { result in
            handleIPAImport(result)
        }
        .sheet(isPresented: Binding(get: { shareURL != nil }, set: { if !$0 { shareURL = nil } })) {
            if let url = shareURL {
                ShareSheet(items: [url])
            }
        }
    }

    // MARK: 証明書

    private var certSection: some View {
        ToolSection(title: "証明書", icon: "key.fill") {
            HStack(spacing: 8) {
                smallBtn("p12 読込", store.p12URL != nil, "key") { importKind = "cert.p12"; showCertPicker = true }
                smallBtn("provision 読込", store.profileURL != nil, "doc.badge.gearshape") { importKind = "profile.mobileprovision"; showCertPicker = true }
            }
            SecureField("p12パスワード", text: $store.password)
                .font(.system(size: 12, design: .monospaced))
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(.tertiarySystemFill)))
            KeyValueRow(key: "p12", value: store.p12URL != nil ? "登録済み" : "未登録")
            KeyValueRow(key: "profile", value: store.profileURL != nil ? "登録済み" : "未登録")
            if let bid = store.profileBundleID {
                KeyValueRow(key: "profile bundle", value: bid, mono: true)
            }
            if let exp = store.profileExpiration {
                KeyValueRow(key: "有効期限", value: DateFormatter.localizedString(from: exp, dateStyle: .medium, timeStyle: .none))
            }
            KeyValueRow(key: "状態", value: store.isReady ? "署名準備完了" : "未完了")
        }
    }

    // MARK: IPA

    private var ipaSection: some View {
        ToolSection(title: "unsigned IPA", icon: "shippingbox") {
            Button {
                showIPAPicker = true
            } label: {
                Label("IPAを選択", systemImage: "square.and.arrow.down")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.appAccent.opacity(0.15)))
            }
            .buttonStyle(.plain)
            if let name = ipaName.isEmpty ? nil : ipaName {
                KeyValueRow(key: "選択中", value: name, mono: true)
            }
        }
    }

    // MARK: 詳細設定

    private var optionsSection: some View {
        ToolSection(title: "詳細設定", icon: "slider.horizontal.3") {
            field("バンドルID(空欄=元のまま・プロファイル一致推奨)", $bundleID)
            field("表示名", $displayName)
            field("バージョン", $version)
            Toggle("ad-hoc署名", isOn: $adhoc)
                .font(.system(size: 12))
            Text("バンドルIDは証明書プロファイルに登録済みのIDと一致させてください")
                .font(.system(size: 10.5)).foregroundColor(.secondary)
        }
    }

    private func field(_ placeholder: String, _ binding: Binding<String>) -> some View {
        TextField(placeholder, text: binding)
            .font(.system(size: 12, design: .monospaced))
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(.tertiarySystemFill)))
    }

    // MARK: 実行

    private var runSection: some View {
        ToolSection(title: "実行", icon: "signature") {
            Button {
                runSign()
            } label: {
                if working {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("処理中…").font(.system(size: 13, weight: .semibold))
                    }
                } else {
                    Label("署名する", systemImage: "checkmark.seal.fill")
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.appAccent.opacity(0.2)))
            .disabled(working || !store.isReady || ipaURL == nil)
            if !store.isReady {
                Text("p12・profile・パスワードを登録してください")
                    .font(.system(size: 10.5)).foregroundColor(.orange)
            }
            if !status.isEmpty {
                Text(status)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var outputSection: some View {
        Group {
            if let url = signedURL {
                ToolSection(title: "署名済み", icon: "checkmark.seal") {
                    KeyValueRow(key: "ファイル", value: url.lastPathComponent, mono: true)
                    HStack(spacing: 8) {
                        smallBtn("共有/書き出し", true, "square.and.arrow.up") { shareURL = url }
                        smallBtn("インストール試行", true, "iphone.and.arrow.down") {
                            status = SignerEngine.attemptInstall(
                                appAtPayload: url.appendingPathComponent("Payload"),
                                bundleID: bundleID.isEmpty ? (store.profileBundleID ?? "?") : bundleID
                            )
                        }
                    }
                    Text("インストールが拒否される場合(通常の証明書では不可)は、書き出したIPAを3uTools等でインストールしてください")
                        .font(.system(size: 10.5)).foregroundColor(.secondary)
                }
            }
        }
    }

    private func smallBtn(_ title: String, _ active: Bool, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundColor(active ? Color.appAccent : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.appAccent.opacity(active ? 0.15 : 0.07)))
        }
        .buttonStyle(.plain)
    }

    // MARK: ハンドラ

    private func handleCertImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        do {
            let saved = try store.saveFromSecurityScoped(url: url, as: importKind)
            if saved.lastPathComponent == "cert.p12" {
                store.p12URL = saved
            } else {
                store.profileURL = saved
                if let bid = store.profileBundleID, bundleID.isEmpty { bundleID = bid }
            }
            status = "\(saved.lastPathComponent) を登録しました"
        } catch {
            status = "読込エラー: \(error.localizedDescription)"
        }
    }

    private func handleIPAImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("import-\(UUID().uuidString.prefix(6)).ipa")
        do {
            try FileManager.default.copyItem(at: url, to: tmp)
            ipaURL = tmp
            ipaName = url.lastPathComponent
            status = "IPA読込完了"
        } catch {
            status = "IPA読込エラー: \(error.localizedDescription)"
        }
    }

    private func runSign() {
        guard let p12 = store.p12URL, let prof = store.profileURL, let ipa = ipaURL else { return }
        working = true
        status = ""
        signedURL = nil
        let bid = bundleID.isEmpty ? nil : bundleID
        let nm = displayName.isEmpty ? nil : displayName
        let ver = version.isEmpty ? nil : version
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let out = try SignerEngine.sign(
                    ipaURL: ipa,
                    p12URL: p12,
                    profileURL: prof,
                    password: store.password,
                    bundleID: bid,
                    displayName: nm,
                    version: ver,
                    adhoc: adhoc
                ) { msg in
                    DispatchQueue.main.async { status = msg }
                }
                DispatchQueue.main.async {
                    signedURL = out
                    status = "署名完了: \(out.lastPathComponent)"
                    working = false
                    notifyHaptic(.success)
                }
            } catch {
                DispatchQueue.main.async {
                    status = "エラー: \(error.localizedDescription)"
                    working = false
                    notifyHaptic(.error)
                }
            }
        }
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - モジュール登録

let developerSigner = ToolboxModule(
    id: "developer.signer", title: "IPA署名", summary: "Zsignで再署名・書き出し",
    icon: "checkmark.seal", category: .developer, permissions: [],
    makeView: { AnyView(IPASignerView()) }
)
