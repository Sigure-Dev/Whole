import SwiftUI

struct ColorToolView: View {
    @State private var color = Color(red: 0.15, green: 0.62, blue: 0.87)

    private var ui: UIColor { UIColor(color) }

    private var rgb: (r: Int, g: Int, b: Int, a: Int) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)), Int(round(a * 255)))
    }

    private var hex: String {
        let c = rgb
        return String(format: "#%02X%02X%02X", c.r, c.g, c.b)
    }

    private var hsb: (h: Int, s: Int, b: Int) {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (Int(round(h * 360)), Int(round(s * 100)), Int(round(b * 100)))
    }

    private var isLight: Bool {
        let c = rgb
        let lum = (0.299 * Double(c.r) + 0.587 * Double(c.g) + 0.114 * Double(c.b)) / 255.0
        return lum > 0.6
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(color)
                    .frame(height: 150)
                    .overlay(
                        Text(hex)
                            .font(.title2)
                            .bold()
                            .monospaced()
                            .foregroundColor(isLight ? .black : .white)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 4)
                    .padding(.horizontal)

                ColorPicker("色を選択", selection: $color, supportsOpacity: false)
                    .padding(.horizontal)

                VStack(spacing: 0) {
                    infoRow("HEX", hex)
                    Divider()
                    let c = rgb
                    infoRow("RGB", "R \(c.r) / G \(c.g) / B \(c.b)")
                    Divider()
                    let h = hsb
                    infoRow("HSB", "H \(h.h)° / S \(h.s)% / B \(h.b)%")
                }
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))
                .padding(.horizontal)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        color = Color(
                            red: .random(in: 0...1),
                            green: .random(in: 0...1),
                            blue: .random(in: 0...1)
                        )
                    }
                    haptic(.light)
                } label: {
                    Label("ランダムな色", systemImage: "dice")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }
            .padding(.vertical)
            .padding(.bottom, 72)
        }
        .navigationTitle("カラーツール")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .monospaced()
            Button {
                UIPasteboard.general.string = value
                haptic(.light)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
