import SwiftUI

struct UnitDef: Identifiable, Hashable {
    let name: String
    let factor: Double
    var id: String { name }
}

struct UnitCategory: Identifiable {
    let name: String
    let units: [UnitDef]
    var id: String { name }
}

enum UnitMath {
    static func convert(_ v: Double, from: UnitDef, to: UnitDef, category: UnitCategory) -> Double {
        if category.name == "温度" {
            return fromCelsius(toCelsius(v, unit: from.name), unit: to.name)
        }
        return v * from.factor / to.factor
    }

    private static func toCelsius(_ v: Double, unit: String) -> Double {
        switch unit {
        case "℃": return v
        case "℉": return (v - 32) * 5 / 9
        case "K": return v - 273.15
        default: return v
        }
    }

    private static func fromCelsius(_ c: Double, unit: String) -> Double {
        switch unit {
        case "℃": return c
        case "℉": return c * 9 / 5 + 32
        case "K": return c + 273.15
        default: return c
        }
    }
}

enum UnitCatalog {
    static let categories: [UnitCategory] = [
        UnitCategory(name: "長さ", units: [
            UnitDef(name: "km", factor: 1000),
            UnitDef(name: "m", factor: 1),
            UnitDef(name: "cm", factor: 0.01),
            UnitDef(name: "mm", factor: 0.001),
            UnitDef(name: "マイル", factor: 1609.344),
            UnitDef(name: "ヤード", factor: 0.9144),
            UnitDef(name: "フィート", factor: 0.3048),
            UnitDef(name: "インチ", factor: 0.0254),
            UnitDef(name: "海里", factor: 1852),
        ]),
        UnitCategory(name: "重さ", units: [
            UnitDef(name: "t", factor: 1000),
            UnitDef(name: "kg", factor: 1),
            UnitDef(name: "g", factor: 0.001),
            UnitDef(name: "mg", factor: 0.000001),
            UnitDef(name: "ポンド", factor: 0.45359237),
            UnitDef(name: "オンス", factor: 0.0283495231),
            UnitDef(name: "貫", factor: 3.75),
        ]),
        UnitCategory(name: "温度", units: [
            UnitDef(name: "℃", factor: 1),
            UnitDef(name: "℉", factor: 1),
            UnitDef(name: "K", factor: 1),
        ]),
        UnitCategory(name: "面積", units: [
            UnitDef(name: "km²", factor: 1_000_000),
            UnitDef(name: "m²", factor: 1),
            UnitDef(name: "ha", factor: 10_000),
            UnitDef(name: "畳", factor: 1.65289),
            UnitDef(name: "坪", factor: 3.30579),
            UnitDef(name: "エーカー", factor: 4046.86),
        ]),
        UnitCategory(name: "容量", units: [
            UnitDef(name: "kL", factor: 1000),
            UnitDef(name: "L", factor: 1),
            UnitDef(name: "mL", factor: 0.001),
            UnitDef(name: "ガロン(US)", factor: 3.78541),
            UnitDef(name: "カップ", factor: 0.2),
            UnitDef(name: "合", factor: 0.1804),
        ]),
        UnitCategory(name: "データ", units: [
            UnitDef(name: "TB", factor: 1_000_000_000_000),
            UnitDef(name: "GB", factor: 1_000_000_000),
            UnitDef(name: "MB", factor: 1_000_000),
            UnitDef(name: "kB", factor: 1_000),
            UnitDef(name: "B", factor: 1),
            UnitDef(name: "bit", factor: 0.125),
        ]),
        UnitCategory(name: "速度", units: [
            UnitDef(name: "km/h", factor: 1.0 / 3.6),
            UnitDef(name: "m/s", factor: 1),
            UnitDef(name: "mph", factor: 0.44704),
            UnitDef(name: "ノット", factor: 0.514444),
        ]),
        UnitCategory(name: "時間", units: [
            UnitDef(name: "週", factor: 604_800),
            UnitDef(name: "日", factor: 86_400),
            UnitDef(name: "時", factor: 3_600),
            UnitDef(name: "分", factor: 60),
            UnitDef(name: "秒", factor: 1),
        ]),
    ]
}

struct UnitConverterView: View {
    @ObservedObject private var settings = Settings.shared
    @State private var categoryIndex = 0
    @State private var amount = "1"
    @State private var fromIndex = 0
    @State private var toIndex = 1

    private var category: UnitCategory {
        UnitCatalog.categories[categoryIndex]
    }

    private var result: Double? {
        guard let v = Double(amount) else { return nil }
        guard fromIndex < category.units.count, toIndex < category.units.count else { return nil }
        return UnitMath.convert(v, from: category.units[fromIndex], to: category.units[toIndex], category: category)
    }

    var body: some View {
        Form {
            Section(header: Text("設定")) {
                Picker("カテゴリ", selection: $categoryIndex) {
                    ForEach(UnitCatalog.categories.indices, id: \.self) { i in
                        Text(UnitCatalog.categories[i].name).tag(i)
                    }
                }
                .onChange(of: categoryIndex) { _ in
                    fromIndex = 0
                    toIndex = 1
                    hideKeyboard()
                }

                HStack {
                    TextField("値", text: $amount)
                        .keyboardType(.decimalPad)
                    unitMenu(selection: $fromIndex)
                }

                Button {
                    let f = fromIndex
                    fromIndex = toIndex
                    toIndex = f
                    haptic(.light)
                } label: {
                    Label("入れ替え", systemImage: "arrow.2.squarepath")
                }
            }

            Section(header: Text("結果")) {
                if let r = result, toIndex < category.units.count {
                    HStack(alignment: .firstTextBaseline) {
                        Text(r.prettyString)
                            .font(.system(size: 28, weight: .semibold, design: .monospaced))
                            .lineLimit(1)
                            .minimumScaleFactor(0.3)
                        Text(category.units[toIndex].name)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("数値を入力してください").foregroundColor(.secondary)
                }
            }

            Section(header: Text("一覧")) {
                if let v = Double(amount), fromIndex < category.units.count {
                    let from = category.units[fromIndex]
                    ForEach(category.units) { u in
                        HStack {
                            Text(u.name)
                                .foregroundColor(u.name == from.name ? .appAccent : .primary)
                            Spacer()
                            Text(UnitMath.convert(v, from: from, to: u, category: category).prettyString)
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.4)
                        }
                    }
                } else {
                    Text("数値を入力すると各単位に変換されます").foregroundColor(.secondary)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 72)
        }
        .navigationTitle("単位変換")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                HStack {
                    Spacer()
                    Button("完了") { hideKeyboard() }
                }
            }
        }
    }

    private func unitMenu(selection: Binding<Int>) -> some View {
        Menu {
            ForEach(category.units.indices, id: \.self) { i in
                Button(category.units[i].name) { selection.wrappedValue = i }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selection.wrappedValue < category.units.count ? category.units[selection.wrappedValue].name : "単位")
                    .font(.subheadline)
                    .foregroundColor(.appAccent)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundColor(.appAccent)
            }
        }
    }
}
