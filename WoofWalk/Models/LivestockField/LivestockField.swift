import Foundation
import CoreLocation
import FirebaseFirestore
import MapKit

struct LivestockField: Codable, Identifiable {
    var id: String { fieldId }

    let fieldId: String
    let centroid: GeoPoint
    let bbox: [Double]
    let area_m2: Double
    let confidence: Double
    let speciesScores: [String: Double]
    let lastSeenAt: TimeInterval?
    let lastNoLivestockAt: TimeInterval?
    let votesUp: Int
    let votesDown: Int
    let signalCount: Int
    let decayedAt: TimeInterval?
    let polygonRaw: [[Double]]
    let isDangerous: Bool
    let isOsmField: Bool
    let osmLanduse: String?
    let dwGrassProbability: Double?
    let dwCropsProbability: Double?
    let dwTreesProbability: Double?
    let dwBuiltProbability: Double?
    let dwWaterProbability: Double?
    let dwLastUpdated: TimeInterval?

    init(
        fieldId: String = "",
        centroid: GeoPoint = GeoPoint(latitude: 0, longitude: 0),
        bbox: [Double] = [],
        area_m2: Double = 0,
        confidence: Double = 0,
        speciesScores: [String: Double] = [:],
        lastSeenAt: TimeInterval? = nil,
        lastNoLivestockAt: TimeInterval? = nil,
        votesUp: Int = 0,
        votesDown: Int = 0,
        signalCount: Int = 0,
        decayedAt: TimeInterval? = nil,
        polygonRaw: [[Double]] = [],
        isDangerous: Bool = false,
        isOsmField: Bool = false,
        osmLanduse: String? = nil,
        dwGrassProbability: Double? = nil,
        dwCropsProbability: Double? = nil,
        dwTreesProbability: Double? = nil,
        dwBuiltProbability: Double? = nil,
        dwWaterProbability: Double? = nil,
        dwLastUpdated: TimeInterval? = nil
    ) {
        self.fieldId = fieldId
        self.centroid = centroid
        self.bbox = bbox
        self.area_m2 = area_m2
        self.confidence = confidence
        self.speciesScores = speciesScores
        self.lastSeenAt = lastSeenAt
        self.lastNoLivestockAt = lastNoLivestockAt
        self.votesUp = votesUp
        self.votesDown = votesDown
        self.signalCount = signalCount
        self.decayedAt = decayedAt
        self.polygonRaw = polygonRaw
        self.isDangerous = isDangerous
        self.isOsmField = isOsmField
        self.osmLanduse = osmLanduse
        self.dwGrassProbability = dwGrassProbability
        self.dwCropsProbability = dwCropsProbability
        self.dwTreesProbability = dwTreesProbability
        self.dwBuiltProbability = dwBuiltProbability
        self.dwWaterProbability = dwWaterProbability
        self.dwLastUpdated = dwLastUpdated
    }

    var confidenceLevel: ConfidenceLevel {
        switch confidence {
        case 0.75...:
            return .high
        case 0.45..<0.75:
            return .medium
        case 0.2..<0.45:
            return .low
        default:
            return .unknown
        }
    }

    var dwLivestockSuitability: Double {
        let grass = dwGrassProbability ?? 0
        let crops = dwCropsProbability ?? 0
        let trees = dwTreesProbability ?? 0
        let built = dwBuiltProbability ?? 0
        let water = dwWaterProbability ?? 0

        let suitability = (grass * 0.7 + crops * 0.3) * (1.0 - built * 0.5 - water * 0.8 - trees * 0.3)
        return max(0, suitability)
    }

    var hasDynamicWorldData: Bool {
        dwGrassProbability != nil
    }

    var topSpecies: LivestockSpecies? {
        guard let maxEntry = speciesScores.max(by: { $0.value < $1.value }) else {
            return nil
        }
        return LivestockSpecies(rawValue: maxEntry.key)
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: centroid.latitude,
            longitude: centroid.longitude
        )
    }

    var polygon: [CLLocationCoordinate2D] {
        polygonRaw.compactMap { coords in
            guard coords.count >= 2 else { return nil }
            return CLLocationCoordinate2D(latitude: coords[1], longitude: coords[0])
        }
    }

    var boundingBox: MKCoordinateRegion? {
        guard bbox.count == 4 else { return nil }
        let west = bbox[0]
        let south = bbox[1]
        let east = bbox[2]
        let north = bbox[3]

        let centerLat = (north + south) / 2
        let centerLng = (east + west) / 2
        let spanLat = abs(north - south)
        let spanLng = abs(east - west)

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng),
            span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLng)
        )
    }

    var areaHectares: Double {
        area_m2 / 10000.0
    }

    var areaAcres: Double {
        area_m2 / 4046.86
    }

    func hasSpecies(_ species: LivestockSpecies) -> Bool {
        speciesScores[species.rawValue] ?? 0 > 0
    }

    func speciesScore(for species: LivestockSpecies) -> Double {
        speciesScores[species.rawValue] ?? 0
    }
}

extension LivestockField {
    var displayConfidence: String {
        String(format: "%.0f%%", confidence * 100)
    }

    var displayArea: String {
        if areaHectares >= 1 {
            return String(format: "%.1f ha", areaHectares)
        } else {
            return String(format: "%.0f m²", area_m2)
        }
    }

    var isActive: Bool {
        decayedAt == nil && confidence >= 0.2
    }

    var needsUpdate: Bool {
        guard let lastUpdated = dwLastUpdated else { return true }
        let daysSinceUpdate = (Date().timeIntervalSince1970 * 1000 - lastUpdated) / (1000 * 60 * 60 * 24)
        return daysSinceUpdate > 30
    }
}
