import SwiftUI
import CoreImage.CIFilterBuiltins

enum QRCodeMaker {
    static func make(_ string: String) -> UIImage? {
        guard !string.isEmpty, let data = string.data(using: .utf8) else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scale: CGFloat = 12
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

struct QRGeneratorView: View {
    @State private var text = ""
    @State private var image: UIImage?
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .frame(width: 280, height: 280)
                        .shadow(color: .black.opacity(0.15), radius: 5)
                    if let image = image {
                        Image(uiImage: image)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 248, height: 248)
                    } else {
                        Text("テキストを入力すると\nQRコードが生成されます")
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                }

                TextField("テキスト / URL", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onChange(of: text) { newText in
                        image = QRCodeMaker.make(newText)
                        copied = false
                    }

                HStack(spacing: 16) {
                    Button {
                        UIPasteboard.general.image = image
                        copied = true
                        haptic(.light)
                    } label: {
                        Label("画像をコピー", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(image == nil)

                    Button {
                        UIPasteboard.general.string = text
                        copied = true
                        haptic(.light)
                    } label: {
                        Label("テキストをコピー", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .disabled(text.isEmpty)
                }

                if copied {
                    Text("コピーしました")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .padding(.bottom, 72)
        }
        .navigationTitle("QRコード生成")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { image = QRCodeMaker.make(text) }
    }
}
