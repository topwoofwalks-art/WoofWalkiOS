import SwiftUI

struct WalkColors {
    static func colorForSpeed(_ speedKmh: Double) -> Color {
        switch speedKmh {
        case ..<2.0: return .blue       // Very slow / stopped
        case 2.0..<4.0: return .green   // Walking
        case 4.0..<6.0: return .yellow  // Brisk walking
        case 6.0..<8.0: return .orange  // Jogging
        default: return .red            // Running
        }
    }

    static func colorForPace(_ paceMinPerKm: Double) -> Color {
        switch paceMinPerKm {
        case ..<6.0: return .red        // Running
        case 6.0..<10.0: return .orange // Jogging
        case 10.0..<15.0: return .yellow // Brisk
        case 15.0..<20.0: return .green  // Walking
        default: return .blue            // Slow
        }
    }
}
