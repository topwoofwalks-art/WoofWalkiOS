import Foundation
import MapKit

struct UserSettings: Codable {
    var distanceUnit: DistanceUnit = .kilometers
    var speedUnit: SpeedUnit = .kilometersPerHour
    var theme: ThemeMode = .auto
    var mapStyle: MapStyleType = .standard
    var showTraffic: Bool = false
    var defaultWalkDistance: Double = 5.0
    var autoPauseSensitivity: AutoPauseSensitivity = .medium
    var backgroundTracking: Bool = true

    var notificationsEnabled: Bool = true
    var hazardAlertsEnabled: Bool = true
    var communityAlertsEnabled: Bool = false
    var walkRemindersEnabled: Bool = true

    var profileVisible: Bool = true
    var locationSharingEnabled: Bool = false

    var alertRadiusMeters: Int = 2000
    var soundEnabled: Bool = true
    var vibrationEnabled: Bool = true
    var headsUpEnabled: Bool = true
    var quietHoursEnabled: Bool = false
    var quietHoursStart: Int = 22
    var quietHoursEnd: Int = 7
    var enabledAlertTypes: Set<String> = ["hazard", "wildlife", "livestock"]
}

enum DistanceUnit: String, Codable, CaseIterable {
    case kilometers = "km"
    case miles = "mi"

    var displayName: String {
        switch self {
        case .kilometers: return "Kilometers"
        case .miles: return "Miles"
        }
    }

    func convert(_ meters: Double) -> Double {
        switch self {
        case .kilometers: return meters / 1000.0
        case .miles: return meters / 1609.34
        }
    }

    func toMeters(_ value: Double) -> Double {
        switch self {
        case .kilometers: return value * 1000.0
        case .miles: return value * 1609.34
        }
    }
}

enum SpeedUnit: String, Codable, CaseIterable {
    case kilometersPerHour = "km/h"
    case milesPerHour = "mph"
    case minPerKilometer = "min/km"
    case minPerMile = "min/mi"

    var displayName: String {
        switch self {
        case .kilometersPerHour: return "km/h"
        case .milesPerHour: return "mph"
        case .minPerKilometer: return "min/km"
        case .minPerMile: return "min/mi"
        }
    }

    func convert(metersPerSecond: Double) -> Double {
        switch self {
        case .kilometersPerHour:
            return metersPerSecond * 3.6
        case .milesPerHour:
            return metersPerSecond * 2.23694
        case .minPerKilometer:
            guard metersPerSecond > 0 else { return 0 }
            return 1000.0 / (metersPerSecond * 60.0)
        case .minPerMile:
            guard metersPerSecond > 0 else { return 0 }
            return 1609.34 / (metersPerSecond * 60.0)
        }
    }
}

enum ThemeMode: String, Codable, CaseIterable {
    case light
    case dark
    case auto

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .auto: return "Auto"
        }
    }
}

enum MapStyleType: String, Codable, CaseIterable {
    case standard
    case hybrid
    case satellite

    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .hybrid: return "Hybrid"
        case .satellite: return "Satellite"
        }
    }

    var mapType: MKMapType {
        switch self {
        case .standard: return .standard
        case .hybrid: return .hybrid
        case .satellite: return .satellite
        }
    }
}

enum AutoPauseSensitivity: String, Codable, CaseIterable {
    case low
    case medium
    case high
    case off

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .off: return "Off"
        }
    }

    var threshold: Double {
        switch self {
        case .low: return 0.3
        case .medium: return 0.5
        case .high: return 0.8
        case .off: return 0.0
        }
    }
}

enum GPSAccuracy: String, Codable, CaseIterable {
    case best
    case tenMeters
    case hundredMeters
    case kilometer

    var displayName: String {
        switch self {
        case .best: return "Best (High Battery)"
        case .tenMeters: return "10 meters"
        case .hundredMeters: return "100 meters"
        case .kilometer: return "1 kilometer (Low Battery)"
        }
    }

    var accuracy: Double {
        switch self {
        case .best: return -1
        case .tenMeters: return 10
        case .hundredMeters: return 100
        case .kilometer: return 1000
        }
    }
}
