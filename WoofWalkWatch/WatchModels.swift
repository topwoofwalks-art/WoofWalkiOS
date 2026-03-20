import Foundation

struct WatchMessage: Identifiable {
    let id: String
    let senderName: String
    let senderId: String
    let previewText: String
    let fullText: String
    let timestamp: Date
    let isRead: Bool

    init?(from dict: [String: Any]) {
        guard let id = dict["id"] as? String,
              let senderName = dict["sender_name"] as? String,
              let senderId = dict["sender_id"] as? String,
              let preview = dict["preview"] as? String else { return nil }

        self.id = id
        self.senderName = senderName
        self.senderId = senderId
        self.previewText = preview
        self.fullText = dict["full_text"] as? String ?? preview
        self.timestamp = Date(timeIntervalSince1970: dict["timestamp"] as? Double ?? 0)
        self.isRead = dict["is_read"] as? Bool ?? false
    }

    var timeAgo: String {
        let minutes = Int(Date().timeIntervalSince(timestamp) / 60)
        switch minutes {
        case ..<1: return "now"
        case 1..<60: return "\(minutes)m"
        case 60..<1440: return "\(minutes / 60)h"
        case 1440..<10080: return "\(minutes / 1440)d"
        default: return "\(minutes / 10080)w"
        }
    }
}

struct WatchRoute {
    let name: String
    let waypoints: [WatchWaypoint]
    let totalDistanceKm: Double

    init?(from dict: [String: Any]) {
        guard let name = dict["name"] as? String,
              let lats = dict["waypoint_lats"] as? [Double],
              let lngs = dict["waypoint_lngs"] as? [Double],
              let names = dict["waypoint_names"] as? [String] else { return nil }

        self.name = name
        self.totalDistanceKm = dict["total_distance_km"] as? Double ?? 0

        let types = dict["waypoint_types"] as? [String] ?? Array(repeating: "waypoint", count: lats.count)
        self.waypoints = zip(lats.indices, zip(lats, lngs)).map { (i, coords) in
            WatchWaypoint(
                lat: coords.0,
                lng: coords.1,
                name: names[safe: i] ?? "Waypoint",
                type: types[safe: i] ?? "waypoint"
            )
        }
    }
}

struct WatchWaypoint {
    let lat: Double
    let lng: Double
    let name: String
    let type: String  // start, stile, turn, crossing, kissing_gate, footbridge, poi, end
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
