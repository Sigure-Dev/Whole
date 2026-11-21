import SwiftUI
import CryptoKit

// MARK: - Security モジュール

/// Keychain 読み書き
private struct KeychainToolView: View {
    @State private var account = "whole.test"
    @State private var value = ""
    @State private var status = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ToolSection(title: "Keychain 汎用パスワード", icon: "key") {
                    KeyValueRow(key: "service", value: "WholeToolbox", mono: true)
                    TextField("account", text: $account)
                        .font(.system(size: 12, design: .monospaced))
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.tertiarySystemFill)))
                    TextField("value", text: $value)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.tertiarySystemFill)))
                    HStack(spacing: 8) {
                        smallButton("保存", "square.and.arrow.down") { save() }
                        smallButton("読込", "square.and.arrow.up") { read() }
                        smallButton("削除", "trash") { delete() }
                    }
                    if !status.isEmpty {
                        Text(status)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private func smallButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.appAccent.opacity(0.15)))
        }
        .buttonStyle(.plain)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "WholeToolbox",
            kSecAttrAccount as String: account,
        ]
    }

    private func save() {
        guard let data = value.data(using: .utf8) else { return }
        SecItemDelete(baseQuery as CFDictionary)
        var q = baseQuery
        q[kSecValueData as String] = data
        let s = SecItemAdd(q as CFDictionary, nil)
        status = s == errSecSuccess ? "保存しました" : "エラー: \(s)"
    }

    private func read() {
        var q = baseQuery
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let s = SecItemCopyMatching(q as CFDictionary, &item)
        if s == errSecSuccess, let data = item as? Data,
           let text = String(data: data, encoding: .utf8) {
            value = text
            status = "読み込みました"
        } else if s == errSecItemNotFound {
            status = "アイテムが存在しません"
        } else {
            status = "エラー: \(s)"
        }
    }

    private func delete() {
        let s = SecItemDelete(baseQuery as CFDictionary)
        status = s == errSecSuccess ? "削除しました" : (s == errSecItemNotFound ? "存在しません" : "エラー: \(s)")
    }
}

/// ハッシュ計算
private struct HashToolView: View {
    @State private var input = ""
    @State private var hashes: [String: String] = [:]

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ToolSection(title: "入力", icon: "character.cursor.ibeam") {
                    TextField("テキスト", text: $input)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.tertiarySystemFill)))
                        .onChange(of: input) { _ in compute() }
                }
                ToolSection(title: "ハッシュ", icon: "number") {
                    if hashes.isEmpty {
                        Text("入力すると自動計算")
                            .font(.system(size: 12)).foregroundColor(.secondary)
                    }
                    ForEach(["SHA256", "SHA512", "MD5"], id: \.self) { k in
                        if let v = hashes[k] {
                            KeyValueRow(key: k, value: v, mono: true)
                        }
                    }
                }
            }
            .padding(12)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private func compute() {
        guard let d = input.data(using: .utf8), !input.isEmpty else {
            hashes = [:]
            return
        }
        hashes = [
            "SHA256": SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined(),
            "SHA512": SHA512.hash(data: d).map { String(format: "%02x", $0) }.joined(),
            "MD5": Insecure.MD5.hash(data: d).map { String(format: "%02x", $0) }.joined(),
        ]
    }
}

/// パスワード生成
private struct PasswordGenView: View {
    @State private var length: Double = 16
    @State private var useUpper = true
    @State private var useLower = true
    @State private var useDigits = true
    @State private var useSymbols = true
    @State private var password = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ToolSection(title: "設定", icon: "slider.horizontal.3") {
                    HStack {
                        Text("長さ \(Int(length))").font(.system(size: 12))
                        Slider(value: $length, in: 8...64, step: 1)
                            .onChange(of: length) { _ in generate() }
                    }
                    Toggle("大文字 A-Z", isOn: $useUpper).font(.system(size: 12)).onChange(of: useUpper) { _ in generate() }
                    Toggle("小文字 a-z", isOn: $useLower).font(.system(size: 12)).onChange(of: useLower) { _ in generate() }
                    Toggle("数字 0-9", isOn: $useDigits).font(.system(size: 12)).onChange(of: useDigits) { _ in generate() }
                    Toggle("記号 !@#", isOn: $useSymbols).font(.system(size: 12)).onChange(of: useSymbols) { _ in generate() }
                }
                ToolSection(title: "生成結果", icon: "wand.and.stars") {
                    Text(password.isEmpty ? " " : password)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.tertiarySystemFill)))
                    HStack(spacing: 8) {
                        Button {
                            generate()
                        } label: {
                            Label("生成", systemImage: "arrow.clockwise")
                                .font(.system(size: 12, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.appAccent.opacity(0.18)))
                        }
                        .buttonStyle(.plain)
                        Button {
                            UIPasteboard.general.string = password
                        } label: {
                            Label("コピー", systemImage: "doc.on.doc")
                                .font(.system(size: 12, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.appAccent.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(12)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear { generate() }
    }

    private func generate() {
        var pool = ""
        if useUpper { pool += "ABCDEFGHIJKLMNOPQRSTUVWXYZ" }
        if useLower { pool += "abcdefghijklmnopqrstuvwxyz" }
        if useDigits { pool += "0123456789" }
        if useSymbols { pool += "!@#$%^&*-_=+?" }
        guard !pool.isEmpty else {
            password = ""
            return
        }
        let chars = Array(pool)
        let n = Int(length)
        var bytes = [UInt8](repeating: 0, count: n)
        let s = SecRandomCopyBytes(kSecRandomDefault, n, &bytes)
        if s != errSecSuccess {
            password = ""
            return
        }
        password = String(bytes.map { chars[Int($0) % chars.count] })
    }
}

// MARK: - モジュール登録

let securityKeychain = ToolboxModule(
    id: "security.keychain", title: "Keychain", summary: "安全な値の保存・読込",
    icon: "key", category: .security, permissions: [],
    makeView: { AnyView(KeychainToolView()) }
)

let securityHash = ToolboxModule(
    id: "security.hash", title: "ハッシュ計算", summary: "SHA256・SHA512・MD5",
    icon: "number", category: .security, permissions: [],
    makeView: { AnyView(HashToolView()) }
)

let securityPassword = ToolboxModule(
    id: "security.password", title: "パスワード生成", summary: "SecRandomで安全な生成",
    icon: "wand.and.stars", category: .security, permissions: [],
    makeView: { AnyView(PasswordGenView()) }
)
