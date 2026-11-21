import SwiftUI

struct WorldCity: Identifiable {
    let name: String
    let tzID: String
    var timeZone: TimeZone { TimeZone(identifier: tzID) ?? .current }
    var id: String { name }
}

struct WorldClockView: View {
    static let cities: [WorldCity] = [
        WorldCity(name: "東京", tzID: "Asia/Tokyo"),
        WorldCity(name: "ソウル", tzID: "Asia/Seoul"),
        WorldCity(name: "上海", tzID: "Asia/Shanghai"),
        WorldCity(name: "シンガポール", tzID: "Asia/Singapore"),
        WorldCity(name: "ロンドン", tzID: "Europe/London"),
        WorldCity(name: "パリ", tzID: "Europe/Paris"),
        WorldCity(name: "ニューヨーク", tzID: "America/New_York"),
        WorldCity(name: "ロサンゼルス", tzID: "America/Los_Angeles"),
        WorldCity(name: "シドニー", tzID: "Australia/Sydney"),
        WorldCity(name: "UTC", tzID: "UTC"),
    ]

    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        List {
            ForEach(Self.cities) { city in
                row(city)
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 72)
        }
        .onReceive(timer) { now = $0 }
        .navigationTitle("世界時計")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ city: WorldCity) -> some View {
        let tz = city.timeZone
        let offsetSec = tz.secondsFromGMT()
        let h = offsetSec / 3600
        let m = abs(offsetSec) % 3600 / 60
        let sign = offsetSec < 0 ? "-" : "+"
        let offsetText = "UTC\(sign)\(abs(h))" + (m > 0 ? String(format: ":%02d", m) : "")

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(city.name)
                Text(tz.identifier)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Self.timeFormatter(tz).string(from: now))
                    .font(.title3)
                    .monospacedDigit()
                Text(offsetText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private static func timeFormatter(_ tz: TimeZone) -> DateFormatter {
        let df = DateFormatter()
        df.timeZone = tz
        df.dateFormat = "HH:mm:ss"
        return df
    }
}
