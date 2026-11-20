import SwiftUI
import CoreLocation

final class CompassModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var heading: Double = 0
    @Published var accuracy: Double = -1
    @Published var denied = false

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.headingFilter = 0.5
    }

    func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            denied = true
        default:
            manager.startUpdatingHeading()
        }
    }

    func stop() {
        manager.stopUpdatingHeading()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            denied = false
            manager.startUpdatingHeading()
        case .denied, .restricted:
            denied = true
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let h = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        heading = h
        accuracy = newHeading.headingAccuracy
    }
}

struct CompassView: View {
    @StateObject private var model = CompassModel()

    var body: some View {
        VStack(spacing: 20) {
            if model.denied {
                VStack(spacing: 12) {
                    Image(systemName: "location.slash")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary)
                    Text("位置情報が許可されていません")
                        .font(.headline)
                    Text("設定 → Whole → 位置情報 で許可してください")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Button("設定を開く") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                compassRose
                    .padding(.top, 8)

                Text("\(Int((model.heading + 360).truncatingRemainder(dividingBy: 360)))° \(Self.directionName(model.heading))")
                    .font(.system(size: 36, weight: .medium, design: .monospaced))
                    .monospacedDigit()

                if model.accuracy >= 0 {
                    Text("精度 ±\(Int(model.accuracy))°")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text("※ シミュレータでは方位を取得できません")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
        .padding(.bottom, 72)
        .navigationTitle("コンパス")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var compassRose: some View {
        ZStack {
            Circle().stroke(Color(.systemGray4), lineWidth: 1).frame(width: 260, height: 260)
            Circle().stroke(Color(.systemGray5), lineWidth: 1).frame(width: 200, height: 200)

            ZStack {
                ForEach(0..<36, id: \.self) { i in
                    Capsule()
                        .fill(i % 9 == 0 ? Color.primary : Color.secondary)
                        .frame(width: i % 9 == 0 ? 2 : 1, height: i % 9 == 0 ? 14 : 8)
                        .offset(y: -122)
                        .rotationEffect(.degrees(Double(i) * 10))
                }
                ForEach(0..<4, id: \.self) { i in
                    Text(["北", "東", "南", "西"][i])
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(i == 0 ? .red : .primary)
                        .rotationEffect(.degrees(model.heading)) // 文字は常に直立
                        .offset(y: -98)
                        .rotationEffect(.degrees(Double(i) * 90))
                }
            }
            .rotationEffect(.degrees(-model.heading))

            Image(systemName: "location.north.fill")
                .font(.system(size: 42))
                .foregroundColor(.red)
        }
    }

    static func directionName(_ deg: Double) -> String {
        let names = ["北", "北北東", "北東", "東北東", "東", "東南東", "南東", "南南東",
                     "南", "南南西", "南西", "西南西", "西", "西北西", "北西", "北北西"]
        let normalized = (deg + 360).truncatingRemainder(dividingBy: 360)
        let idx = Int((normalized + 11.25) / 22.5) % 16
        return names[idx]
    }
}
