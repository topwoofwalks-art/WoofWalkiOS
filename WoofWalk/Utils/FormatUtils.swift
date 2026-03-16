import Foundation

struct FormatUtils {
    static func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return String(format: "%.0fm", meters)
        } else {
            return String(format: "%.2fkm", meters / 1000.0)
        }
    }

    static func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%dh %dm", h, m)
        } else if m > 0 {
            return String(format: "%dm %ds", m, s)
        } else {
            return String(format: "%ds", s)
        }
    }

    static func formatDurationCompact(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%d:%02d", m, s)
        }
    }

    static func formatPace(_ minPerKm: Double) -> String {
        guard minPerKm.isFinite && minPerKm > 0 else { return "--:--" }
        let minutes = Int(minPerKm)
        let seconds = Int((minPerKm - Double(minutes)) * 60)
        return String(format: "%d:%02d /km", minutes, seconds)
    }

    static func formatSpeed(_ kmh: Double) -> String {
        String(format: "%.1f km/h", kmh)
    }

    static func formatRelativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        switch interval {
        case ..<60: return "Just now"
        case 60..<3600: return "\(Int(interval / 60))m ago"
        case 3600..<86400: return "\(Int(interval / 3600))h ago"
        case 86400..<604800: return "\(Int(interval / 86400))d ago"
        default:
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }

    static func formatPoints(_ points: Int) -> String {
        if points >= 1000 {
            return String(format: "%.1fk", Double(points) / 1000.0)
        }
        return "\(points)"
    }
}
