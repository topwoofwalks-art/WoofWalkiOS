import Foundation
import CoreLocation

// MARK: - Walk Tracking ViewModel

@MainActor
class WalkTrackingViewModel: ObservableObject {
    @Published var isWalkActive = false
    @Published var walkDistance: Double = 0
    @Published var walkDuration: TimeInterval = 0

    private var walkStartTime: Date?
    private var timer: Timer?

    func startWalk() {
        isWalkActive = true
        walkStartTime = Date()
        walkDistance = 0

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.walkStartTime else { return }
            self.walkDuration = Date().timeIntervalSince(startTime)
        }
    }

    func stopWalk() {
        isWalkActive = false
        timer?.invalidate()
        timer = nil
    }

    private var lastLocation: CLLocationCoordinate2D?

    func updateLocation(_ location: CLLocationCoordinate2D) {
        guard isWalkActive else { return }
        if let last = lastLocation {
            let distance = CLLocation(latitude: last.latitude, longitude: last.longitude)
                .distance(from: CLLocation(latitude: location.latitude, longitude: location.longitude))
            if distance > 1 && distance < 100 { // filter GPS jitter
                walkDistance += distance
            }
        }
        lastLocation = location
    }
}
