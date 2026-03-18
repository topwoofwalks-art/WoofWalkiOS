import SwiftUI
import AVFoundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - ScanKeyScreen

struct ScanKeyScreen: View {
    @StateObject private var viewModel = ScanKeyViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.neutral10.ignoresSafeArea()

            VStack(spacing: 0) {
                if viewModel.showManualEntry {
                    manualEntryView
                } else {
                    cameraSection
                }

                keyDetailsOrHistory
            }

            // Loading overlay
            if viewModel.isLoading {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .overlay {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)
                    }
            }

            // Success overlay
            if viewModel.actionSuccess, let message = viewModel.successMessage {
                successOverlay(message: message)
            }
        }
        .navigationTitle("Scan Key")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { viewModel.toggleManualEntry() }) {
                    Image(systemName: viewModel.showManualEntry ? "camera.fill" : "keyboard")
                        .foregroundColor(.white)
                }
            }
        }
        .alert("Confirm Action", isPresented: $viewModel.showConfirmDialog) {
            Button("Cancel", role: .cancel) { viewModel.cancelAction() }
            Button("Confirm") { viewModel.confirmKeyAction() }
        } message: {
            if let action = viewModel.pendingAction, let key = viewModel.scannedKey {
                Text("\(action.displayName) key \(key.keyCode) for \(key.clientName)?")
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.clearError() } }
        )) {
            Button("OK") { viewModel.clearError() }
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
    }

    // MARK: - Camera Section

    private var cameraSection: some View {
        ZStack {
            QRScannerView(
                isFlashOn: viewModel.isFlashOn,
                onCodeScanned: { code in
                    viewModel.onBarcodeScanned(code)
                }
            )
            .frame(height: 300)

            // Scanning overlay
            VStack {
                Spacer()
                HStack {
                    Spacer()

                    // Flash toggle
                    Button(action: { viewModel.toggleFlash() }) {
                        Image(systemName: viewModel.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    .padding()
                }
            }

            // Scanning frame overlay
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.turquoise30, lineWidth: 3)
                .frame(width: 220, height: 220)

            // Hint text
            VStack {
                Spacer()
                Text("Point camera at QR code on key tag")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.black.opacity(0.6)))
                    .padding(.bottom, 16)
            }
        }
        .frame(height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Manual Entry View

    private var manualEntryView: some View {
        VStack(spacing: 16) {
            Image(systemName: "keyboard")
                .font(.system(size: 48))
                .foregroundColor(.turquoise30)
                .padding(.top, 24)

            Text("Manual Key Lookup")
                .font(.headline)
                .foregroundColor(.white)

            HStack(spacing: 12) {
                TextField("Enter key code (e.g. WW-001-ABC)", text: $viewModel.manualKeyCode)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { viewModel.submitManualKeyCode() }

                Button(action: { viewModel.submitManualKeyCode() }) {
                    Image(systemName: "magnifyingglass")
                        .font(.body.bold())
                        .foregroundColor(.neutral10)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.turquoise30))
                }
                .disabled(viewModel.manualKeyCode.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .frame(height: 300)
        .background(Color.neutral20)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Key Details or History

    private var keyDetailsOrHistory: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let key = viewModel.scannedKey {
                    keyDetailsCard(key: key)
                    actionButtons(key: key)
                } else {
                    scanHistorySection
                }
            }
            .padding(16)
        }
    }

    // MARK: - Key Details Card

    private func keyDetailsCard(key: ClientKey) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: key.keyTypeEnum.icon)
                    .font(.title2)
                    .foregroundColor(.turquoise30)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.turquoise30.opacity(0.2)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(key.clientName)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(key.keyCode)
                        .font(.caption.monospaced())
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                statusBadge(key.statusEnum)
            }

            Divider().background(Color.white.opacity(0.1))

            // Key type
            detailRow(icon: key.keyTypeEnum.icon, label: "Type", value: key.keyTypeEnum.displayName)

            // Address
            if !key.address.isEmpty {
                detailRow(icon: "mappin.circle.fill", label: "Address", value: key.address)
            }

            // Access Instructions
            if !key.accessInstructions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.turquoise30)
                            .font(.subheadline)
                        Text("Access Instructions")
                            .font(.subheadline.bold())
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Text(key.accessInstructions)
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.turquoise30.opacity(0.1))
                        )
                }
            }

            // Notes
            if !key.notes.isEmpty {
                detailRow(icon: "note.text", label: "Notes", value: key.notes)
            }

            // Dismiss button
            Button(action: { viewModel.dismissKeyDetails() }) {
                HStack {
                    Image(systemName: "xmark.circle")
                    Text("Dismiss")
                }
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.neutral20)
        )
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.turquoise30)
                .font(.subheadline)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
        }
    }

    private func statusBadge(_ status: KeyStatus) -> some View {
        Text(status.displayName)
            .font(.caption2.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(statusColor(status))
            )
    }

    private func statusColor(_ status: KeyStatus) -> Color {
        switch status {
        case .withClient: return .blue
        case .withWalker: return .orange
        case .inOffice: return .green
        case .lost: return .red
        case .returned: return .gray
        }
    }

    // MARK: - Action Buttons

    private func actionButtons(key: ClientKey) -> some View {
        VStack(spacing: 10) {
            Button(action: { viewModel.requestKeyAction(.pickup) }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.circle.fill")
                    Text("Mark as Picked Up")
                        .font(.body.bold())
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.turquoise30)
                )
            }
            .disabled(viewModel.actionInProgress)

            Button(action: { viewModel.requestKeyAction(.return) }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("Mark as Returned")
                        .font(.body.bold())
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue)
                )
            }
            .disabled(viewModel.actionInProgress)

            Button(action: { viewModel.requestKeyAction(.verified) }) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Verify")
                        .font(.body.bold())
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
            .disabled(viewModel.actionInProgress)

            if viewModel.actionInProgress {
                ProgressView()
                    .tint(.white)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Scan History Section

    private var scanHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.turquoise30)
                Text("Recent Scans")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }

            if viewModel.recentScans.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.3))
                    Text("No recent scans")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                    Text("Scan a QR code on a key tag to get started")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ForEach(viewModel.recentScans) { record in
                    scanRecordRow(record)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.neutral20)
        )
    }

    private func scanRecordRow(_ record: KeyScanRecord) -> some View {
        HStack(spacing: 12) {
            Image(systemName: record.actionEnum.icon)
                .foregroundColor(.turquoise30)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.clientName)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                HStack(spacing: 4) {
                    Text(record.keyCode)
                        .font(.caption.monospaced())
                        .foregroundColor(.white.opacity(0.5))
                    Text("--")
                        .foregroundColor(.white.opacity(0.3))
                    Text(record.actionEnum.displayName)
                        .font(.caption)
                        .foregroundColor(.turquoise30)
                }
            }

            Spacer()

            Text(record.timestampDate, style: .relative)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.vertical, 6)
    }

    // MARK: - Success Overlay

    private func successOverlay(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(.green)

            Text(message)
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.neutral20)
                .shadow(color: .black.opacity(0.3), radius: 20)
        )
        .transition(.scale.combined(with: .opacity))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                viewModel.dismissKeyDetails()
            }
        }
    }
}

// MARK: - ScanKeyViewModel

@MainActor
final class ScanKeyViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var isFlashOn = false
    @Published var scannedKey: ClientKey?
    @Published var error: String?
    @Published var recentScans: [KeyScanRecord] = []
    @Published var showManualEntry = false
    @Published var manualKeyCode = ""
    @Published var showConfirmDialog = false
    @Published var pendingAction: KeyAction?
    @Published var actionInProgress = false
    @Published var actionSuccess = false
    @Published var successMessage: String?

    private let db = Firestore.firestore()
    private var userId: String? { Auth.auth().currentUser?.uid }
    private var scanListener: ListenerRegistration?

    init() {
        loadRecentScans()
    }

    deinit {
        scanListener?.remove()
    }

    // MARK: - Firestore

    private func loadRecentScans() {
        guard let userId else { return }

        scanListener?.remove()
        scanListener = db.collection("organizations").document(userId)
            .collection("scanRecords")
            .order(by: "timestamp", descending: true)
            .limit(to: 20)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    console_debug("ScanKey: Failed to load scan records: \(error.localizedDescription)")
                    return
                }
                guard let documents = snapshot?.documents else { return }
                self.recentScans = documents.compactMap { try? $0.data(as: KeyScanRecord.self) }
            }
    }

    func onBarcodeScanned(_ code: String) {
        guard !isLoading, scannedKey == nil else { return }
        lookupKey(code: code)
    }

    func submitManualKeyCode() {
        let code = manualKeyCode.trimmingCharacters(in: .whitespaces).uppercased()
        guard !code.isEmpty else { return }
        lookupKey(code: code)
    }

    private func lookupKey(code: String) {
        guard let userId else {
            error = "Not signed in"
            return
        }

        isLoading = true
        self.error = nil

        db.collection("organizations").document(userId)
            .collection("keys").document(code)
            .getDocument(as: ClientKey.self) { [weak self] result in
                guard let self else { return }
                self.isLoading = false

                switch result {
                case .success(let key):
                    self.scannedKey = key
                case .failure:
                    self.error = "Key not found: \(code)"
                }
            }
    }

    func toggleManualEntry() {
        showManualEntry.toggle()
        manualKeyCode = ""
    }

    func toggleFlash() {
        isFlashOn.toggle()
    }

    func dismissKeyDetails() {
        scannedKey = nil
        pendingAction = nil
        showConfirmDialog = false
        actionSuccess = false
        successMessage = nil
    }

    func clearError() {
        error = nil
    }

    func requestKeyAction(_ action: KeyAction) {
        pendingAction = action
        showConfirmDialog = true
    }

    func cancelAction() {
        pendingAction = nil
        showConfirmDialog = false
    }

    func confirmKeyAction() {
        guard let action = pendingAction, let key = scannedKey, let userId else { return }

        actionInProgress = true
        showConfirmDialog = false

        let batch = db.batch()

        // Create scan record
        let scanRef = db.collection("organizations").document(userId)
            .collection("scanRecords").document()
        let scanRecord = KeyScanRecord(
            id: scanRef.documentID,
            keyId: key.id ?? key.keyCode,
            keyCode: key.keyCode,
            clientName: key.clientName,
            action: action.rawValue,
            scannedBy: Auth.auth().currentUser?.displayName ?? "Walker"
        )
        if let data = try? Firestore.Encoder().encode(scanRecord) {
            batch.setData(data, forDocument: scanRef)
        }

        // Update key status if action changes it
        if let newStatus = action.resultingStatus {
            let keyRef = db.collection("organizations").document(userId)
                .collection("keys").document(key.keyCode)
            batch.updateData([
                "status": newStatus.rawValue,
                "lastScannedAt": Int64(Date().timeIntervalSince1970 * 1000),
                "lastScannedBy": Auth.auth().currentUser?.displayName ?? "Walker"
            ], forDocument: keyRef)

            scannedKey?.status = newStatus.rawValue
        }

        batch.commit { [weak self] batchError in
            guard let self else { return }
            self.actionInProgress = false

            if let batchError {
                self.error = "Failed to record action: \(batchError.localizedDescription)"
            } else {
                self.actionSuccess = true
                self.successMessage = action.successMessage
            }
        }
    }
}

// MARK: - console_debug helper

private func console_debug(_ message: String) {
    #if DEBUG
    print(message)
    #endif
}

// MARK: - QRScannerView (AVFoundation Camera)

struct QRScannerView: UIViewControllerRepresentable {
    let isFlashOn: Bool
    let onCodeScanned: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.onCodeScanned = onCodeScanned
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {
        uiViewController.setFlash(isFlashOn)
    }
}

final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCodeScanned: ((String) -> Void)?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hasScanned = false
        startSession()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSession()
    }

    private func setupCamera() {
        let session = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
              session.canAddInput(videoInput) else {
            showPermissionDeniedLabel()
            return
        }

        session.addInput(videoInput)

        let metadataOutput = AVCaptureMetadataOutput()
        guard session.canAddOutput(metadataOutput) else {
            showPermissionDeniedLabel()
            return
        }

        session.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        metadataOutput.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)

        captureSession = session
        previewLayer = preview

        startSession()
    }

    private func startSession() {
        guard let session = captureSession, !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    private func stopSession() {
        guard let session = captureSession, session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            session.stopRunning()
        }
    }

    func setFlash(_ on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }

    private func showPermissionDeniedLabel() {
        let label = UILabel()
        label.text = "Camera access required.\nGo to Settings to enable."
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }

    // MARK: - AVCaptureMetadataOutputObjectsDelegate

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !hasScanned,
              let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              metadataObject.type == .qr,
              let stringValue = metadataObject.stringValue else { return }

        hasScanned = true
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        onCodeScanned?(stringValue)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ScanKeyScreen()
    }
    .preferredColorScheme(.dark)
}
