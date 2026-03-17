import Foundation
import CoreLocation
import FirebaseFirestore

enum PoiType: String, CaseIterable, Codable {
    case bin = "BIN"
    case hazard = "HAZARD"
    case water = "WATER"
    case dogPark = "DOG_PARK"
    case park = "PARK"
    case church = "CHURCH"
    case landscape = "LANDSCAPE"
    case accessNote = "ACCESS_NOTE"
    case livestock = "LIVESTOCK"
    case wildlife = "WILDLIFE"
    case amenity = "AMENITY"

    var displayName: String {
        switch self {
        case .bin: return "Waste Bin"
        case .hazard: return "Hazard"
        case .water: return "Water Source"
        case .dogPark: return "Dog Park"
        case .park: return "Park"
        case .church: return "Church"
        case .landscape: return "Landscape"
        case .accessNote: return "Access Note"
        case .livestock: return "Livestock"
        case .wildlife: return "Wildlife"
        case .amenity: return "Amenity"
        }
    }

    var iconName: String {
        switch self {
        case .bin: return "trash"
        case .hazard: return "exclamationmark.triangle"
        case .water: return "drop.fill"
        case .dogPark: return "pawprint.fill"
        case .park: return "leaf.fill"
        case .church: return "building.columns"
        case .landscape: return "mountain.2.fill"
        case .accessNote: return "info.circle"
        case .livestock: return "hare.fill"
        case .wildlife: return "hare"
        case .amenity: return "storefront"
        }
    }

    static func from(string: String) -> PoiType? {
        return PoiType(rawValue: string)
    }
}

enum PoiStatus: String, Codable {
    case active = "ACTIVE"
    case hidden = "HIDDEN"
    case expired = "EXPIRED"
    case removed = "REMOVED"
}

enum AlertSeverity: String, Codable {
    case low = "LOW"
    case medium = "MEDIUM"
    case high = "HIGH"
    case critical = "CRITICAL"
}

struct AccessInfo: Codable {
    var isPublic: Bool = true
    var notes: String = ""

    enum CodingKeys: String, CodingKey {
        case isPublic = "public"
        case notes
    }
}

// Typealias so code using POI (uppercase) still compiles against Poi (lowercase) from Models/Poi.swift
typealias POI = Poi

extension Poi {
    typealias POIType = PoiType

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    var poiType: PoiType {
        PoiType.from(string: type) ?? .bin
    }

    var poiStatus: PoiStatus {
        PoiStatus(rawValue: status) ?? .active
    }

    var displayLocation: String {
        if !formattedAddress.isEmpty {
            return formattedAddress
        }
        if !streetAddress.isEmpty {
            return streetAddress
        }
        return String(format: "%.6f, %.6f", lat, lng)
    }
}

struct PoiComment: Identifiable, Codable {
    var id: String = ""
    var poiId: String = ""
    var authorId: String = ""
    var authorName: String = ""
    var text: String = ""
    var createdAt: Timestamp?
    var voteUp: Int = 0
}

struct CachedPoi: Codable {
    var osmId: String
    var name: String
    var type: String
    var latitude: Double
    var longitude: Double
    var tags: String
    var cachedAt: Date
    var regionLat: Double
    var regionLng: Double
    var radiusKm: Double

    func toDomainPoi() -> Poi {
        let tagPairs = tags.split(separator: ";")
            .compactMap { pair -> (String, String)? in
                let parts = pair.split(separator: "=", maxSplits: 1)
                guard parts.count == 2 else { return nil }
                return (String(parts[0]), String(parts[1]))
            }
        let tagDict = Dictionary(uniqueKeysWithValues: tagPairs)

        let displayTitle = !name.isEmpty ? name : (tagDict["amenity"] ?? tagDict["leisure"] ?? type)
        let description = tagPairs.map { "\($0): \($1)" }.joined(separator: "\n")

        return Poi(
            type: type,
            title: displayTitle,
            desc: description,
            lat: latitude,
            lng: longitude,
            photoUrls: [],
            createdBy: "overpass",
            createdAt: Timestamp(date: cachedAt),
            updatedAt: Timestamp(date: cachedAt),
            status: PoiStatus.active.rawValue,
            voteUp: 0,
            voteDown: 0,
            regionCode: "GB",
            streetAddress: "",
            locality: "",
            administrativeArea: "",
            formattedAddress: ""
        )
    }
}
