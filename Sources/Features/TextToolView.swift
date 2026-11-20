import SwiftUI

struct TextToolView: View {
    @State private var text = ""
    @State private var showError = false
    @State private var errorMessage = ""

    private var charCount: Int { text.count }
    private var lineCount: Int { text.isEmpty ? 0 : text.components(separatedBy: "\n").count }
    private var wordCount: Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    var body: some View {
        VStack(spacing: 12) {
            TextEditor(text: $text)
                .frame(minHeight: 150)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.3))
                )
                .padding(.horizontal)

            HStack {
                stat("文字", charCount)
                stat("単語", wordCount)
                stat("行", lineCount)
            }
            .padding(.horizontal)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 10) {
                toolButton("大文字") { text = text.uppercased() }
                toolButton("小文字") { text = text.lowercased() }
                toolButton("反転") { text = String(text.reversed()) }
                toolButton("空白削除") { text = text.replacingOccurrences(of: " ", with: "") }
                toolButton("Base64化") {
                    if let e = text.base64Encoded { text = e } else { fail("エンコードできません") }
                }
                toolButton("Base64復号") {
                    if let d = text.base64Decoded { text = d } else { fail("Base64として不正です") }
                }
                toolButton("URLエンコード") {
                    if let e = text.urlEncoded { text = e } else { fail("エンコードできません") }
                }
                toolButton("URLデコード") {
                    if let d = text.urlDecoded { text = d } else { fail("不正なエンコードです") }
                }
                toolButton("整形") {
                    text = text
                        .split(separator: "\n")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                        .joined(separator: "\n")
                }
            }
            .padding(.horizontal)

            Spacer(minLength: 0)
        }
        .padding(.bottom, 72)
        .navigationTitle("テキストツール")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 14) {
                    Button {
                        UIPasteboard.general.string = text
                        haptic(.light)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .disabled(text.isEmpty)

                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(text.isEmpty)
                }
            }
        }
        .alert("エラー", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func fail(_ message: String) {
        errorMessage = message
        showError = true
    }

    private func stat(_ title: String, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title3)
                .bold()
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func toolButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.footnote)
                .frame(maxWidth: .infinity, minHeight: 40)
        }
        .buttonStyle(.bordered)
    }
}
