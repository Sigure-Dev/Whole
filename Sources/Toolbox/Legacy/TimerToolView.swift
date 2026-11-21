import SwiftUI
import AudioToolbox

struct TimerToolView: View {
    @ObservedObject private var settings = Settings.shared
    @State private var minutes = 3
    @State private var seconds = 0
    @State private var running = false
    @State private var endDate: Date? = nil
    @State private var remaining: TimeInterval = 180
    @State private var showDone = false

    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    private var total: TimeInterval { TimeInterval(minutes * 60 + seconds) }
    private var progress: Double { total > 0 ? max(0, min(1, remaining / total)) : 0 }

    var body: some View {
        VStack(spacing: 24) {
            if running {
                ring
                HStack(spacing: 16) {
                    Button {
                        running = false
                        endDate = nil
                    } label: {
                        Text("一時停止")
                            .frame(width: 110, height: 44)
                            .background(Circle().fill(Color(.systemGray5)))
                    }
                    .buttonStyle(.plain)

                    Button {
                        cancel()
                    } label: {
                        Text("リセット")
                            .frame(width: 110, height: 44)
                            .background(Circle().fill(Color.red.opacity(0.15)))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                HStack(spacing: 0) {
                    Picker("分", selection: $minutes) {
                        ForEach(0..<60, id: \.self) { Text("\($0) 分").tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: 130)
                    .clipped()

                    Picker("秒", selection: $seconds) {
                        ForEach(0..<60, id: \.self) { Text("\($0) 秒").tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: 130)
                    .clipped()
                }
                .onChange(of: minutes) { _ in remaining = total }
                .onChange(of: seconds) { _ in remaining = total }

                Button {
                    start()
                } label: {
                    Text("開始")
                        .font(.headline)
                        .frame(width: 140, height: 48)
                        .background(RoundedRectangle(cornerRadius: 24).fill(total > 0 ? Color.appAccent : Color.gray))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .disabled(total <= 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(timer) { t in
            guard running, let end = endDate else { return }
            remaining = end.timeIntervalSince(t)
            if remaining <= 0 { finish() }
        }
        .onAppear { remaining = total }
        .onDisappear {
            if running { cancel() }
        }
        .padding(.bottom, 72)
        .alert("タイマー終了", isPresented: $showDone) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("時間になりました")
        }
        .navigationTitle("タイマー")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 12)
            Circle()
                .trim(to: CGFloat(progress))
                .stroke(Color.appAccent, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 4) {
                Text(Self.format(remaining))
                    .font(.system(size: 40, weight: .light, design: .monospaced))
                    .monospacedDigit()
                Text("残り")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 240, height: 240)
    }

    private func start() {
        remaining = total
        endDate = Date().addingTimeInterval(total)
        running = true
    }

    private func cancel() {
        running = false
        endDate = nil
        remaining = total
    }

    private func finish() {
        running = false
        remaining = 0
        endDate = nil
        showDone = true
        notifyHaptic(.success)
        if Settings.shared.soundOn {
            AudioServicesPlaySystemSound(1000)
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }

    static func format(_ t: TimeInterval) -> String {
        let s = max(0, Int(t.rounded()))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}
