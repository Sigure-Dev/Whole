import SwiftUI
import AVFoundation

final class ScannerModel: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    @Published var foundCode: String? = nil
    @Published var authorizationDenied = false
    @Published var setupFailed = false

    let session = AVCaptureSession()
    private let metadataOutput = AVCaptureMetadataOutput()
    private var configured = false
    private let sessionQueue = DispatchQueue(label: "jp.whole.scanner")

    func requestAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if granted {
                        self.configureAndStart()
                    } else {
                        self.authorizationDenied = true
                    }
                }
            }
        default:
            authorizationDenied = true
        }
    }

    private func configureAndStart() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.configured {
                self.startRunning()
                return
            }
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input) else {
                DispatchQueue.main.async { self.setupFailed = true }
                return
            }
            self.session.beginConfiguration()
            self.session.addInput(input)
            if self.session.canAddOutput(self.metadataOutput) {
                self.session.addOutput(self.metadataOutput)
                self.metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
                self.metadataOutput.metadataObjectTypes = [.qr, .ean13, .ean8, .code128, .code39]
            }
            self.session.commitConfiguration()
            self.configured = true
            self.startRunning()
        }
    }

    func startRunning() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.session.isRunning else { return }
            self.session.startRunning()
            DispatchQueue.main.async { self.isRunningState() }
        }
    }

    func stopRunning() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async { self.isRunningState() }
        }
    }

    private func isRunningState() {
        objectWillChange.send()
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let object = metadataObjects.compactMap({ $0 as? AVMetadataMachineReadableCodeObject }).first,
              let value = object.stringValue else { return }
        foundCode = value
        notifyHaptic()
        stopRunning()
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

struct QRScannerView: View {
    @StateObject private var model = ScannerModel()
    @ObservedObject private var settings = Settings.shared

    var body: some View {
        ZStack {
            CameraPreview(session: model.session)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.appAccent, lineWidth: 3)
                    .frame(width: 240, height: 240)
                Spacer()
                resultCard
            }
            .padding()
            .padding(.bottom, 72)
        }
        .onAppear { model.requestAndStart() }
        .onDisappear { model.stopRunning() }
        .navigationTitle("QRスキャナー")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private var resultCard: some View {
        if let code = model.foundCode {
            VStack(spacing: 10) {
                Text(code)
                    .font(.headline)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                HStack(spacing: 12) {
                    Button {
                        UIPasteboard.general.string = code
                        haptic(.light)
                    } label: {
                        Label("コピー", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderedProminent)

                    if let url = URL(string: code), url.scheme != nil {
                        Button {
                            UIApplication.shared.open(url)
                        } label: {
                            Label("開く", systemImage: "safari")
                        }
                        .buttonStyle(.bordered)
                    }

                    Button {
                        model.foundCode = nil
                        model.startRunning()
                    } label: {
                        Label("再スキャン", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 14).fill(.thinMaterial))
        } else if model.authorizationDenied {
            VStack(spacing: 8) {
                Text("カメラが許可されていません")
                    .font(.headline)
                Button("設定を開く") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 14).fill(.thinMaterial))
        } else if model.setupFailed {
            Text("カメラを起動できませんでした")
                .padding()
                .background(RoundedRectangle(cornerRadius: 14).fill(.thinMaterial))
        }
    }
}
