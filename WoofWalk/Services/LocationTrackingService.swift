import Foundation
import CoreLocation
import Combine
import UIKit
import UserNotifications

/// Service for continuous location tracking during walks
/// Handles foreground and background location updates
@MainActor
class LocationTrackingService: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var isTracking: Bool = false
    @Published private(set) var isPaused: Bool = false
    @Published var error: Error?

    // MARK: - Publishers
    private let locationSubject = PassthroughSubject<CLLocation, Never>()
    var locationPublisher: AnyPublisher<CLLocation, Never> {
        locationSubject.eraseToAnyPublisher()
    }

    // MARK: - Private Properties
    private let locationManager: CLLocationManager
    private let filterPipeline = GPSFilterPipeline()
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var lastLocationUpdate: Date?
    private var minimumDistance: CLLocationDistance = 10.0 // meters
    private var minimumTimeInterval: TimeInterval = 5.0 // seconds

    // MARK: - Configuration
    struct TrackingConfiguration {
        var desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyBest
        var distanceFilter: CLLocationDistance = 10.0
        var allowsBackgroundLocationUpdates: Bool = true
        var pausesLocationUpdatesAutomatically: Bool = false
        var activityType: CLActivityType = .fitness
    }

    private var configuration: TrackingConfiguration

    // MARK: - Initialization
    override init() {
        self.locationManager = CLLocationManager()
        self.configuration = TrackingConfiguration()

        super.init()

        setupLocationManager()
        setupBackgroundObservers()
    }

    // MARK: - Setup
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = configuration.desiredAccuracy
        locationManager.distanceFilter = configuration.distanceFilter
        locationManager.pausesLocationUpdatesAutomatically = configuration.pausesLocationUpdatesAutomatically
        locationManager.activityType = configuration.activityType

        // Enable background location updates
        if configuration.allowsBackgroundLocationUpdates {
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.showsBackgroundLocationIndicator = true
        }

        // Update authorization status
        authorizationStatus = locationManager.authorizationStatus
    }

    private func setupBackgroundObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    // MARK: - Authorization
    func requestWhenInUseAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }

    func hasLocationPermission() -> Bool {
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }

    // MARK: - Tracking Control
    func startTracking() {
        guard hasLocationPermission() else {
            print("Location permission not granted")
            error = LocationError.permissionDenied
            return
        }

        guard !isTracking else {
            print("Tracking already started")
            return
        }

        isTracking = true
        isPaused = false

        locationManager.startUpdatingLocation()

        // Start heading updates for UI bearing display
        if CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
        }

        startBackgroundTask()

        print("Location tracking started")
    }

    func pauseTracking() {
        guard isTracking, !isPaused else { return }

        isPaused = true
        locationManager.stopUpdatingLocation()

        print("Location tracking paused")
    }

    func resumeTracking() {
        guard isTracking, isPaused else { return }

        isPaused = false
        locationManager.startUpdatingLocation()

        print("Location tracking resumed")
    }

    func stopTracking() {
        guard isTracking else { return }

        isTracking = false
        isPaused = false

        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        endBackgroundTask()

        print("Location tracking stopped")
    }

    // MARK: - Background Tasks
    private func startBackgroundTask() {
        guard backgroundTask == .invalid else { return }

        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }

        print("Background task started: \(backgroundTask.rawValue)")
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }

        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid

        print("Background task ended")
    }

    // MARK: - Background Notifications
    @objc private func appDidEnterBackground() {
        guard isTracking else { return }

        print("App entered background - continuing location tracking")
        startBackgroundTask()

        // Send local notification
        sendBackgroundNotification(
            title: "WoofWalk Active",
            body: "Walk tracking is running in the background"
        )
    }

    @objc private func appWillEnterForeground() {
        guard isTracking else { return }

        print("App entering foreground - location tracking continues")
    }

    // MARK: - Local Notifications
    private func sendBackgroundNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: "walk_tracking_background",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending notification: \(error)")
            }
        }
    }

    // MARK: - Location Filtering
    private func shouldAcceptLocation(_ location: CLLocation) -> Bool {
        // Filter out inaccurate locations
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= 50 else {
            print("Location rejected - poor accuracy: \(location.horizontalAccuracy)m")
            return false
        }

        // Filter by minimum distance
        if let lastLocation = currentLocation {
            let distance = location.distance(from: lastLocation)
            guard distance >= minimumDistance else {
                return false
            }
        }

        // Filter by minimum time interval
        if let lastUpdate = lastLocationUpdate {
            let timeInterval = location.timestamp.timeIntervalSince(lastUpdate)
            guard timeInterval >= minimumTimeInterval else {
                return false
            }
        }

        return true
    }

    // MARK: - Configuration Updates
    func updateConfiguration(_ config: TrackingConfiguration) {
        self.configuration = config
        setupLocationManager()

        if isTracking {
            locationManager.stopUpdatingLocation()
            locationManager.startUpdatingLocation()
        }
    }

    // MARK: - Cleanup
    deinit {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationTrackingService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            // Filter location
            guard shouldAcceptLocation(location) else { return }

            // Update properties
            currentLocation = location
            lastLocationUpdate = location.timestamp

            // Publish to subscribers
            locationSubject.send(location)

            print("Location updated: (\(location.coordinate.latitude), \(location.coordinate.longitude)) - accuracy: \(location.horizontalAccuracy)m")
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error.localizedDescription)")
        Task { @MainActor in
            self.error = error
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let newStatus = manager.authorizationStatus
        print("Authorization status changed: \(newStatus.rawValue)")
        Task { @MainActor in
            authorizationStatus = newStatus

            switch newStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                print("Location permission granted")
            case .denied, .restricted:
                print("Location permission denied")
                if isTracking {
                    stopTracking()
                }
                error = LocationError.permissionDenied
            case .notDetermined:
                print("Location permission not determined")
            @unknown default:
                print("Unknown authorization status")
            }
        }
    }

    nonisolated func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        print("Location updates paused by system")
    }

    nonisolated func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
        print("Location updates resumed by system")
    }
}

// LocationError is defined in LocationService.swift

// MARK: - CLAuthorizationStatus Extension
extension CLAuthorizationStatus {
    var description: String {
        switch self {
        case .notDetermined:
            return "Not Determined"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorizedAlways:
            return "Authorized Always"
        case .authorizedWhenInUse:
            return "Authorized When In Use"
        @unknown default:
            return "Unknown"
        }
    }
}
