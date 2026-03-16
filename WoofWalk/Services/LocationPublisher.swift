import CoreLocation
import Combine

class LocationPublisher {
    private let locationService: LocationService
    private var cancellables = Set<AnyCancellable>()

    let locationUpdates: AnyPublisher<LocationUpdate, Never>
    let filteredLocationUpdates: AnyPublisher<LocationUpdate, Never>

    private let minAccuracy: CLLocationAccuracy
    private let debounceInterval: TimeInterval

    init(
        locationService: LocationService = .shared,
        minAccuracy: CLLocationAccuracy = 50.0,
        debounceInterval: TimeInterval = 0.3
    ) {
        self.locationService = locationService
        self.minAccuracy = minAccuracy
        self.debounceInterval = debounceInterval

        self.locationUpdates = locationService.locationUpdatePublisher
            .eraseToAnyPublisher()

        self.filteredLocationUpdates = locationService.locationUpdatePublisher
            .filter { update in
                update.accuracy <= minAccuracy && update.accuracy >= 0
            }
            .debounce(for: .seconds(debounceInterval), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func startTracking(
        accuracy: CLLocationAccuracy = kCLLocationAccuracyBest,
        distanceFilter: CLLocationDistance = kCLDistanceFilterNone
    ) {
        locationService.startUpdatingLocation(accuracy: accuracy, distanceFilter: distanceFilter)
    }

    func stopTracking() {
        locationService.stopUpdatingLocation()
    }

    func subscribe(
        onUpdate: @escaping (LocationUpdate) -> Void,
        useFiltered: Bool = true
    ) -> AnyCancellable {
        let publisher = useFiltered ? filteredLocationUpdates : locationUpdates
        return publisher.sink(receiveValue: onUpdate)
    }
}

// MARK: - Walk Tracking Publisher

class WalkTrackingLocationPublisher: ObservableObject {
    private let locationService: LocationService
    private var cancellables = Set<AnyCancellable>()

    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var currentSpeed: CLLocationSpeed = 0
    @Published var currentBearing: CLLocationDirection = 0
    @Published var gpsQuality: GPSQuality = .unknown
    @Published var trackPoints: [LocationTrackPoint] = []
    @Published var polyline: [CLLocationCoordinate2D] = []

    private var lastLocation: CLLocation?
    private var lastUpdateTime: Date?
    private var totalDistance: CLLocationDistance = 0
    private var isPaused = false

    private let minAccuracyMeters: CLLocationAccuracy = 50.0
    private let minDistanceMeters: CLLocationDistance = 2.0
    private let autoPauseThresholdMps: CLLocationSpeed = 0.3
    private let autoPauseTimeSeconds: TimeInterval = 30.0

    init(locationService: LocationService = .shared) {
        self.locationService = locationService
        setupSubscriptions()
    }

    private func setupSubscriptions() {
        locationService.locationUpdatePublisher
            .filter { [weak self] update in
                guard let self = self else { return false }
                return update.accuracy <= self.minAccuracyMeters && update.accuracy >= 0
            }
            .sink { [weak self] update in
                self?.handleLocationUpdate(update)
            }
            .store(in: &cancellables)
    }

    func startTracking() {
        resetTracking()
        locationService.startUpdatingLocation(
            accuracy: kCLLocationAccuracyBest,
            distanceFilter: kCLDistanceFilterNone
        )
        locationService.startUpdatingHeading()
        isPaused = false
    }

    func pauseTracking() {
        isPaused = true
    }

    func resumeTracking() {
        isPaused = false
    }

    func stopTracking() {
        locationService.stopUpdatingLocation()
        locationService.stopUpdatingHeading()
        isPaused = false
    }

    private func resetTracking() {
        trackPoints.removeAll()
        polyline.removeAll()
        totalDistance = 0
        lastLocation = nil
        lastUpdateTime = nil
    }

    private func handleLocationUpdate(_ update: LocationUpdate) {
        guard !isPaused else { return }

        currentLocation = update.coordinate
        currentSpeed = update.speed
        currentBearing = update.course
        gpsQuality = update.gpsQuality

        let location = CLLocation(
            coordinate: update.coordinate,
            altitude: update.altitude ?? 0,
            horizontalAccuracy: update.accuracy,
            verticalAccuracy: -1,
            course: update.course,
            speed: update.speed,
            timestamp: update.timestamp
        )

        checkAutoPause(location: location)

        guard !isPaused else { return }

        if let lastLoc = lastLocation {
            let distance = location.distance(from: lastLoc)

            if distance >= minDistanceMeters {
                totalDistance += distance

                let trackPoint = LocationTrackPoint(
                    timestamp: update.timestamp.timeIntervalSince1970,
                    latitude: update.coordinate.latitude,
                    longitude: update.coordinate.longitude,
                    accuracy: update.accuracy
                )

                trackPoints.append(trackPoint)
                polyline.append(update.coordinate)
                lastLocation = location
            }
        } else {
            let trackPoint = LocationTrackPoint(
                timestamp: update.timestamp.timeIntervalSince1970,
                latitude: update.coordinate.latitude,
                longitude: update.coordinate.longitude,
                accuracy: update.accuracy
            )

            trackPoints.append(trackPoint)
            polyline.append(update.coordinate)
            lastLocation = location
        }

        lastUpdateTime = Date()
    }

    private func checkAutoPause(location: CLLocation) {
        guard let lastUpdate = lastUpdateTime else { return }

        let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdate)

        if location.speed < autoPauseThresholdMps &&
           timeSinceLastUpdate > autoPauseTimeSeconds &&
           !isPaused {
            pauseTracking()
            NotificationCenter.default.post(name: .walkAutoPaused, object: nil)
        }
    }

    var distanceMeters: CLLocationDistance {
        totalDistance
    }

    var distanceKilometers: Double {
        totalDistance / 1000.0
    }
}

// MARK: - Track Point Model

struct LocationTrackPoint: Codable, Identifiable {
    let id = UUID()
    let timestamp: TimeInterval
    let latitude: Double
    let longitude: Double
    let accuracy: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    enum CodingKeys: String, CodingKey {
        case timestamp = "t"
        case latitude = "lat"
        case longitude = "lng"
        case accuracy = "acc"
    }
}

// MARK: - Speed & ETA Calculator

class SpeedETACalculator {
    static func calculatePaceKmh(distanceMeters: CLLocationDistance, durationSeconds: TimeInterval) -> Double {
        guard durationSeconds > 0, distanceMeters > 50 else { return 0.0 }
        let distanceKm = distanceMeters / 1000.0
        let durationHours = durationSeconds / 3600.0
        return distanceKm / durationHours
    }

    static func calculateAveragePaceMinPerKm(distanceMeters: CLLocationDistance, durationSeconds: TimeInterval) -> Double {
        guard distanceMeters > 50 else { return 0.0 }
        let distanceKm = distanceMeters / 1000.0
        let durationMinutes = durationSeconds / 60.0
        return durationMinutes / distanceKm
    }

    static func calculateETA(
        remainingDistanceMeters: CLLocationDistance,
        averageSpeedKmh: Double
    ) -> TimeInterval {
        guard averageSpeedKmh > 0 else { return 0 }
        let remainingDistanceKm = remainingDistanceMeters / 1000.0
        let hoursRemaining = remainingDistanceKm / averageSpeedKmh
        return hoursRemaining * 3600.0
    }

    static func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }

    static func formatDistance(_ meters: CLLocationDistance) -> String {
        if meters < 1000 {
            return String(format: "%.0f m", meters)
        } else {
            let km = meters / 1000.0
            return String(format: "%.2f km", km)
        }
    }

    static func formatSpeed(_ kmh: Double) -> String {
        return String(format: "%.1f km/h", kmh)
    }

    static func formatPace(_ minPerKm: Double) -> String {
        let minutes = Int(minPerKm)
        let seconds = Int((minPerKm - Double(minutes)) * 60)
        return String(format: "%d:%02d /km", minutes, seconds)
    }
}

// MARK: - Polyline Encoding

class PolylineEncoder {
    static func encode(coordinates: [CLLocationCoordinate2D]) -> String {
        var result = ""
        var prevLat = 0
        var prevLng = 0

        for coordinate in coordinates {
            let lat = Int(coordinate.latitude * 1e5)
            let lng = Int(coordinate.longitude * 1e5)

            let dLat = lat - prevLat
            let dLng = lng - prevLng

            encodeValue(dLat, to: &result)
            encodeValue(dLng, to: &result)

            prevLat = lat
            prevLng = lng
        }

        return result
    }

    private static func encodeValue(_ value: Int, to result: inout String) {
        var v = value < 0 ? ~(value << 1) : (value << 1)
        while v >= 0x20 {
            let char = Character(UnicodeScalar((0x20 | (v & 0x1f)) + 63)!)
            result.append(char)
            v >>= 5
        }
        result.append(Character(UnicodeScalar(v + 63)!))
    }

    static func decode(encodedPolyline: String) -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []
        var index = encodedPolyline.startIndex
        var lat = 0
        var lng = 0

        while index < encodedPolyline.endIndex {
            var b: Int
            var shift = 0
            var result = 0

            repeat {
                b = Int(encodedPolyline[index].asciiValue!) - 63
                index = encodedPolyline.index(after: index)
                result |= (b & 0x1f) << shift
                shift += 5
            } while b >= 0x20

            let dLat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1))
            lat += dLat

            shift = 0
            result = 0

            repeat {
                b = Int(encodedPolyline[index].asciiValue!) - 63
                index = encodedPolyline.index(after: index)
                result |= (b & 0x1f) << shift
                shift += 5
            } while b >= 0x20

            let dLng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1))
            lng += dLng

            let coordinate = CLLocationCoordinate2D(
                latitude: Double(lat) / 1e5,
                longitude: Double(lng) / 1e5
            )
            coordinates.append(coordinate)
        }

        return coordinates
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let walkAutoPaused = Notification.Name("walkAutoPaused")
}
