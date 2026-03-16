import Foundation
import CoreLocation
import Combine

struct WalkingPathUiState {
    var isPathLayerEnabled: Bool = false
    var paths: [WalkingPath] = []
    var isLoading: Bool = false
    var error: String?
}

@MainActor
class WalkingPathViewModel: ObservableObject {
    @Published var uiState = WalkingPathUiState()

    private let repository = WalkingPathRepository.shared

    func togglePathLayer() {
        let newState = !uiState.isPathLayerEnabled
        print("[PATH_LAYER] Toggling path layer: \(newState)")
        uiState.isPathLayerEnabled = newState

        if !newState {
            Task {
                await repository.clearCache()
                uiState.paths = []
            }
        }
    }

    func loadPathsInViewport(bounds: [CLLocationCoordinate2D]) {
        guard uiState.isPathLayerEnabled, !bounds.isEmpty else {
            return
        }

        Task {
            uiState.isLoading = true

            do {
                let paths = try await repository.fetchWalkingPaths(bounds: bounds)
                print("[PATH_LAYER] Loaded \(paths.count) paths")
                uiState.paths = paths
                uiState.isLoading = false
            } catch {
                print("[PATH_LAYER] Failed to load paths: \(error)")
                uiState.isLoading = false
                uiState.error = error.localizedDescription
            }
        }
    }

    func loadPathsForRouting(start: CLLocationCoordinate2D, end: CLLocationCoordinate2D) {
        Task {
            print("[PATH_ROUTING] Finding paths from \(start) to \(end)")

            let paths = await repository.findPathsForRouting(start: start, end: end)
            print("[PATH_ROUTING] Found \(paths.count) paths for routing")
        }
    }

    func clearError() {
        uiState.error = nil
    }
}
