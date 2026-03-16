import SwiftUI

struct DataManagementView: View {
    @StateObject private var viewModel = DataManagementViewModel()
    @State private var showExportDialog = false
    @State private var showClearCacheDialog = false
    @State private var showDeleteDataDialog = false
    @State private var exportURL: URL?

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
        .sheet(isPresented: $showExportDialog) {
            if let url = exportURL {
                ShareSheet(items: [url])
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

    private var dataExportSection: some View {
        Section {
            Button {
                viewModel.exportAllData { result in
                    switch result {
                    case .success(let url):
                        exportURL = url
                        showExportDialog = true
                    case .failure:
                        break
                    }
                }
            } label: {
                Label("Export All Data", systemImage: "square.and.arrow.up")
            }

            Button {
                viewModel.exportWalkHistory { result in
                    switch result {
                    case .success(let url):
                        exportURL = url
                        showExportDialog = true
                    case .failure:
                        break
                    }
                }
            } label: {
                Label("Export Walk History", systemImage: "figure.walk.circle")
            }

            Button {
                viewModel.exportSettings { result in
                    switch result {
                    case .success(let url):
                        exportURL = url
                        showExportDialog = true
                    case .failure:
                        break
                    }
                }
            } label: {
                Label("Export Settings", systemImage: "gearshape")
            }
        } header: {
            Text("Data Export")
        } footer: {
            Text("Export your data to share with other apps or back up to cloud storage.")
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
            Text("This will permanently delete all walks, photos, and local data from this device. Cloud data will not be affected.")
        }
    }
}

class DataManagementViewModel: ObservableObject {
    @Published var totalStorageUsed: Int64 = 0
    @Published var walkDataSize: Int64 = 0
    @Published var photoDataSize: Int64 = 0
    @Published var cacheSize: Int64 = 0
    @Published var autoClearCache: Bool = false
    @Published var offlineMapsEnabled: Bool = false

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

    func exportAllData(completion: @escaping (Result<URL, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try JSONEncoder().encode(["exported": "all_data"])
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("woofwalk_full_export_\(Date().timeIntervalSince1970).json")
                try data.write(to: tempURL)

                DispatchQueue.main.async {
                    completion(.success(tempURL))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    func exportWalkHistory(completion: @escaping (Result<URL, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try JSONEncoder().encode(["exported": "walks"])
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("woofwalk_walks_\(Date().timeIntervalSince1970).json")
                try data.write(to: tempURL)

                DispatchQueue.main.async {
                    completion(.success(tempURL))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    func exportSettings(completion: @escaping (Result<URL, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try JSONEncoder().encode(["exported": "settings"])
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("woofwalk_settings_\(Date().timeIntervalSince1970).json")
                try data.write(to: tempURL)

                DispatchQueue.main.async {
                    completion(.success(tempURL))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
}
