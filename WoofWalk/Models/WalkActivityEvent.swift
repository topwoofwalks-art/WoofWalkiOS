import Foundation
import CoreLocation

// MARK: - Walk Activity Event Type

/// Types of activity events that can be logged during a walk.
enum WalkActivityEventType: String, Codable, CaseIterable {
    case pee = "PEE"
    case poo = "POO"
    case water = "WATER"
    case feed = "FEED"
    case photo = "PHOTO"
    case note = "NOTE"
    case checkIn = "CHECK_IN"
    case play = "PLAY"
    case incident = "INCIDENT"

    var displayName: String {
        switch self {
        case .pee: return "Pee"
        case .poo: return "Poo"
        case .water: return "Water"
        case .feed: return "Feed"
        case .photo: return "Photo"
        case .note: return "Note"
        case .checkIn: return "Check In"
        case .play: return "Play"
        case .incident: return "Incident"
        }
    }

    var iconName: String {
        switch self {
        case .pee: return "drop.fill"
        case .poo: return "leaf.fill"
        case .water: return "cup.and.saucer.fill"
        case .feed: return "fork.knife"
        case .photo: return "camera.fill"
        case .note: return "note.text"
        case .checkIn: return "checkmark.circle.fill"
        case .play: return "figure.run"
        case .incident: return "exclamationmark.triangle.fill"
        }
    }

    static func from(string: String) -> WalkActivityEventType {
        return WalkActivityEventType(rawValue: string) ?? .note
    }
}

// MARK: - Walk Activity Event

/// An activity event logged by the walker during a walk (pee, poo, water, feed, etc.).
struct WalkActivityEvent: Identifiable, Codable, Equatable {
    let id: String
    let type: String
    let timestamp: Int64
    var note: String?
    var photoUrl: String?
    var latitude: Double?
    var longitude: Double?

    var eventType: WalkActivityEventType {
        WalkActivityEventType.from(string: type)
    }

    var location: CLLocationCoordinate2D? {
        guard let lat = latitude, let lng = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000.0)
    }

    init(
        id: String = UUID().uuidString,
        type: String,
        timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        note: String? = nil,
        photoUrl: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
        self.note = note
        self.photoUrl = photoUrl
        self.latitude = latitude
        self.longitude = longitude
    }
}

// MARK: - Connection Status

/// Connection status for live walk tracking.
enum ConnectionStatus: String, Codable {
    case connected = "CONNECTED"
    case delayed = "DELAYED"
    case lost = "LOST"
}

// MARK: - Live Walk Status

/// Status of a live walk session.
enum LiveWalkStatus: String, Codable {
    case connecting = "CONNECTING"
    case active = "ACTIVE"
    case paused = "PAUSED"
    case ended = "ENDED"
    case error = "ERROR"
}

// MARK: - Live Location Update

/// Wire-format location update from walker during live tracking.
/// Distinct from `LocationUpdate` (the in-memory CL form used by `LocationService`).
struct LiveLocationUpdate: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    let timestamp: Int64
    var accuracy: Float?
    var heading: Float?
    var speed: Float?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000.0)
    }
}

// MARK: - Live Walk Stats

/// Live statistics during an active walk.
struct LiveWalkStats: Codable, Equatable {
    var distanceKm: Double = 0.0
    var durationSeconds: Int64 = 0
    var currentPaceMinPerKm: Double?
    var estimatedEndTime: Int64?
    var averageSpeedKmh: Double?
}

// MARK: - Walk Photo Update

/// Photo taken during a walk.
struct WalkPhotoUpdate: Identifiable, Codable, Equatable {
    let photoId: String
    let url: String
    var thumbnailUrl: String?
    let timestamp: Int64
    var latitude: Double?
    var longitude: Double?
    var caption: String?

    var id: String { photoId }

    var location: CLLocationCoordinate2D? {
        guard let lat = latitude, let lng = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

// MARK: - Walker Info

/// Information about the walker.
struct WalkerInfo: Codable, Equatable {
    let id: String
    let name: String
    var photoUrl: String?
    let rating: Double
    var phoneNumber: String?
}

// MARK: - ETA Calculation

/// ETA calculation for walk return.
struct ETACalculation: Equatable {
    let estimatedReturnTime: Int64
    let remainingDistanceKm: Double
    let estimatedRemainingMinutes: Int
    let confidenceLevel: Double
}

// MARK: - Live Walk Session

/// Complete live walk session data.
struct LiveWalkSession: Identifiable, Equatable {
    let walkId: String
    var bookingId: String?
    let dogIds: [String]
    let walkerInfo: WalkerInfo
    var currentLocation: LiveLocationUpdate?
    var routePoints: [LiveLocationUpdate]
    var stats: LiveWalkStats
    var photos: [WalkPhotoUpdate]
    var activityEvents: [WalkActivityEvent]
    let status: LiveWalkStatus
    let startTime: Int64
    let lastUpdateTime: Int64
    var homeLatitude: Double?
    var homeLongitude: Double?

    var id: String { walkId }

    var homeLocation: CLLocationCoordinate2D? {
        guard let lat = homeLatitude, let lng = homeLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}
