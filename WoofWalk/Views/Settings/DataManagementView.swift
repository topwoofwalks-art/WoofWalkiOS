import SwiftUI
import FirebaseAuth
import FirebaseFunctions

struct DataManagementView: View {
    @StateObject private var viewModel = DataManagementViewModel()
    @State private var showClearCacheDialog = false
    @State private var showDeleteDataDialog = false
    @State private var showExportShare = false
    @State private var exportURL: URL?
    @State private var exportError: String?

    var body: some View {
        List {
            storageInfoSection
            cacheSection
            dataExportSection
            dangerZoneSection
        }
        .navigationTitle("Data & Storage")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.calculateStorageUsage()
        }
        .alert("Clear Cache?", isPresented: $showClearCacheDialog) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                viewModel.clearCache()
            }
        } message: {
            Text("This will remove all cached map tiles and images. You can re-download them later.")
        }
        .alert("Delete All Data?", isPresented: $showDeleteDataDialog) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteAllData()
            }
        } message: {
            Text("This will permanently delete all walks, photos, and local data. This cannot be undone.")
        }
        .alert("Export Failed", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
        .sheet(isPresented: $showExportShare) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
            }
        }
    }

    private var storageInfoSection: some View {
        Section {
            HStack {
                Label("Total Storage Used", systemImage: "internaldrive")
                Spacer()
                Text(viewModel.formatBytes(viewModel.totalStorageUsed))
                    .foregroundColor(.secondary)
            }

            HStack {
                Label("Walk Data", systemImage: "figure.walk")
                Spacer()
                Text(viewModel.formatBytes(viewModel.walkDataSize))
                    .foregroundColor(.secondary)
            }

            HStack {
                Label("Photos", systemImage: "photo")
                Spacer()
                Text(viewModel.formatBytes(viewModel.photoDataSize))
                    .foregroundColor(.secondary)
            }

            HStack {
                Label("Cache", systemImage: "memorychip")
                Spacer()
                Text(viewModel.formatBytes(viewModel.cacheSize))
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("Storage Usage")
        }
    }

    private var cacheSection: some View {
        Section {
            Button {
                showClearCacheDialog = true
            } label: {
                Label("Clear Cache", systemImage: "trash")
            }

            Toggle(isOn: $viewModel.autoClearCache) {
                VStack(alignment: .leading) {
                    Text("Auto-Clear Cache")
                    Text("Automatically clear cache when it exceeds 500 MB")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Toggle(isOn: $viewModel.offlineMapsEnabled) {
                VStack(alignment: .leading) {
                    Text("Offline Maps")
                    Text("Download and cache map tiles for offline use")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Cache Management")
        }
    }

    // GDPR Article 20: right to data portability. A single CF call
    // (`exportUserData`) returns the user's complete bundle (profile,
    // dogs, posts, friendships, bookings, reviews, meet-and-greets,
    // consents, ...). We write it to a temp file and surface via the
    // platform share sheet.
    //
    // The three legacy "scope" buttons (All / Walks / Settings) were
    // stubs that wrote `{"exported": "all_data"}` to disk — GDPR
    // non-compliant. Consolidated to one real export.
    private var dataExportSection: some View {
        Section {
            Button {
                viewModel.exportAllData { result in
                    switch result {
                    case .success(let url):
                        exportURL = url
                        showExportShare = true
                    case .failure(let error):
                        exportError = error.localizedDescription
                    }
                }
            } label: {
                HStack {
                    Label("Export All My Data", systemImage: "square.and.arrow.up")
                    Spacer()
                    if viewModel.isExporting {
                        ProgressView()
                    }
                }
            }
            .disabled(viewModel.isExporting)
        } header: {
            Text("Data Export (GDPR)")
        } footer: {
            Text("Download a JSON copy of all data WoofWalk holds about you — profile, dogs, posts, friendships, bookings, reviews, meet-and-greets, and consent records. Your right under GDPR Article 20.")
        }
    }

    private var dangerZoneSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteDataDialog = true
            } label: {
                Label("Delete All Local Data", systemImage: "exclamationmark.triangle")
            }
        } header: {
            Text("Danger Zone")
        } footer: {
            Text("This will permanently delete all walks, photos, and local data from this device. Cloud data will not be affected — use Delete Account in Settings to remove cloud data.")
        }
    }
}

@MainActor
class DataManagementViewModel: ObservableObject {
    @Published var totalStorageUsed: Int64 = 0
    @Published var walkDataSize: Int64 = 0
    @Published var photoDataSize: Int64 = 0
    @Published var cacheSize: Int64 = 0
    @Published var autoClearCache: Bool = false
    @Published var offlineMapsEnabled: Bool = false
    @Published var isExporting: Bool = false

    private lazy var functions = Functions.functions(region: "europe-west2")

    func calculateStorageUsage() {
        let fileManager = FileManager.default

        if let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            walkDataSize = directorySize(at: documentsPath.appendingPathComponent("walks"))
            photoDataSize = directorySize(at: documentsPath.appendingPathComponent("photos"))
        }

        if let cachesPath = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            cacheSize = directorySize(at: cachesPath)
        }

        totalStorageUsed = walkDataSize + photoDataSize + cacheSize
    }

    private func directorySize(at url: URL) -> Int64 {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = resourceValues.fileSize else {
                continue
            }
            totalSize += Int64(fileSize)
        }

        return totalSize
    }

    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    func clearCache() {
        let fileManager = FileManager.default
        if let cachesPath = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            try? fileManager.removeItem(at: cachesPath)
            try? fileManager.createDirectory(at: cachesPath, withIntermediateDirectories: true)
        }

        URLCache.shared.removeAllCachedResponses()
        calculateStorageUsage()
    }

    func deleteAllData() {
        let fileManager = FileManager.default
        if let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            try? fileManager.removeItem(at: documentsPath.appendingPathComponent("walks"))
            try? fileManager.removeItem(at: documentsPath.appendingPathComponent("photos"))
        }
        calculateStorageUsage()
    }

    enum ExportError: LocalizedError {
        case notSignedIn
        case malformedResponse
        case writeFailed(String)

        var errorDescription: String? {
            switch self {
            case .notSignedIn:
                return "You must be signed in to export your data."
            case .malformedResponse:
                return "Server returned an unexpected response. Please try again."
            case .writeFailed(let detail):
                return "Could not save export file: \(detail)"
            }
        }
    }

    // Calls the `exportUserData` CF (europe-west2), which returns
    // `{ ok: true, bundle: { ... } }`. We serialise the bundle as
    // pretty-printed JSON and drop it in the temp dir so iOS' share
    // sheet can hand it to Files / Mail / AirDrop / etc.
    //
    // Matches Android's `UserRepository.exportUserData()` source-of-truth
    // path. The CF mirrors GDPR Article 20 scope; if it ever grows to
    // emit a Cloud Storage signed URL (large exports), the response
    // contract becomes `{ ok: true, downloadUrl, expiresAt }` and we
    // detect+stream in the same callback below.
    func exportAllData(completion: @escaping (Result<URL, Error>) -> Void) {
        guard Auth.auth().currentUser != nil else {
            completion(.failure(ExportError.notSignedIn))
            return
        }

        isExporting = true

        functions
            .httpsCallable("exportUserData")
            .call([:]) { [weak self] result, error in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.isExporting = false

                    if let error = error {
                        completion(.failure(error))
                        return
                    }

                    guard let data = result?.data as? [String: Any] else {
                        completion(.failure(ExportError.malformedResponse))
                        return
                    }

                    // If the CF ever switches to signed-URL delivery,
                    // stream it down rather than serialising the inline
                    // bundle. Detect via the presence of `downloadUrl`.
                    if let downloadUrlString = data["downloadUrl"] as? String,
                       let downloadUrl = URL(string: downloadUrlString) {
                        self.streamSignedExport(from: downloadUrl, completion: completion)
                        return
                    }

                    guard let bundle = data["bundle"] else {
                        completion(.failure(ExportError.malformedResponse))
                        return
                    }

                    do {
                        let json = try JSONSerialization.data(
                            withJSONObject: bundle,
                            options: [.prettyPrinted, .sortedKeys]
                        )
                        let filename = "woofwalk_data_export_\(Int(Date().timeIntervalSince1970)).json"
                        let tempURL = FileManager.default.temporaryDirectory
                            .appendingPathComponent(filename)
                        try json.write(to: tempURL, options: .atomic)
                        completion(.success(tempURL))
                    } catch {
                        completion(.failure(ExportError.writeFailed(error.localizedDescription)))
                    }
                }
            }
    }

    private func streamSignedExport(from url: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        URLSession.shared.downloadTask(with: url) { tempLocation, _, error in
            Task { @MainActor in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let tempLocation = tempLocation else {
                    completion(.failure(ExportError.malformedResponse))
                    return
                }
                // Move out of the system-managed location into our own
                // tempDirectory so the OS doesn't reap it before the
                // share-sheet presenter reads it.
                let filename = "woofwalk_data_export_\(Int(Date().timeIntervalSince1970)).json"
                let destination = FileManager.default.temporaryDirectory
                    .appendingPathComponent(filename)
                try? FileManager.default.removeItem(at: destination)
                do {
                    try FileManager.default.moveItem(at: tempLocation, to: destination)
                    completion(.success(destination))
                } catch {
                    completion(.failure(ExportError.writeFailed(error.localizedDescription)))
                }
            }
        }.resume()
    }
}
