import SwiftUI

struct CounterView: View {
    @ObservedObject private var settings = Settings.shared
    @AppStorage("counter.value") private var value = 0

    var body: some View {
        VStack(spacing: 28) {
            Text("\(value)")
                .font(.system(size: 88, weight: .bold, design: .rounded))
                .monospacedDigit()
                .onTapGesture {
                    value += 1
                    haptic(.light)
                }

            HStack(spacing: 20) {
                Button {
                    value -= 1
                    haptic(.light)
                } label: {
                    Image(systemName: "minus")
                        .font(.title2)
                        .frame(width: 76, height: 76)
                        .background(Circle().fill(Color(.systemGray5)))
                }
                .buttonStyle(.plain)

                Button {
                    value += 1
                    haptic(.light)
                } label: {
                    Image(systemName: "plus")
                        .font(.title2)
                        .frame(width: 76, height: 76)
                        .background(Circle().fill(Color.appAccent.opacity(0.25)))
                }
                .buttonStyle(.plain)
            }

            Button("リセット") {
                value = 0
                haptic(.medium)
            }
            .disabled(value == 0)

            Text("数字をタップしても +1 できます")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 72)
        .navigationTitle("カウンタ")
        .navigationBarTitleDisplayMode(.inline)
    }
}
