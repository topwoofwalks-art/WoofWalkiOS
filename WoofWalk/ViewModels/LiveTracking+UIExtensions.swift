import SwiftUI
import Foundation

// UI helper extensions for the canonical live-tracking model types
// declared in `Models/WalkActivityEvent.swift`. Keeping these as
// extensions lets the wire-format types stay UI-agnostic.

extension LiveWalkStatus {
    var label: String {
        switch self {
        case .connecting: return "Connecting..."
        case .active: return "Walk in Progress"
        case .paused: return "Paused"
        case .ended: return "Walk Ended"
        case .error: return "Connection Error"
        }
    }

    var color: Color {
        switch self {
        case .connecting: return Color(hex: 0xFFA000)
        case .active: return Color(hex: 0x4CAF50)
        case .paused: return Color(hex: 0xFFA000)
        case .ended: return Color(hex: 0x9E9E9E)
        case .error: return Color(hex: 0xF44336)
        }
    }
}

extension ConnectionStatus {
    var color: Color {
        switch self {
        case .connected: return Color(hex: 0x4CAF50)
        case .delayed: return Color(hex: 0xFFA000)
        case .lost: return Color(hex: 0xF44336)
        }
    }

    var icon: String {
        switch self {
        case .connected: return "cellularbars"
        case .delayed: return "exclamationmark.triangle.fill"
        case .lost: return "xmark.circle.fill"
        }
    }
}

extension WalkPhotoUpdate {
    /// Wall-clock date derived from the wire timestamp (ms since epoch).
    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000.0)
    }
}

extension ETACalculation {
    /// Wall-clock date derived from the wire timestamp (ms since epoch).
    var estimatedReturnDate: Date {
        Date(timeIntervalSince1970: TimeInterval(estimatedReturnTime) / 1000.0)
    }
}

extension WalkActivityEvent {
    /// SF Symbol icon name for the event type.
    var icon: String {
        eventType.iconName
    }

    /// Display label derived from the event type.
    var label: String {
        switch type.uppercased() {
        case "PEE": return "Pee break"
        case "POO": return "Poo break"
        case "WATER": return "Had water"
        case "FEED": return "Fed"
        case "PHOTO": return "Photo taken"
        case "NOTE": return "Note"
        case "CHECK_IN": return "Checked in"
        case "PLAY": return "Play time"
        case "INCIDENT": return "Incident"
        default: return type
        }
    }

    /// Tint colour for the event tile / chip.
    var tintColor: Color {
        switch type.uppercased() {
        case "PEE": return Color(hex: 0xFFA000)
        case "POO": return Color(hex: 0x795548)
        case "WATER": return Color(hex: 0x2196F3)
        case "FEED": return Color(hex: 0xFF7043)
        case "PHOTO": return Color(hex: 0x7C4DFF)
        case "NOTE": return Color(hex: 0x607D8B)
        case "CHECK_IN": return Color(hex: 0x4CAF50)
        case "PLAY": return Color(hex: 0x4CAF50)
        case "INCIDENT": return Color(hex: 0xF44336)
        default: return Color(hex: 0x9E9E9E)
        }
    }
}
