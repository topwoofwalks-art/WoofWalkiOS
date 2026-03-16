import Foundation
import CoreLocation
import Combine
@testable import WoofWalk

class MockLocationService: LocationServiceProtocol {
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isTracking: Bool = false

    var currentLocationPublisher: AnyPublisher<CLLocation?, Never> {
        $currentLocation.eraseToAnyPublisher()
    }

    var authorizationStatusPublisher: AnyPublisher<CLAuthorizationStatus, Never> {
        $authorizationStatus.eraseToAnyPublisher()
    }

    var isTrackingPublisher: AnyPublisher<Bool, Never> {
        $isTracking.eraseToAnyPublisher()
    }

    var requestAuthorizationCalled = false
    var startTrackingCalled = false
    var stopTrackingCalled = false

    func requestAuthorization() {
        requestAuthorizationCalled = true
        authorizationStatus = .authorizedWhenInUse
    }

    func startTracking() {
        startTrackingCalled = true
        isTracking = true
    }

    func stopTracking() {
        stopTrackingCalled = true
        isTracking = false
    }

    func simulateLocation(_ location: CLLocation) {
        currentLocation = location
    }

    func simulateAuthorizationChange(_ status: CLAuthorizationStatus) {
        authorizationStatus = status
    }
}
