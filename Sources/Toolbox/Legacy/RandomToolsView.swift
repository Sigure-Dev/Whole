import SwiftUI

struct RandomToolsView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case dice = "ダイス"
        case coin = "コイン"
        case number = "乱数"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .dice

    var body: some View {
        VStack(spacing: 16) {
            Picker("モード", selection: $mode) {
                ForEach(Mode.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            switch mode {
            case .dice: DiceTool()
            case .coin: CoinTool()
            case .number: NumberTool()
            }

            Spacer()
        }
        .padding(.top)
        .padding(.bottom, 72)
        .navigationTitle("ランダム")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DiceTool: View {
    @State private var count = 2
    @State private var sides = 6
    @State private var rolls: [Int] = []

    var body: some View {
        VStack(spacing: 20) {
            resultView
                .frame(minHeight: 120)

            Stepper("個数: \(count)", value: $count, in: 1...8)
                .padding(.horizontal, 40)
                .onChange(of: count) { _ in rolls = [] }
            Picker("面数", selection: $sides) {
                Text("6面").tag(6)
                Text("20面").tag(20)
                Text("100面").tag(100)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 40)
            .onChange(of: sides) { _ in rolls = [] }

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    rolls = (0..<count).map { _ in Int.random(in: 1...sides) }
                }
                haptic(.medium)
            } label: {
                Text("ロール")
                    .font(.headline)
                    .frame(width: 160, height: 46)
                    .background(RoundedRectangle(cornerRadius: 23).fill(Color.brown.opacity(0.85)))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder private var resultView: some View {
        if rolls.isEmpty {
            Text("ロールしてね")
                .foregroundColor(.secondary)
        } else if sides == 6 && rolls.count <= 6 {
            HStack(spacing: 10) {
                ForEach(rolls, id: \.self) { r in
                    Image(systemName: "die.face.\(r)")
                        .font(.system(size: 44))
                }
            }
        } else {
            Text(rolls.map(String.init).joined(separator: "  ·  "))
                .font(.system(size: 36, weight: .semibold, design: .monospaced))
                .lineLimit(2)
                .minimumScaleFactor(0.4)
        }
    }
}

struct CoinTool: View {
    @State private var result: String? = nil

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(colors: [Color.yellow.opacity(0.95), Color.orange.opacity(0.9)],
                                       center: .center, startRadius: 5, endRadius: 90)
                    )
                    .frame(width: 150, height: 150)
                    .shadow(color: .black.opacity(0.2), radius: 6)
                Text(result ?? "?")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(.brown)
            }
            .id(result) // アニメーション再トリガ

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    result = Bool.random() ? "表" : "裏"
                }
                haptic(.medium)
            } label: {
                Text("トス")
                    .font(.headline)
                    .frame(width: 160, height: 46)
                    .background(RoundedRectangle(cornerRadius: 23).fill(Color.orange))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
        }
    }
}

struct NumberTool: View {
    @State private var minText = "1"
    @State private var maxText = "100"
    @State private var value: Int? = nil

    private var range: ClosedRange<Int>? {
        guard let a = Int(minText), let b = Int(maxText) else { return nil }
        return a <= b ? a...b : b...a
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(value.map(String.init) ?? "—")
                .font(.system(size: 64, weight: .bold, design: .monospaced))
                .monospacedDigit()

            HStack(spacing: 12) {
                TextField("最小", text: $minText)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 110)
                Text("〜")
                    .foregroundColor(.secondary)
                TextField("最大", text: $maxText)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 110)
            }

            Button {
                if let r = range {
                    value = Int.random(in: r)
                    haptic(.medium)
                }
            } label: {
                Text("生成")
                    .font(.headline)
                    .frame(width: 160, height: 46)
                    .background(RoundedRectangle(cornerRadius: 23).fill(range == nil ? Color.gray : Color.appAccent))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .disabled(range == nil)
        }
    }
}
