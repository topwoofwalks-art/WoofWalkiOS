import Foundation

struct NotificationRecord: Identifiable, Codable {
    var id: String
    var type: String
    var title: String
    var body: String
    var imageUrl: String?
    var data: [String: String]
    /// Denormalised sender display name. Server (`functions/src/notifications/notify.ts`)
    /// stamps this top-level on the notification doc whenever the caller passes
    /// `metadata.fromUserId` — lets the row render the actor's avatar without an
    /// extra Firestore read per row. Mirrors Android's `Notification.fromUserDisplayName`.
    var fromUserDisplayName: String?
    /// Denormalised sender photo URL — same provenance as `fromUserDisplayName`.
    /// Server reads `users/{fromUserId}.photoURL` once at notification creation
    /// and stores it here for the row to render directly.
    var fromUserPhotoUrl: String?
    var read: Bool
    var delivered: Bool
    var deliveredAt: Int64?
    var clicked: Bool
    var clickedAt: Int64?
    var dismissed: Bool
    var createdAt: Int64

    init(
        id: String = UUID().uuidString,
        type: String = "",
        title: String = "",
        body: String = "",
        imageUrl: String? = nil,
        data: [String: String] = [:],
        fromUserDisplayName: String? = nil,
        fromUserPhotoUrl: String? = nil,
        read: Bool = false,
        delivered: Bool = false,
        deliveredAt: Int64? = nil,
        clicked: Bool = false,
        clickedAt: Int64? = nil,
        dismissed: Bool = false,
        createdAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.imageUrl = imageUrl
        self.data = data
        self.fromUserDisplayName = fromUserDisplayName
        self.fromUserPhotoUrl = fromUserPhotoUrl
        self.read = read
        self.delivered = delivered
        self.deliveredAt = deliveredAt
        self.clicked = clicked
        self.clickedAt = clickedAt
        self.dismissed = dismissed
        self.createdAt = createdAt
    }

    var createdDate: Date {
        Date(timeIntervalSince1970: Double(createdAt) / 1000.0)
    }

    /// Sender uid — when this notification was triggered by another user's
    /// action (friend request, post like, comment, etc.) the server stamps
    /// `metadata.fromUserId` into the `data` map. Used by the tap-router to
    /// route FRIEND_REQUEST taps to the actor's public profile.
    var fromUserId: String? {
        let raw = data["fromUserId"] ?? data["from_user_id"]
        guard let raw, !raw.isEmpty else { return nil }
        return raw
    }
}

struct NotificationPreferences: Codable {
    var bookingsEnabled: Bool
    var messagesEnabled: Bool
    var walkUpdatesEnabled: Bool
    var paymentsEnabled: Bool
    var alertsEnabled: Bool
    var marketingEnabled: Bool
    var emailEnabled: Bool
    var pushEnabled: Bool
    var quietHoursEnabled: Bool
    var quietHoursStart: String
    var quietHoursEnd: String
    var soundEnabled: Bool
    var vibrationEnabled: Bool

    init(bookingsEnabled: Bool = true, messagesEnabled: Bool = true, walkUpdatesEnabled: Bool = true, paymentsEnabled: Bool = true, alertsEnabled: Bool = true, marketingEnabled: Bool = false, emailEnabled: Bool = true, pushEnabled: Bool = true, quietHoursEnabled: Bool = false, quietHoursStart: String = "22:00", quietHoursEnd: String = "08:00", soundEnabled: Bool = true, vibrationEnabled: Bool = true) {
        self.bookingsEnabled = bookingsEnabled; self.messagesEnabled = messagesEnabled; self.walkUpdatesEnabled = walkUpdatesEnabled; self.paymentsEnabled = paymentsEnabled; self.alertsEnabled = alertsEnabled; self.marketingEnabled = marketingEnabled; self.emailEnabled = emailEnabled; self.pushEnabled = pushEnabled; self.quietHoursEnabled = quietHoursEnabled; self.quietHoursStart = quietHoursStart; self.quietHoursEnd = quietHoursEnd; self.soundEnabled = soundEnabled; self.vibrationEnabled = vibrationEnabled
    }
}
