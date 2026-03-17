import Foundation
import CoreLocation
import Combine
import UserNotifications

struct GeofenceRegion {
    let identifier: String
    let coordinate: CLLocationCoordinate2D
    let radius: CLLocationDistance
    let title: String
    let notifyOnEntry: Bool
    let notifyOnExit: Bool

    var region: CLCircularRegion {
        let region = CLCircularRegion(
            center: coordinate,
            radius: radius,
            identifier: identifier
        )
        region.notifyOnEntry = notifyOnEntry
        region.notifyOnExit = notifyOnExit
        return region
    }
}

class GeofenceManager: ObservableObject {
    static let shared = GeofenceManager()

    private let locationService: LocationService
    private var registeredRegions: [String: GeofenceRegion] = [:]

    @Published var activeGeofences: Set<String> = []

    private let maxGeofenceCount = 20
    private let defaultRadius: CLLocationDistance = 100

    private init(locationService: LocationService = .shared) {
        self.locationService = locationService
        setupNotificationObservers()
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRegionEntry(_:)),
            name: .didEnterRegion,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRegionExit(_:)),
            name: .didExitRegion,
            object: nil
        )
    }

    @objc private func handleRegionEntry(_ notification: Notification) {
        guard let region = notification.userInfo?["region"] as? CLRegion else { return }
        activeGeofences.insert(region.identifier)
        print("Entered geofence: \(region.identifier)")
    }

    @objc private func handleRegionExit(_ notification: Notification) {
        guard let region = notification.userInfo?["region"] as? CLRegion else { return }
        activeGeofences.remove(region.identifier)
        print("Exited geofence: \(region.identifier)")
    }

    // MARK: - Register Geofences

    func registerGeofence(
        identifier: String,
        coordinate: CLLocationCoordinate2D,
        radius: CLLocationDistance = 100,
        title: String = "",
        notifyOnEntry: Bool = true,
        notifyOnExit: Bool = false
    ) -> Result<Void, GeofenceError> {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            return .failure(.monitoringNotAvailable)
        }

        guard locationService.isAuthorized else {
            return .failure(.notAuthorized)
        }

        if registeredRegions.count >= maxGeofenceCount {
            return .failure(.limitExceeded)
        }

        let geofence = GeofenceRegion(
            identifier: identifier,
            coordinate: coordinate,
            radius: radius,
            title: title,
            notifyOnEntry: notifyOnEntry,
            notifyOnExit: notifyOnExit
        )

        registeredRegions[identifier] = geofence
        locationService.startMonitoring(region: geofence.region)

        print("Registered geofence: \(identifier) at \(coordinate)")
        return .success(())
    }

    func registerGeofences(
        pois: [POI],
        userLocation: CLLocationCoordinate2D,
        maxDistance: CLLocationDistance = 1000
    ) -> Result<Int, GeofenceError> {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            return .failure(.monitoringNotAvailable)
        }

        guard locationService.isAuthorized else {
            return .failure(.notAuthorized)
        }

        let nearbyPOIs = pois.filter { poi in
            let distance = locationService.calculateDistance(
                from: userLocation,
                to: CLLocationCoordinate2D(latitude: poi.lat, longitude: poi.lng)
            )
            return distance <= maxDistance
        }

        let sortedPOIs = nearbyPOIs.sorted { poi1, poi2 in
            let dist1 = locationService.calculateDistance(
                from: userLocation,
                to: CLLocationCoordinate2D(latitude: poi1.lat, longitude: poi1.lng)
            )
            let dist2 = locationService.calculateDistance(
                from: userLocation,
                to: CLLocationCoordinate2D(latitude: poi2.lat, longitude: poi2.lng)
            )
            return dist1 < dist2
        }

        var registeredCount = 0
        let availableSlots = maxGeofenceCount - registeredRegions.count

        for poi in sortedPOIs.prefix(availableSlots) {
            let identifier = "poi_\(poi.id)"

            if registeredRegions[identifier] == nil {
                let result = registerGeofence(
                    identifier: identifier,
                    coordinate: CLLocationCoordinate2D(
                        latitude: poi.lat,
                        longitude: poi.lng
                    ),
                    radius: defaultRadius,
                    title: poi.title,
                    notifyOnEntry: true,
                    notifyOnExit: false
                )

                if case .success = result {
                    registeredCount += 1
                }
            }
        }

        print("Registered \(registeredCount) new geofences")
        return .success(registeredCount)
    }

    // MARK: - Unregister Geofences

    func unregisterGeofence(identifier: String) {
        guard let geofence = registeredRegions[identifier] else { return }

        locationService.stopMonitoring(region: geofence.region)
        registeredRegions.removeValue(forKey: identifier)
        activeGeofences.remove(identifier)

        print("Unregistered geofence: \(identifier)")
    }

    func unregisterAllGeofences() {
        locationService.stopMonitoringAllRegions()
        registeredRegions.removeAll()
        activeGeofences.removeAll()

        print("Unregistered all geofences")
    }

    func removeExpiredGeofences(currentPOIs: [POI]) {
        let currentPOIIds = Set(currentPOIs.map { "poi_\($0.id)" })

        let expiredGeofences = registeredRegions.keys.filter { identifier in
            identifier.hasPrefix("poi_") && !currentPOIIds.contains(identifier)
        }

        for identifier in expiredGeofences {
            unregisterGeofence(identifier: identifier)
        }

        if !expiredGeofences.isEmpty {
            print("Removed \(expiredGeofences.count) expired geofences")
        }
    }

    // MARK: - Query

    func isInsideGeofence(identifier: String) -> Bool {
        activeGeofences.contains(identifier)
    }

    func getRegisteredGeofences() -> [GeofenceRegion] {
        Array(registeredRegions.values)
    }

    func getRegisteredGeofenceCount() -> Int {
        registeredRegions.count
    }
}

// POI model is defined in Models/POI/POI.swift

// MARK: - Errors

enum GeofenceError: LocalizedError {
    case notAuthorized
    case monitoringNotAvailable
    case limitExceeded
    case invalidRegion

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Location authorization required for geofencing"
        case .monitoringNotAvailable:
            return "Geofencing not available on this device"
        case .limitExceeded:
            return "Maximum number of geofences reached (20)"
        case .invalidRegion:
            return "Invalid geofence region"
        }
    }
}

// MARK: - Geofence Notifications

extension GeofenceManager {
    func enableGeofenceNotifications(for identifier: String, title: String, body: String) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            if granted {
                print("Notification permission granted for geofence: \(identifier)")
            }
        }
    }

    func showGeofenceNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Geofence notification error: \(error)")
            }
        }
    }
}

#if false
// MARK: - Helper Extensions
// CLLocationCoordinate2D Equatable/Hashable conformance defined elsewhere - wrapped to avoid invalid redeclaration

extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

extension CLLocationCoordinate2D: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(latitude)
        hasher.combine(longitude)
    }
}
#endif
