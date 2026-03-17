import Foundation
import SwiftUI
import CoreLocation
import Combine

@MainActor
class WalkingPathViewModel: ObservableObject {
    @Published var paths: [WalkingPath] = []
    @Published var selectedPath: WalkingPath?
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var showPathOverlays: Bool = true
    @Published var filterByPathType: Set<WalkingPath.PathType> = Set(WalkingPath.PathType.allCases)

    private var cancellables = Set<AnyCancellable>()
    private let radiusMeters: Double = 5000

    func loadPathsNearby(center: CLLocationCoordinate2D, radius: Double? = nil) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let searchRadius = radius ?? radiusMeters
            paths = try await fetchPathsFromFirestore(
                center: center,
                radiusMeters: searchRadius
            )
            applyFilters()
        } catch {
            self.error = "Failed to load walking paths: \(error.localizedDescription)"
            print("Error loading paths: \(error)")
        }
    }

    func selectPath(_ path: WalkingPath) {
        selectedPath = path
    }

    func deselectPath() {
        selectedPath = nil
    }

    func getPathQualityScore(_ path: WalkingPath) -> Double {
        return path.qualityScore / 15.0 // Normalize to 0-1 range
    }

    func getRecommendedPaths(for dogSize: DogSize, maxPriority: Int = 5) -> [WalkingPath] {
        paths.filter { path in
            let qualityScore = getPathQualityScore(path)
            return qualityScore >= 0.5 && path.isPedestrian
        }.sorted { getPathQualityScore($0) > getPathQualityScore($1) }
    }

    func findNearestPath(to coordinate: CLLocationCoordinate2D) -> WalkingPath? {
        var nearest: WalkingPath?
        var minDistance = Double.infinity

        for path in paths {
            for coord in path.coordinates {
                let distance = haversineDistance(
                    from: coordinate,
                    to: coord.clLocationCoordinate2D
                )

                if distance < minDistance {
                    minDistance = distance
                    nearest = path
                }
            }
        }

        return nearest
    }

    func togglePathOverlays() {
        showPathOverlays.toggle()
    }

    func togglePathTypeFilter(_ pathType: WalkingPath.PathType) {
        if filterByPathType.contains(pathType) {
            filterByPathType.remove(pathType)
        } else {
            filterByPathType.insert(pathType)
        }
        applyFilters()
    }

    func clearFilters() {
        filterByPathType = Set(WalkingPath.PathType.allCases)
        applyFilters()
    }

    private func applyFilters() {
    }

    private func haversineDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let R = 6371000.0
        let dLat = (to.latitude - from.latitude) * .pi / 180.0
        let dLng = (to.longitude - from.longitude) * .pi / 180.0

        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(from.latitude * .pi / 180.0) * cos(to.latitude * .pi / 180.0) *
                sin(dLng / 2) * sin(dLng / 2)

        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }

    private func fetchPathsFromFirestore(center: CLLocationCoordinate2D, radiusMeters: Double) async throws -> [WalkingPath] {
        return []
    }
}

enum DogSize: String, Codable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    case giant = "giant"
}
