import SwiftUI

struct StopwatchView: View {
    @ObservedObject private var settings = Settings.shared
    @State private var running = false
    @State private var startDate: Date? = nil
    @State private var accumulated: TimeInterval = 0
    @State private var laps: [TimeInterval] = []
    @State private var now = Date()

    private let timer = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()

    private var elapsed: TimeInterval {
        accumulated + (running && startDate != nil ? now.timeIntervalSince(startDate!) : 0)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(Self.format(elapsed))
                .font(.system(size: 56, weight: .light, design: .monospaced))
                .monospacedDigit()
                .padding(.top, 12)

            HStack(spacing: 16) {
                Button {
                    if running {
                        laps.append(elapsed)
                        haptic(.light)
                    } else if elapsed > 0 {
                        reset()
                    }
                } label: {
                    Text(running ? "ラップ" : "リセット")
                        .frame(width: 92, height: 44)
                        .background(Circle().fill(Color(.systemGray5)))
                }
                .buttonStyle(.plain)

                Button {
                    running ? pause() : start()
                    haptic(.medium)
                } label: {
                    Text(running ? "停止" : "開始")
                        .frame(width: 92, height: 44)
                        .background(Circle().fill(running ? Color.red.opacity(0.85) : Color.green.opacity(0.85)))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }

            if !laps.isEmpty {
                List {
                    ForEach(Array(laps.enumerated().reversed()), id: \.offset) { item in
                        let index = item.offset
                        let total = item.element
                        let split = total - (index > 0 ? laps[index - 1] : 0)
                        HStack {
                            Text("ラップ \(index + 1)")
                                .font(.subheadline)
                            Spacer()
                            Text("+" + Self.format(split))
                                .font(.subheadline)
                                .monospacedDigit()
                                .foregroundColor(.appAccent)
                            Text(Self.format(total))
                                .font(.subheadline)
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                                .frame(width: 100, alignment: .trailing)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .onReceive(timer) { t in
            if running { now = t }
        }
        .onDisappear {
            if running { pause() }
        }
        .padding(.bottom, 72)
        .navigationTitle("ストップウォッチ")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func start() {
        startDate = Date()
        running = true
    }

    private func pause() {
        if let s = startDate {
            accumulated += now.timeIntervalSince(s)
        }
        running = false
    }

    private func reset() {
        running = false
        startDate = nil
        accumulated = 0
        laps.removeAll()
    }

    static func format(_ t: TimeInterval) -> String {
        let cs = max(0, Int((t * 100).rounded()))
        return String(format: "%02d:%02d.%02d", cs / 6000, (cs / 100) % 60, cs % 100)
    }
}
