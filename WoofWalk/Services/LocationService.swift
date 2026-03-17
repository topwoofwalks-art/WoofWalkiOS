import CoreLocation
import Combine
import SwiftUI

enum LocationAuthorizationStatus {
    case notDetermined
    case restricted
    case denied
    case authorizedWhenInUse
    case authorizedAlways
}

enum GPSQuality {
    case excellent  // < 10m
    case good       // 10-20m
    case fair       // 20-50m
    case poor       // > 50m
    case unknown

    static func from(accuracy: CLLocationAccuracy) -> GPSQuality {
        switch accuracy {
        case ..<10: return .excellent
        case 10..<20: return .good
        case 20..<50: return .fair
        case 50...: return .poor
        default: return .unknown
        }
    }
}

struct LocationUpdate {
    let coordinate: CLLocationCoordinate2D
    let altitude: CLLocationDistance?
    let accuracy: CLLocationAccuracy
    let course: CLLocationDirection
    let speed: CLLocationSpeed
    let timestamp: Date

    var gpsQuality: GPSQuality {
        GPSQuality.from(accuracy: accuracy)
    }
}

@MainActor
class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: LocationAuthorizationStatus = .notDetermined
    @Published var lastLocation: CLLocation?
    @Published var isUpdatingLocation = false
    @Published var heading: CLHeading?
    @Published var gpsQuality: GPSQuality = .unknown

    let locationUpdatePublisher = PassthroughSubject<LocationUpdate, Never>()
    let authorizationPublisher = PassthroughSubject<LocationAuthorizationStatus, Never>()

    private var distanceFilter: CLLocationDistance = kCLDistanceFilterNone
    private var desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyBest

    private override init() {
        super.init()
        setupLocationManager()
    }

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.activityType = .fitness
        locationManager.pausesLocationUpdatesAutomatically = false

        if #available(iOS 14.0, *) {
            locationManager.allowsBackgroundLocationUpdates = true
        }

        updateAuthorizationStatus()
    }

    // MARK: - Authorization

    func requestWhenInUseAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }

    private func updateAuthorizationStatus() {
        let status: LocationAuthorizationStatus

        if #available(iOS 14.0, *) {
            switch locationManager.authorizationStatus {
            case .notDetermined:
                status = .notDetermined
            case .restricted:
                status = .restricted
            case .denied:
                status = .denied
            case .authorizedWhenInUse:
                status = .authorizedWhenInUse
            case .authorizedAlways:
                status = .authorizedAlways
            @unknown default:
                status = .notDetermined
            }
        } else {
            switch CLLocationManager.authorizationStatus() {
            case .notDetermined:
                status = .notDetermined
            case .restricted:
                status = .restricted
            case .denied:
                status = .denied
            case .authorizedWhenInUse:
                status = .authorizedWhenInUse
            case .authorizedAlways:
                status = .authorizedAlways
            @unknown default:
                status = .notDetermined
            }
        }

        authorizationStatus = status
        authorizationPublisher.send(status)
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    // MARK: - Location Updates

    func startUpdatingLocation(accuracy: CLLocationAccuracy = kCLLocationAccuracyBest,
                              distanceFilter: CLLocationDistance = kCLDistanceFilterNone) {
        guard isAuthorized else {
            print("Location not authorized")
            return
        }

        locationManager.desiredAccuracy = accuracy
        locationManager.distanceFilter = distanceFilter
        self.desiredAccuracy = accuracy
        self.distanceFilter = distanceFilter

        locationManager.startUpdatingLocation()
        isUpdatingLocation = true

        print("Started location updates - accuracy: \(accuracy)m, distanceFilter: \(distanceFilter)m")
    }

    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
        isUpdatingLocation = false
        print("Stopped location updates")
    }

    func getCurrentLocation(timeout: TimeInterval = 10.0) async throws -> CLLocationCoordinate2D {
        guard isAuthorized else {
            throw LocationError.notAuthorized
        }

        if let lastLocation = lastLocation,
           Date().timeIntervalSince(lastLocation.timestamp) < 5.0 {
            return lastLocation.coordinate
        }

        return try await withCheckedThrowingContinuation { continuation in
            nonisolated(unsafe) var hasReturned = false
            nonisolated(unsafe) var timeoutTask: Task<Void, Never>?

            let observer = locationUpdatePublisher
                .first()
                .sink { update in
                    guard !hasReturned else { return }
                    hasReturned = true
                    timeoutTask?.cancel()
                    continuation.resume(returning: update.coordinate)
                }

            timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                guard !hasReturned else { return }
                hasReturned = true
                observer.cancel()

                if let last = self.lastLocation {
                    continuation.resume(returning: last.coordinate)
                } else {
                    continuation.resume(throwing: LocationError.timeout)
                }
            }

            if !isUpdatingLocation {
                startUpdatingLocation()
            }
        }
    }

    // MARK: - Heading Updates

    func startUpdatingHeading() {
        guard CLLocationManager.headingAvailable() else {
            print("Heading not available on this device")
            return
        }
        locationManager.startUpdatingHeading()
    }

    func stopUpdatingHeading() {
        locationManager.stopUpdatingHeading()
    }

    // MARK: - Significant Location Changes

    func startMonitoringSignificantLocationChanges() {
        guard CLLocationManager.significantLocationChangeMonitoringAvailable() else {
            print("Significant location change monitoring not available")
            return
        }
        locationManager.startMonitoringSignificantLocationChanges()
        print("Started monitoring significant location changes")
    }

    func stopMonitoringSignificantLocationChanges() {
        locationManager.stopMonitoringSignificantLocationChanges()
        print("Stopped monitoring significant location changes")
    }

    // MARK: - Region Monitoring (Geofencing)

    func startMonitoring(region: CLRegion) {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            print("Region monitoring not available")
            return
        }

        locationManager.startMonitoring(for: region)
        print("Started monitoring region: \(region.identifier)")
    }

    func stopMonitoring(region: CLRegion) {
        locationManager.stopMonitoring(for: region)
        print("Stopped monitoring region: \(region.identifier)")
    }

    func stopMonitoringAllRegions() {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        print("Stopped monitoring all regions")
    }

    // MARK: - Geocoding

    func geocode(address: String) async throws -> CLLocation {
        let placemarks = try await geocoder.geocodeAddressString(address)
        guard let location = placemarks.first?.location else {
            throw LocationError.geocodingFailed
        }
        return location
    }

    func reverseGeocode(location: CLLocation) async throws -> CLPlacemark {
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        guard let placemark = placemarks.first else {
            throw LocationError.geocodingFailed
        }
        return placemark
    }

    // MARK: - Distance Calculation

    func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDistance {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }

    func calculateDistance(from: CLLocation, to: CLLocation) -> CLLocationDistance {
        return from.distance(from: to)
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            updateAuthorizationStatus()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            let coordinate = location.coordinate
            currentLocation = coordinate
            lastLocation = location
            gpsQuality = GPSQuality.from(accuracy: location.horizontalAccuracy)

            let update = LocationUpdate(
                coordinate: coordinate,
                altitude: location.altitude,
                accuracy: location.horizontalAccuracy,
                course: location.course,
                speed: location.speed,
                timestamp: location.timestamp
            )

            locationUpdatePublisher.send(update)

            print("Location update: lat=\(coordinate.latitude), lng=\(coordinate.longitude), accuracy=\(location.horizontalAccuracy)m, GPS=\(gpsQuality)")
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        Task { @MainActor in
            heading = newHeading
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("Did enter region: \(region.identifier)")
        NotificationCenter.default.post(
            name: .didEnterRegion,
            object: nil,
            userInfo: ["region": region]
        )
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("Did exit region: \(region.identifier)")
        NotificationCenter.default.post(
            name: .didExitRegion,
            object: nil,
            userInfo: ["region": region]
        )
    }

    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("Monitoring failed for region: \(region?.identifier ?? "unknown") - \(error.localizedDescription)")
    }
}

// MARK: - Errors

enum LocationError: LocalizedError {
    case notAuthorized
    case timeout
    case geocodingFailed
    case invalidLocation
    case permissionDenied
    case locationUnavailable
    case trackingFailed

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Location access not authorized"
        case .timeout:
            return "Location request timed out"
        case .geocodingFailed:
            return "Failed to geocode location"
        case .invalidLocation:
            return "Invalid location"
        case .permissionDenied:
            return "Location access is required. Please enable location permissions in Settings."
        case .locationUnavailable:
            return "Unable to determine your location"
        case .trackingFailed:
            return "Location tracking failed"
        }
    }
}

// MARK: - Notification Names

extension NSNotification.Name {
    static let didEnterRegion = NSNotification.Name("didEnterRegion")
    static let didExitRegion = NSNotification.Name("didExitRegion")
}
