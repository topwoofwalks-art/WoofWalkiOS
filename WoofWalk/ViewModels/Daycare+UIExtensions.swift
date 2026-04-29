import SwiftUI
import Foundation

// UI-helper extensions for the canonical daycare model types defined in
// `Models/DaycareModels.swift`. Mirrors what the screen+VM expect: `.label`,
// `.icon`, `.color`, `.emoji`.

extension DaycareUpdateType {
    var label: String { displayName }
    var icon: String { iconName }

    var color: Color {
        switch self {
        case .feedBreakfast, .feedLunch: return Color(red: 1.0, green: 0.6, blue: 0.0)
        case .feedSnack: return Color(red: 1.0, green: 0.72, blue: 0.3)
        case .water: return Color(red: 0.13, green: 0.59, blue: 0.95)
        case .napStart: return Color(red: 0.49, green: 0.34, blue: 0.76)
        case .napEnd: return Color(red: 1.0, green: 0.79, blue: 0.16)
        case .playSoloIndoor: return Color(red: 0.3, green: 0.69, blue: 0.31)
        case .playSoloOutdoor: return Color(red: 0.4, green: 0.73, blue: 0.42)
        case .playGroupIndoor: return Color(red: 0.15, green: 0.65, blue: 0.6)
        case .playGroupOutdoor: return Color(red: 0.18, green: 0.49, blue: 0.2)
        case .bathroomPee: return Color(red: 0.26, green: 0.65, blue: 0.96)
        case .bathroomPoo: return Color(red: 0.55, green: 0.43, blue: 0.39)
        case .socialisation: return Color(red: 0.93, green: 0.25, blue: 0.48)
        case .temperament: return Color(red: 0.36, green: 0.42, blue: 0.75)
        case .photo: return Color(red: 0.0, green: 0.54, blue: 0.48)
        case .note: return Color(red: 0.47, green: 0.56, blue: 0.61)
        case .incident: return Color(red: 0.96, green: 0.26, blue: 0.21)
        }
    }

    var isFeedType: Bool {
        self == .feedBreakfast || self == .feedLunch || self == .feedSnack
    }

    var isPlayType: Bool {
        self == .playSoloIndoor || self == .playSoloOutdoor || self == .playGroupIndoor || self == .playGroupOutdoor
    }

    var isBathroomType: Bool {
        self == .bathroomPee || self == .bathroomPoo
    }
}

extension DogTemperament {
    var label: String { displayName }
}

extension DaycareIncidentType {
    var label: String { displayName }
}

extension DaycareIncidentSeverity {
    var label: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}
