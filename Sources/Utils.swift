import SwiftUI
import UIKit

// MARK: - ハプティクス

func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
    guard Settings.shared.hapticsOn else { return }
    UIImpactFeedbackGenerator(style: style).impactOccurred()
}

func notifyHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType = .success) {
    guard Settings.shared.hapticsOn else { return }
    UINotificationFeedbackGenerator().notificationOccurred(type)
}

// MARK: - アプリ情報

enum AppInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}

// MARK: - テーマカラー

extension Color {
    /// 設定で選択したアクセントカラー(設定 > アピアランスで変更可能)
    static var appAccent: Color { Settings.shared.accentColor }
}

// MARK: - 数値の表示整形

extension Double {
    /// 計算機・変換結果の表示用。整数なら小数部を省き、極端な値は指数表記にする。
    var prettyString: String {
        if self == 0 { return "0" }
        let a = abs(self)
        if a >= 1e12 || a < 1e-9 {
            return String(format: "%.6e", self)
        }
        if self == rounded() {
            return String(Int64(self))
        }
        var s = String(format: "%.10f", self)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }
}

// MARK: - 文字列ユーティリティ

extension String {
    var base64Encoded: String? {
        data(using: .utf8)?.base64EncodedString()
    }
    var base64Decoded: String? {
        Data(base64Encoded: self).flatMap { String(data: $0, encoding: .utf8) }
    }
    var urlEncoded: String? {
        addingPercentEncoding(withAllowedCharacters: .alphanumerics)
    }
    var urlDecoded: String? {
        removingPercentEncoding
    }
}

// MARK: - キーボードを閉じる

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}
