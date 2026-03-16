import Foundation

struct LandCoverProbabilities: Codable, Equatable {
    let water: Double
    let trees: Double
    let grass: Double
    let floodedVegetation: Double
    let crops: Double
    let shrubAndScrub: Double
    let built: Double
    let bare: Double
    let snowAndIce: Double

    init(
        water: Double = 0.0,
        trees: Double = 0.0,
        grass: Double = 0.0,
        floodedVegetation: Double = 0.0,
        crops: Double = 0.0,
        shrubAndScrub: Double = 0.0,
        built: Double = 0.0,
        bare: Double = 0.0,
        snowAndIce: Double = 0.0
    ) {
        self.water = water
        self.trees = trees
        self.grass = grass
        self.floodedVegetation = floodedVegetation
        self.crops = crops
        self.shrubAndScrub = shrubAndScrub
        self.built = built
        self.bare = bare
        self.snowAndIce = snowAndIce
    }

    var dominant: (type: String, value: Double) {
        let classes = [
            ("water", water),
            ("trees", trees),
            ("grass", grass),
            ("flooded_vegetation", floodedVegetation),
            ("crops", crops),
            ("shrub_scrub", shrubAndScrub),
            ("built", built),
            ("bare", bare),
            ("snow_ice", snowAndIce)
        ]
        return classes.max(by: { $0.1 < $1.1 }) ?? ("unknown", 0.0)
    }

    var allClasses: [(name: String, value: Double)] {
        [
            ("Water", water),
            ("Trees", trees),
            ("Grass", grass),
            ("Flooded Vegetation", floodedVegetation),
            ("Crops", crops),
            ("Shrub & Scrub", shrubAndScrub),
            ("Built", built),
            ("Bare", bare),
            ("Snow & Ice", snowAndIce)
        ]
    }
}

struct LivestockSuitability: Codable, Equatable {
    let score: Double
    let primaryType: String
    let confidence: Double

    var rating: SuitabilityRating {
        switch score {
        case 0..<30: return .poor
        case 30..<50: return .fair
        case 50..<70: return .good
        case 70...100: return .excellent
        default: return .unknown
        }
    }

    enum SuitabilityRating {
        case unknown, poor, fair, good, excellent

        var color: String {
            switch self {
            case .unknown: return "gray"
            case .poor: return "red"
            case .fair: return "orange"
            case .good: return "yellow"
            case .excellent: return "green"
            }
        }

        var description: String {
            switch self {
            case .unknown: return "Unknown"
            case .poor: return "Poor"
            case .fair: return "Fair"
            case .good: return "Good"
            case .excellent: return "Excellent"
            }
        }
    }
}

struct DynamicWorldData: Codable, Equatable {
    let fieldId: String
    let centerLat: Double
    let centerLng: Double
    let radiusMeters: Double?
    let landCover: LandCoverProbabilities
    let livestockSuitability: LivestockSuitability
    let dominantClass: String
    let fetchedAt: Date
    let expiresAt: Date

    init(
        fieldId: String,
        centerLat: Double,
        centerLng: Double,
        radiusMeters: Double? = nil,
        landCover: LandCoverProbabilities,
        livestockSuitability: LivestockSuitability,
        dominantClass: String,
        fetchedAt: Date = Date(),
        expiresAt: Date? = nil
    ) {
        self.fieldId = fieldId
        self.centerLat = centerLat
        self.centerLng = centerLng
        self.radiusMeters = radiusMeters
        self.landCover = landCover
        self.livestockSuitability = livestockSuitability
        self.dominantClass = dominantClass
        self.fetchedAt = fetchedAt
        self.expiresAt = expiresAt ?? Calendar.current.date(byAdding: .day, value: 30, to: fetchedAt)!
    }

    var isExpired: Bool {
        return Date() > expiresAt
    }

    var daysUntilExpiry: Int {
        return Calendar.current.dateComponents([.day], from: Date(), to: expiresAt).day ?? 0
    }
}

struct FieldLocation: Codable {
    let fieldId: String
    let lat: Double
    let lng: Double
    let bbox: [Double]?

    init(fieldId: String, lat: Double, lng: Double, bbox: [Double]? = nil) {
        self.fieldId = fieldId
        self.lat = lat
        self.lng = lng
        self.bbox = bbox
    }
}

struct DateRange: Codable {
    let start: String
    let end: String

    init(start: Date, end: Date) {
        let formatter = ISO8601DateFormatter()
        self.start = formatter.string(from: start)
        self.end = formatter.string(from: end)
    }

    init(start: String, end: String) {
        self.start = start
        self.end = end
    }
}

struct EnrichedField: Codable {
    let fieldId: String
    let probabilities: LandCoverProbabilities
    let dominantClass: String
    let livestockSuitability: Double
    let timestamp: Int64

    func toDynamicWorldData(
        centerLat: Double,
        centerLng: Double,
        radiusMeters: Double? = nil
    ) -> DynamicWorldData {
        let fetchedAt = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000.0)

        let suitability = LivestockSuitability(
            score: livestockSuitability,
            primaryType: dominantClass,
            confidence: probabilities.dominant.value
        )

        return DynamicWorldData(
            fieldId: fieldId,
            centerLat: centerLat,
            centerLng: centerLng,
            radiusMeters: radiusMeters,
            landCover: probabilities,
            livestockSuitability: suitability,
            dominantClass: dominantClass,
            fetchedAt: fetchedAt
        )
    }
}

struct FieldEnrichmentRequest: Codable {
    let fields: [FieldLocation]
    let dateRange: DateRange?

    init(fields: [FieldLocation], dateRange: DateRange? = nil) {
        self.fields = fields
        self.dateRange = dateRange
    }
}

struct FieldEnrichmentResponse: Codable {
    let success: Bool
    let fields: [EnrichedField]
    let count: Int
}

enum DynamicWorldError: LocalizedError {
    case invalidResponse
    case noDataReturned
    case enrichmentFailed(String)
    case cacheError(String)
    case expiredData

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from enrichment service"
        case .noDataReturned:
            return "No enrichment data returned"
        case .enrichmentFailed(let message):
            return "Enrichment failed: \(message)"
        case .cacheError(let message):
            return "Cache error: \(message)"
        case .expiredData:
            return "Cached data has expired"
        }
    }
}
