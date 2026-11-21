import SwiftUI
import CoreNFC

// MARK: - NFC モジュール

/// NFCタグリーダー(FeliCa / ISO14443 / ISO15693)
private struct NFCReaderView: View {
    @State private var log: [String] = []
    @State private var scanning = false
    private var sessionHolder = NFCTagSessionHolder()

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if !PermissionCenter.nfcSupported {
                    ToolSection(title: "非対応", icon: "exclamationmark.triangle") {
                        Text("この端末/証明書ではNFCが使用できません。\n(com.apple.developer.nfc.readersession.formats 権限とNFC対応端末が必要)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                } else {
                    ToolSection(title: "タグ読み取り", icon: "dot.radiowaves.left.and.right") {
                        Button {
                            startScan()
                        } label: {
                            Label(scanning ? "スキャン中…" : "スキャン開始", systemImage: "sensor.tag.radiowaves.forward")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.appAccent.opacity(0.18)))
                        }
                        .buttonStyle(.plain)
                        .disabled(scanning)
                        Text("FeliCa(Suica等)・ISO14443・ISO15693タグのUID/IDmを読み取ります")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                if !log.isEmpty {
                    ToolSection(title: "読み取り結果", icon: "list.bullet.rectangle") {
                        ForEach(log.indices, id: \.self) { i in
                            Text(log[i])
                                .font(.system(size: 12, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .padding(12)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onDisappear { sessionHolder.stop() }
    }

    private func startScan() {
        scanning = true
        sessionHolder.start { line in
            log.insert(line, at: 0)
        } onFinish: {
            scanning = false
        }
    }
}

/// NFCTagReaderSession の保持とデリゲート(本体はonDisappearで停止 → 省電力)
final class NFCTagSessionHolder: NSObject, NFCTagReaderSessionDelegate {
    private var session: NFCTagReaderSession?
    private var onLine: ((String) -> Void)?
    private var onFinish: (() -> Void)?

    func start(onLine: @escaping (String) -> Void, onFinish: @escaping () -> Void) {
        self.onLine = onLine
        self.onFinish = onFinish
        guard NFCTagReaderSession.readingAvailable else {
            onLine("NFCセッションを開始できません(権限または端末非対応)")
            onFinish()
            return
        }
        let s = NFCTagReaderSession(pollingOption: [.iso14443, .iso18092, .iso15693], delegate: self)
        s?.alertMessage = "タグをかざしてください"
        session = s
        ModuleRuntime.shared.appendLog("nfc: session start")
        s?.begin()
    }

    func stop() {
        session?.invalidate()
        session = nil
    }

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        let msg = (error as NSError).localizedDescription
        DispatchQueue.main.async {
            if !msg.contains("session terminated") && !msg.contains("ユーザ") && !msg.lowercased().contains("cancelled") {
                self.onLine?("エラー: \(msg)")
                if msg.lowercased().contains("entitlement") {
                    self.onLine?("→ 証明書にNFC権限(nfc.readersession.formats)がありません")
                }
            }
            self.session = nil
            ModuleRuntime.shared.appendLog("nfc: session end")
            self.onFinish?()
        }
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        for tag in tags {
            session.connect(to: tag) { error in
                var line = ""
                if let error = error {
                    line = "接続エラー: \(error.localizedDescription)"
                } else {
                    switch tag {
                    case let feliCa as NFCFeliCaTag:
                        let idm = feliCa.currentIDm.map { String(format: "%02x", $0) }.joined()
                        let sys = feliCa.currentSystemCode.map { String(format: "%02x", $0) }.joined()
                        line = "FeliCa  IDm: \(idm)  SystemCode: \(sys)"
                    case let miFare as NFCMiFareTag:
                        let uid = miFare.identifier.map { String(format: "%02x", $0) }.joined()
                        line = "MIFARE(\(miFare.mifareFamily))  UID: \(uid)"
                    case let iso7816 as NFCISO7816Tag:
                        let uid = iso7816.identifier.map { String(format: "%02x", $0) }.joined()
                        line = "ISO7816  UID: \(uid)"
                    case let iso15693 as NFCISO15693Tag:
                        let uid = iso15693.identifier.map { String(format: "%02x", $0) }.joined()
                        line = "ISO15693  UID: \(uid)"
                    default:
                        line = "不明なタグ"
                    }
                }
                DispatchQueue.main.async {
                    self.onLine?(line)
                    ModuleRuntime.shared.appendLog("nfc: tag detected")
                    self.session?.invalidate()
                }
            }
            return // 1枚ずつ
        }
    }
}

// MARK: - モジュール登録

let nfcTagReader = ToolboxModule(
    id: "nfc.tagreader", title: "タグリーダー", summary: "FeliCa・UID・IDm読み取り",
    icon: "dot.radiowaves.left.and.right", category: .nfc,
    permissions: [
        PermissionRequirement(name: "NFC", detail: "NFC読み取り権限と対応端末") {
            PermissionCenter.nfcSupported ? .granted : .denied
        }
    ],
    makeView: { AnyView(NFCReaderView()) }
)
