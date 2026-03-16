import Foundation

enum LivestockSpecies: String, Codable, CaseIterable {
    case cattle = "CATTLE"
    case sheep = "SHEEP"
    case horse = "HORSE"
    case deer = "DEER"
    case other = "OTHER"

    var displayName: String {
        switch self {
        case .cattle: return "Cattle"
        case .sheep: return "Sheep"
        case .horse: return "Horse"
        case .deer: return "Deer"
        case .other: return "Other"
        }
    }
}

enum ConfidenceLevel: String, Codable {
    case unknown = "UNKNOWN"
    case low = "LOW"
    case medium = "MEDIUM"
    case high = "HIGH"
    case noLivestock = "NO_LIVESTOCK"

    var displayName: String {
        switch self {
        case .unknown: return "Unknown"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .noLivestock: return "No Livestock"
        }
    }
}
