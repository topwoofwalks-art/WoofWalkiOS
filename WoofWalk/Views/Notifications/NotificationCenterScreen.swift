import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct NotificationCenterScreen: View {
    @StateObject private var viewModel = NotificationCenterViewModel()

    var body: some View {
        NavigationStack {
            List {
                if viewModel.notifications.isEmpty && !viewModel.isLoading {
                    VStack(spacing: 12) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(String(localized: "notifications_empty_title"))
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(String(localized: "notifications_empty_subtitle"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                ForEach(viewModel.notifications) { notification in
                    NotificationRow(notification: notification)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            handleTap(notification)
                        }
                        .listRowBackground(notification.read ? Color.clear : Color.turquoise90.opacity(0.1))
                }
                .onDelete { offsets in
                    for index in offsets { viewModel.dismiss(viewModel.notifications[index].id) }
                }
            }
            .navigationTitle(String(localized: "notifications_title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "notifications_mark_all_read")) { viewModel.markAllRead() }
                        .font(.caption)
                }
            }
            .refreshable { viewModel.load() }
        }
    }

    /// Tap handler — mark-as-read + route per Android's
    /// `handleNotificationAction` in `NotificationCenterScreen.kt`. We
    /// reuse the existing `.deepLinkRouteRequested` Notification.Name
    /// hop already wired in `NotificationService` so the root navigator
    /// pushes onto the active stack regardless of which tab the user
    /// is on when they tap.
    private func handleTap(_ notification: NotificationRecord) {
        viewModel.markAsRead(notification.id)
        guard let route = NotificationCenterScreen.route(for: notification) else { return }
        NotificationCenter.default.post(
            name: .deepLinkRouteRequested,
            object: nil,
            userInfo: ["route": route]
        )
    }

    /// Pure mapper from notification → AppRoute. Exposed `static` so
    /// it's unit-testable without standing up Firestore. Mirrors the
    /// Android `handleNotificationAction` switch in NotificationCenterScreen.kt.
    static func route(for notification: NotificationRecord) -> AppRoute? {
        switch notification.type {
        case "FRIEND_REQUEST", "FRIEND_ACCEPTED":
            if let uid = notification.fromUserId { return .publicProfile(userId: uid) }
            return nil
        case "POST_LIKE", "POST_COMMENT":
            if let postId = notification.data["postId"], !postId.isEmpty {
                return .postDetail(postId: postId)
            }
            return nil
        case "LOST_DOG_ALERT":
            let alertId = notification.data["alertId"]
                ?? notification.data["lostDogId"]
            if let id = alertId, !id.isEmpty { return .lostDog(alertId: id) }
            return nil
        case "BOOKING_UPDATE", "BOOKING_CONFIRMED", "BOOKING_CANCELLED",
             "BOOKING_REQUEST", "BOOKING_REMINDER":
            if let bookingId = notification.data["bookingId"], !bookingId.isEmpty {
                return .clientBookingDetail(bookingId: bookingId)
            }
            return nil
        case "CHAT_MESSAGE", "MESSAGE_NEW", "MESSAGE_REPLY":
            if let chatId = notification.data["chatId"]
                ?? notification.data["threadId"], !chatId.isEmpty {
                return .chatDetail(chatId: chatId)
            }
            return nil
        case "WALK_UPDATE", "WALK_STARTED", "WALK_COMPLETED":
            if let walkId = notification.data["walkId"], !walkId.isEmpty {
                return .walkDetail(walkId: walkId)
            }
            return nil
        case "PAYMENT":
            if let bookingId = notification.data["bookingId"], !bookingId.isEmpty {
                return .payment(bookingId: bookingId)
            }
            return nil
        default:
            return nil
        }
    }
}

struct NotificationRow: View {
    let notification: NotificationRecord

    private var hasActor: Bool {
        let nameOk = (notification.fromUserDisplayName ?? "").isEmpty == false
        let photoOk = (notification.fromUserPhotoUrl ?? "").isEmpty == false
        return nameOk || photoOk
    }

    var body: some View {
        HStack(spacing: 12) {
            // Unread dot — leading edge, mirrors prior layout.
            if !notification.read {
                Circle().fill(Color.turquoise60).frame(width: 8, height: 8)
            }

            // Actor avatar (when the server denormed `fromUserDisplayName` /
            // `fromUserPhotoUrl`) — friend likes, friend requests, comments
            // etc. Pure system notifications (booking reminders, payment
            // events) fall back to the typed icon.
            if hasActor {
                UserAvatarView(
                    photoUrl: notification.fromUserPhotoUrl,
                    displayName: notification.fromUserDisplayName ?? "",
                    size: 40
                )
            } else {
                NotificationTypeIcon(type: notification.type)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.subheadline.bold())
                Text(notification.body)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                Text(FormatUtils.formatRelativeTime(notification.createdDate))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

/// Type-keyed leading icon for notification rows. Mirrors Android
/// `NotificationIcon(type:)` in NotificationCenterScreen.kt — same
/// type → glyph mapping so the cross-platform notification feed
/// reads identically.
private struct NotificationTypeIcon: View {
    let type: String

    private var symbol: String {
        switch type {
        case "FRIEND_REQUEST", "FRIEND_ACCEPTED": return "person.badge.plus"
        case "POST_LIKE": return "heart.fill"
        case "POST_COMMENT": return "bubble.left.fill"
        case "LOST_DOG_ALERT": return "exclamationmark.triangle.fill"
        case "BOOKING_UPDATE", "BOOKING_CONFIRMED", "BOOKING_CANCELLED",
             "BOOKING_REQUEST", "BOOKING_REMINDER":
            return "calendar"
        case "WALK_UPDATE", "WALK_STARTED", "WALK_COMPLETED":
            return "figure.walk"
        case "PAYMENT": return "creditcard"
        case "CHAT_MESSAGE", "MESSAGE_NEW", "MESSAGE_REPLY":
            return "message.fill"
        case "ACHIEVEMENT": return "trophy.fill"
        case "EVENT_INVITE", "EVENT_REMINDER", "EVENT_UPDATED":
            return "calendar.badge.clock"
        case "EVENT_CANCELLED": return "calendar.badge.exclamationmark"
        default: return "bell.fill"
        }
    }

    private var tint: Color {
        switch type {
        case "LOST_DOG_ALERT", "EVENT_CANCELLED": return .red
        case "POST_LIKE": return .pink
        case "PAYMENT": return .green
        case "WALK_UPDATE", "WALK_STARTED", "WALK_COMPLETED": return .blue
        case "FRIEND_REQUEST", "FRIEND_ACCEPTED": return .turquoise60
        default: return .secondary
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.15))
                .frame(width: 40, height: 40)
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(tint)
        }
    }
}

@MainActor
class NotificationCenterViewModel: ObservableObject {
    @Published var notifications: [NotificationRecord] = []
    @Published var isLoading = false
    @Published var unreadCount: Int = 0

    private var listener: ListenerRegistration?

    init() { load() }

    deinit {
        listener?.remove()
    }

    func load() {
        guard let uid = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }
        isLoading = true
        listener?.remove()
        let db = Firestore.firestore()
        listener = db.collection("notifications")
            .whereField("userId", isEqualTo: uid)
            .order(by: "createdAt", descending: true)
            .limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    print("Notifications error: \(error.localizedDescription)")
                    return
                }
                self.notifications = (snapshot?.documents ?? []).compactMap { doc in
                    let data = doc.data()
                    let createdRaw = data["createdAt"]
                    let createdMs: Int64
                    if let ts = createdRaw as? Timestamp {
                        createdMs = Int64(ts.dateValue().timeIntervalSince1970 * 1000)
                    } else if let n = createdRaw as? Int64 {
                        createdMs = n
                    } else if let n = createdRaw as? Double {
                        createdMs = Int64(n)
                    } else {
                        createdMs = Int64(Date().timeIntervalSince1970 * 1000)
                    }
                    // The Firestore document may carry the metadata under
                    // either `data` (legacy) or `metadata` (server-side
                    // notify.ts canonical key). Normalise to the model's
                    // `data` field so the tap-router and avatar wiring see
                    // a single shape regardless of producer.
                    let rawMeta = (data["metadata"] as? [String: Any])
                        ?? (data["data"] as? [String: Any])
                        ?? [:]
                    let metadata: [String: String] = rawMeta.reduce(into: [:]) { acc, pair in
                        acc[pair.key] = "\(pair.value)"
                    }
                    return NotificationRecord(
                        id: doc.documentID,
                        type: data["type"] as? String ?? "",
                        title: data["title"] as? String ?? "",
                        body: data["body"] as? String ?? "",
                        imageUrl: data["imageUrl"] as? String,
                        data: metadata,
                        fromUserDisplayName: data["fromUserDisplayName"] as? String,
                        fromUserPhotoUrl: data["fromUserPhotoUrl"] as? String,
                        read: data["read"] as? Bool ?? false,
                        delivered: data["delivered"] as? Bool ?? false,
                        createdAt: createdMs
                    )
                }
                self.unreadCount = self.notifications.filter { !$0.read }.count
            }
    }

    func markAsRead(_ id: String) {
        if let idx = notifications.firstIndex(where: { $0.id == id }) {
            notifications[idx].read = true
        }
        guard Auth.auth().currentUser != nil else {
            print("[NotificationCenter] markAsRead skipped — not signed in")
            return
        }
        Firestore.firestore()
            .collection("notifications")
            .document(id)
            .updateData([
                "read": true,
                "readAt": FieldValue.serverTimestamp()
            ]) { error in
                if let error {
                    print("[NotificationCenter] markAsRead failed: \(error.localizedDescription)")
                }
            }
    }

    func markAllRead() {
        let unread = notifications.filter { !$0.read }
        for i in notifications.indices { notifications[i].read = true }
        guard Auth.auth().currentUser != nil else {
            print("[NotificationCenter] markAllRead skipped — not signed in")
            return
        }
        if unread.isEmpty { return }
        let db = Firestore.firestore()
        let chunks = stride(from: 0, to: unread.count, by: 500).map {
            Array(unread[$0..<min($0 + 500, unread.count)])
        }
        for chunk in chunks {
            let batch = db.batch()
            for note in chunk {
                let ref = db.collection("notifications").document(note.id)
                batch.updateData([
                    "read": true,
                    "readAt": FieldValue.serverTimestamp()
                ], forDocument: ref)
            }
            batch.commit { error in
                if let error {
                    print("[NotificationCenter] markAllRead batch failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func dismiss(_ id: String) {
        notifications.removeAll { $0.id == id }
        guard Auth.auth().currentUser != nil else {
            print("[NotificationCenter] dismiss skipped — not signed in")
            return
        }
        Firestore.firestore()
            .collection("notifications")
            .document(id)
            .updateData([
                "read": true,
                "readAt": FieldValue.serverTimestamp()
            ]) { error in
                if let error {
                    print("[NotificationCenter] dismiss failed: \(error.localizedDescription)")
                }
            }
    }
}
