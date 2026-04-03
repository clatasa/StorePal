internal import SwiftUI
import AVFoundation

// MARK: - Scanner state

enum ScannerState: Equatable {
    case scanning
    case locked(barcode: String)
    case loading(barcode: String)
    case found(barcode: String, product: FoundProduct)
    case notFound(barcode: String)
    case denied

    static func == (lhs: ScannerState, rhs: ScannerState) -> Bool {
        switch (lhs, rhs) {
        case (.scanning, .scanning), (.denied, .denied): return true
        case (.locked(let a), .locked(let b)): return a == b
        case (.loading(let a), .loading(let b)): return a == b
        case (.notFound(let a), .notFound(let b)): return a == b
        case (.found(let a, _), .found(let b, _)): return a == b
        default: return false
        }
    }
}

struct FoundProduct {
    let name: String
    let brand: String?
    let quantity: String?

    var subtitle: String? {
        [brand, quantity].compactMap { $0 }.joined(separator: " · ").nonEmptyOrNil
    }
}

private extension String {
    var nonEmptyOrNil: String? { isEmpty ? nil : self }
}

// MARK: - SwiftUI wrapper

struct BarcodeScannerView: View {
    /// Called when the user confirms adding a product. Passes (name, note).
    let onAdd: (String, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var state: ScannerState = .scanning
    @State private var manualName = ""

    var body: some View {
        NavigationStack {
            ZStack {
                // Live camera feed
                CameraPreviewView(onDetect: handleDetection, isScanning: state == .scanning)
                    .ignoresSafeArea()

                // Reticle
                if state == .scanning {
                    reticleOverlay
                }

                // Bottom panel
                VStack {
                    Spacer()
                    bottomPanel
                }
            }
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.black.opacity(0.6), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    // MARK: - Reticle

    private var reticleOverlay: some View {
        GeometryReader { geo in
            let w = geo.size.width * 0.72
            let h: CGFloat = 160
            let x = (geo.size.width  - w) / 2
            let y = (geo.size.height - h) / 2 - 40

            ZStack {
                // Dim surround
                Color.black.opacity(0.45)
                    .mask(
                        Rectangle()
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .frame(width: w, height: h)
                                    .blendMode(.destinationOut)
                            )
                    )

                // Corner brackets
                ReticleCorners(width: w, height: h)
                    .position(x: geo.size.width / 2, y: y + h / 2)

                // Label
                Text("Align barcode inside the frame")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.5), in: Capsule())
                    .position(x: geo.size.width / 2, y: y + h + 22)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Bottom panel

    @ViewBuilder
    private var bottomPanel: some View {
        VStack(spacing: 16) {
            switch state {
            case .scanning:
                EmptyView()

            case .locked(let barcode):
                VStack(spacing: 10) {
                    Label("Barcode locked: \(barcode)", systemImage: "barcode.viewfinder")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                    HStack(spacing: 12) {
                        Button("Scan Again") {
                            state = .scanning
                        }
                        .buttonStyle(PanelButtonStyle(filled: false))

                        Button("Look Up Product") {
                            state = .loading(barcode: barcode)
                            Task { await lookupProduct(barcode: barcode) }
                        }
                        .buttonStyle(PanelButtonStyle(filled: true))
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal)

            case .loading:
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.white)
                    Text("Looking up product…")
                        .foregroundStyle(.white)
                        .font(.subheadline)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal)

            case .found(_, let product):
                VStack(spacing: 10) {
                    VStack(spacing: 4) {
                        Text(product.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                        if let sub = product.subtitle {
                            Text(sub)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    HStack(spacing: 12) {
                        Button("Scan Again") {
                            state = .scanning
                        }
                        .buttonStyle(PanelButtonStyle(filled: false))

                        Button("Add to List") {
                            onAdd(product.name, product.subtitle)
                            dismiss()
                        }
                        .buttonStyle(PanelButtonStyle(filled: true))
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal)

            case .notFound(let barcode):
                VStack(spacing: 10) {
                    Label("Product not found for \(barcode)", systemImage: "questionmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    TextField("Enter item name manually", text: $manualName)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                    HStack(spacing: 12) {
                        Button("Scan Again") {
                            manualName = ""
                            state = .scanning
                        }
                        .buttonStyle(PanelButtonStyle(filled: false))

                        Button("Add to List") {
                            let name = manualName.trimmingCharacters(in: .whitespaces)
                            guard !name.isEmpty else { return }
                            onAdd(name, nil)
                            dismiss()
                        }
                        .buttonStyle(PanelButtonStyle(filled: true))
                        .disabled(manualName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal)

            case .denied:
                VStack(spacing: 10) {
                    Label("Camera access denied", systemImage: "camera.slash")
                        .font(.subheadline.weight(.medium))
                    Text("Enable camera access in Settings to scan barcodes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(PanelButtonStyle(filled: true))
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 32)
        .animation(.spring(duration: 0.3), value: state)
    }

    // MARK: - Barcode detected callback

    private func handleDetection(_ barcode: String) {
        guard state == .scanning else { return }
        state = .locked(barcode: barcode)
    }

    // MARK: - API lookup

    private func lookupProduct(barcode: String) async {
        do {
            if let result = try await OpenFoodFactsService.shared.lookup(barcode: barcode) {
                state = .found(barcode: barcode, product: FoundProduct(
                    name: result.name,
                    brand: result.brand,
                    quantity: result.quantity
                ))
            } else {
                state = .notFound(barcode: barcode)
            }
        } catch {
            state = .notFound(barcode: barcode)
        }
    }
}

// MARK: - Camera preview (UIViewControllerRepresentable)

private struct CameraPreviewView: UIViewControllerRepresentable {
    let onDetect: (String) -> Void
    let isScanning: Bool

    func makeUIViewController(context: Context) -> CameraViewController {
        let vc = CameraViewController()
        vc.onDetect = onDetect
        return vc
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        if isScanning {
            uiViewController.resumeScanning()
        }
    }
}

// MARK: - CameraViewController

final class CameraViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    var onDetect: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        checkPermission()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning { session.stopRunning() }
    }

    private func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.setupSession() }
                    else { self?.onDetect = nil }   // triggers .denied state via parent
                }
            }
        default:
            break   // denied — parent view shows the Settings prompt
        }
    }

    private func setupSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input  = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }

        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)

        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.ean13, .ean8, .upce, .code128, .code39, .qr]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    // MARK: AVCaptureMetadataOutputObjectsDelegate

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = obj.stringValue else { return }
        // Pause detection until user acts
        session.stopRunning()
        onDetect?(value)
    }

    // MARK: - Resume scanning (called from SwiftUI side via restart)

    func resumeScanning() {
        guard !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }
}

// MARK: - Reticle corners shape

private struct ReticleCorners: View {
    let width: CGFloat
    let height: CGFloat
    private let arm: CGFloat = 22
    private let thickness: CGFloat = 4
    private let radius: CGFloat = 6

    var body: some View {
        ZStack {
            corner().offset(x: -width/2, y: -height/2)
            corner().rotationEffect(.degrees(90)).offset(x: width/2, y: -height/2)
            corner().rotationEffect(.degrees(180)).offset(x: width/2, y: height/2)
            corner().rotationEffect(.degrees(270)).offset(x: -width/2, y: height/2)
        }
    }

    private func corner() -> some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: arm))
            path.addLine(to: CGPoint(x: 0, y: radius))
            path.addQuadCurve(to: CGPoint(x: radius, y: 0), control: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: arm, y: 0))
        }
        .stroke(Color.white, style: StrokeStyle(lineWidth: thickness, lineCap: .round))
    }
}

// MARK: - Button style

private struct PanelButtonStyle: ButtonStyle {
    let filled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(filled ? Color.blue : Color.white.opacity(0.15),
                        in: Capsule())
            .foregroundStyle(.white)
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
