import CoreLocation
import Foundation
import HealthKit
import WatchKit

class WalkTracker: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var isWalking = false
    @Published var distanceKm: Double = 0.0
    @Published var durationSeconds: Int = 0
    @Published var currentPace: String = "Standing"
    @Published var heartRate: Int = 0
    @Published var lastLat: Double = 0.0
    @Published var lastLng: Double = 0.0

    private let locationManager = CLLocationManager()
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var timer: Timer?
    private var startTime: Date?
    private var lastLocation: CLLocation?
    private var totalDistanceMeters: Double = 0.0
    private(set) var gpsPoints: [(lat: Double, lng: Double, alt: Double, speed: Double, time: Date)] = []

    var formattedDuration: String {
        let hours = durationSeconds / 3600
        let minutes = (durationSeconds % 3600) / 60
        let seconds = durationSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var paceEmoji: String {
        switch currentPace {
        case "Strolling": return "\u{1F6B6}"
        case "Walking": return "\u{1F463}"
        case "Brisk": return "\u{1F3C3}"
        case "Running": return "\u{26A1}"
        default: return "\u{23F8}\u{FE0F}"
        }
    }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.requestWhenInUseAuthorization()
    }

    func startWalk(heartRateEnabled: Bool) {
        isWalking = true
        distanceKm = 0.0
        durationSeconds = 0
        currentPace = "Standing"
        heartRate = 0
        totalDistanceMeters = 0.0
        lastLocation = nil
        gpsPoints = []
        startTime = Date()

        locationManager.startUpdatingLocation()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.startTime else { return }
            self.durationSeconds = Int(Date().timeIntervalSince(start))
        }

        if heartRateEnabled {
            startHeartRateMonitoring()
        }
    }

    func stopWalk() {
        isWalking = false
        locationManager.stopUpdatingLocation()
        timer?.invalidate()
        timer = nil
        stopHeartRateMonitoring()
    }

    func sendSOS() {
        WKInterfaceDevice.current().play(.notification)
    }

    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isWalking, let location = locations.last else { return }

        if let prev = lastLocation {
            let delta = location.distance(from: prev)
            if delta > 1 && delta < 500 {
                totalDistanceMeters += delta
                distanceKm = totalDistanceMeters / 1000.0
            }
        }

        lastLocation = location
        lastLat = location.coordinate.latitude
        lastLng = location.coordinate.longitude

        gpsPoints.append((
            lat: location.coordinate.latitude,
            lng: location.coordinate.longitude,
            alt: location.altitude,
            speed: max(0, location.speed),
            time: Date()
        ))

        updatePace(speedMs: max(0, location.speed))
    }

    private func updatePace(speedMs: Double) {
        currentPace = switch speedMs {
        case ..<0.3: "Standing"
        case 0.3..<1.0: "Strolling"
        case 1.0..<1.8: "Walking"
        case 1.8..<2.5: "Brisk"
        default: "Running"
        }
    }

    // MARK: - Heart Rate
    private func startHeartRateMonitoring() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        healthStore.requestAuthorization(toShare: nil, read: [heartRateType]) { [weak self] success, _ in
            guard success else { return }
            self?.startHeartRateQuery()
        }
    }

    private func startHeartRateQuery() {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: HKQuery.predicateForSamples(withStart: Date(), end: nil),
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.processHeartRateSamples(samples)
        }

        query.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.processHeartRateSamples(samples)
        }

        healthStore.execute(query)
    }

    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], let latest = samples.last else { return }
        let hr = Int(latest.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
        DispatchQueue.main.async {
            self.heartRate = hr
        }
    }

    private func stopHeartRateMonitoring() {
        // HealthKit queries are stopped when the app closes
    }
}
