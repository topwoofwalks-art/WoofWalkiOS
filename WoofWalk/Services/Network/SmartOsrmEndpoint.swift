import Foundation

/// Routes OSRM calls between a self-hosted UK service (Primary) and the public
/// router (Backup), based on coordinates and on Primary availability.
///
///   - UK coordinates  → Primary first, falls back to Backup on any failure
///   - Non-UK coords   → Backup directly (Primary is UK-data-only)
///
/// "Is UK?" is a generous bounding box (49.5–61.0 N, -8.5–2.0 E) covering GB,
/// Northern Ireland, the Channel Islands, and the Isle of Man. A sliver of
/// Brittany / NW France / IE west coast will misclassify as UK and get a
/// nonsense Primary response — the failover then routes them to Backup.
///
/// Mirrors the Android `SmartOsrmService` shape.
enum SmartOsrmEndpoint {
    static let primaryBase = "http://178.105.124.133:5000"
    static let backupBase  = "https://router.project-osrm.org"

    static func isUk(coordinates: String) -> Bool {
        guard let first = coordinates.split(separator: ";").first else { return false }
        let parts = first.split(separator: ",")
        guard parts.count >= 2,
              let lon = Double(parts[0]),
              let lat = Double(parts[1]) else { return false }
        return lat >= 49.5 && lat <= 61.0 && lon >= -8.5 && lon <= 2.0
    }

    /// Fetch raw data from OSRM with Primary→Backup failover for UK coords.
    /// `path` is the path component including coordinates, e.g. "/route/v1/foot/0.1,51.5;...".
    /// Throws if every attempt fails. Treats 5xx HTTP as Primary failure (triggers fallback).
    static func loadData(
        path: String,
        coordinates: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> (Data, URLResponse) {
        let bases: [String] = isUk(coordinates: coordinates)
            ? [primaryBase, backupBase]
            : [backupBase]

        var lastError: Error = URLError(.badURL)

        for base in bases {
            guard var components = URLComponents(string: "\(base)\(path)") else {
                lastError = URLError(.badURL)
                continue
            }
            if !queryItems.isEmpty {
                components.queryItems = queryItems
            }
            guard let url = components.url else { continue }

            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let http = response as? HTTPURLResponse, http.statusCode >= 500 {
                    lastError = URLError(.badServerResponse)
                    if base == primaryBase {
                        print("[SmartOsrm] Primary returned \(http.statusCode), falling back to Backup")
                    }
                    continue
                }
                return (data, response)
            } catch {
                lastError = error
                if base == primaryBase {
                    print("[SmartOsrm] Primary failed (\(error.localizedDescription)), falling back to Backup")
                }
            }
        }
        throw lastError
    }
}
