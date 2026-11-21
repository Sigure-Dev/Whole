import SwiftUI

final class CalcModel: ObservableObject {
    @Published var display = "0"
    @Published var history: [String] = []

    private var acc: Double? = nil
    private var pendingOp: String? = nil
    private var typing = false

    private func apply(_ a: Double, _ op: String, _ b: Double) -> Double {
        switch op {
        case "+": return a + b
        case "−": return a - b
        case "×": return a * b
        case "÷": return b == 0 ? Double.nan : a / b
        default: return b
        }
    }

    func pressDigit(_ d: String) {
        if !typing {
            display = (d == ".") ? "0." : d
            typing = true
            return
        }
        if d == "." && display.contains(".") { return }
        if display == "0" && d != "." {
            display = d
        } else {
            if display.count >= 14 { return }
            display += d
        }
    }

    func pressOperator(_ op: String) {
        let v = Double(display) ?? 0
        if let a = acc, let po = pendingOp {
            if typing {
                let r = apply(a, po, v)
                if r.isNaN { setError(); return }
                acc = r
                display = r.prettyString
            }
        } else {
            acc = v
        }
        pendingOp = op
        typing = false
    }

    func pressEquals() {
        guard let a = acc, let po = pendingOp else { return }
        let v = Double(display) ?? 0
        let r = apply(a, po, v)
        if r.isNaN { setError(); return }
        history.insert("\(a.prettyString) \(po) \(v.prettyString) = \(r.prettyString)", at: 0)
        if history.count > 5 { history.removeLast() }
        display = r.prettyString
        acc = nil
        pendingOp = nil
        typing = false
    }

    func pressPercent() {
        var v = Double(display) ?? 0
        v /= 100
        display = v.prettyString
        typing = false
    }

    func pressNegate() {
        guard let v = Double(display) else { return }
        display = (-v).prettyString
    }

    func pressBackspace() {
        guard typing, display.count > 1 else {
            display = "0"
            typing = false
            return
        }
        display.removeLast()
        if display == "-" {
            display = "0"
            typing = false
        }
    }

    func clear() {
        display = "0"
        acc = nil
        pendingOp = nil
        typing = false
        history.removeAll()
    }

    private func setError() {
        display = "エラー"
        acc = nil
        pendingOp = nil
        typing = false
    }
}

struct CalcKey {
    enum Kind {
        case digit(String), clear, negate, percent, back, equals, op(String)
    }
    let kind: Kind

    var label: String {
        switch kind {
        case .digit(let d): return d
        case .clear: return "AC"
        case .negate: return "±"
        case .percent: return "%"
        case .back: return "⌫"
        case .equals: return "="
        case .op(let o): return o
        }
    }

    var isOperator: Bool {
        if case .op = kind { return true }
        if case .equals = kind { return true }
        return false
    }

    var isUtility: Bool {
        switch kind {
        case .clear, .negate, .percent, .back: return true
        default: return false
        }
    }
}

struct CalculatorView: View {
    @StateObject private var model = CalcModel()

    private let rows: [[CalcKey]] = [
        [CalcKey(kind: .clear), CalcKey(kind: .negate), CalcKey(kind: .percent), CalcKey(kind: .op("÷"))],
        [CalcKey(kind: .digit("7")), CalcKey(kind: .digit("8")), CalcKey(kind: .digit("9")), CalcKey(kind: .op("×"))],
        [CalcKey(kind: .digit("4")), CalcKey(kind: .digit("5")), CalcKey(kind: .digit("6")), CalcKey(kind: .op("−"))],
        [CalcKey(kind: .digit("1")), CalcKey(kind: .digit("2")), CalcKey(kind: .digit("3")), CalcKey(kind: .op("+"))],
        [CalcKey(kind: .digit("0")), CalcKey(kind: .digit(".")), CalcKey(kind: .back), CalcKey(kind: .equals)],
    ]

    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .trailing, spacing: 6) {
                ForEach(model.history.prefix(3), id: \.self) { h in
                    Text(h)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Text(model.display)
                    .font(.system(size: 48, weight: .light, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.35)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal)
            .padding(.top, 8)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                ForEach(rows.indices, id: \.self) { r in
                    ForEach(rows[r].indices, id: \.self) { c in
                        keyButton(rows[r][c])
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 80)
        }
        .navigationTitle("電卓")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func keyButton(_ key: CalcKey) -> some View {
        Button {
            haptic(.light)
            switch key.kind {
            case .digit(let d): model.pressDigit(d)
            case .clear: model.clear()
            case .negate: model.pressNegate()
            case .percent: model.pressPercent()
            case .back: model.pressBackspace()
            case .equals: model.pressEquals()
            case .op(let o): model.pressOperator(o)
            }
        } label: {
            Text(key.label)
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 62)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(key.isOperator ? Color.orange : (key.isUtility ? Color(.systemGray3) : Color(.systemGray5)))
                )
                .foregroundColor(key.isOperator ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}
