import Foundation

class DynamicWorldCacheManager {
    static let shared = DynamicWorldCacheManager()

    private let cacheDirectory: URL
    private let fileManager = FileManager.default
    private let cacheExpirationDays = 30

    private init() {
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.cacheDirectory = cacheDir.appendingPathComponent("DynamicWorld", isDirectory: true)

        try? fileManager.createDirectory(
            at: cacheDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    func cacheData(_ data: DynamicWorldData) throws {
        let fileURL = cacheFileURL(for: data.fieldId)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let jsonData = try encoder.encode(data)
        try jsonData.write(to: fileURL)

        print("[DW_CACHE] Cached data for field: \(data.fieldId)")
    }

    func getCachedData(forFieldId fieldId: String) throws -> DynamicWorldData? {
        let fileURL = cacheFileURL(for: fieldId)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let cachedData = try decoder.decode(DynamicWorldData.self, from: data)

        if cachedData.isExpired {
            try? fileManager.removeItem(at: fileURL)
            print("[DW_CACHE] Removed expired cache for field: \(fieldId)")
            return nil
        }

        print("[DW_CACHE] Retrieved cached data for field: \(fieldId)")
        return cachedData
    }

    func clearCache() throws {
        let contents = try fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil
        )

        for fileURL in contents {
            try fileManager.removeItem(at: fileURL)
        }

        print("[DW_CACHE] Cleared all cached data")
    }

    func clearExpiredCache() throws {
        let contents = try fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil
        )

        var expiredCount = 0
        for fileURL in contents {
            do {
                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let cachedData = try decoder.decode(DynamicWorldData.self, from: data)

                if cachedData.isExpired {
                    try fileManager.removeItem(at: fileURL)
                    expiredCount += 1
                }
            } catch {
                try? fileManager.removeItem(at: fileURL)
                expiredCount += 1
            }
        }

        if expiredCount > 0 {
            print("[DW_CACHE] Cleared \(expiredCount) expired cache entries")
        }
    }

    func getCacheSize() -> Int64 {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else {
            return 0
        }

        var totalSize: Int64 = 0
        for fileURL in contents {
            if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let fileSize = attributes[.size] as? Int64 {
                totalSize += fileSize
            }
        }

        return totalSize
    }

    func getCacheStats() -> (count: Int, sizeBytes: Int64, oldestDate: Date?) {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]
        ) else {
            return (0, 0, nil)
        }

        var totalSize: Int64 = 0
        var oldestDate: Date?

        for fileURL in contents {
            if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path) {
                if let fileSize = attributes[.size] as? Int64 {
                    totalSize += fileSize
                }
                if let creationDate = attributes[.creationDate] as? Date {
                    if oldestDate == nil || creationDate < oldestDate! {
                        oldestDate = creationDate
                    }
                }
            }
        }

        return (contents.count, totalSize, oldestDate)
    }

    private func cacheFileURL(for fieldId: String) -> URL {
        let sanitizedId = fieldId.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return cacheDirectory.appendingPathComponent("\(sanitizedId).json")
    }
}
