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
                        Text("No Notifications")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("You're all caught up!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                ForEach(viewModel.notifications) { notification in
                    NotificationRow(notification: notification)
                        .onTapGesture { viewModel.markAsRead(notification.id) }
                        .listRowBackground(notification.read ? Color.clear : Color.turquoise90.opacity(0.1))
                }
                .onDelete { offsets in
                    for index in offsets { viewModel.dismiss(viewModel.notifications[index].id) }
                }
            }
            .navigationTitle("Notifications")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Mark All Read") { viewModel.markAllRead() }
                        .font(.caption)
                }
            }
            .refreshable { viewModel.load() }
        }
    }
}

struct NotificationRow: View {
    let notification: NotificationRecord

    var body: some View {
        HStack(spacing: 12) {
            if !notification.read {
                Circle().fill(Color.turquoise60).frame(width: 8, height: 8)
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

@MainActor
class NotificationCenterViewModel: ObservableObject {
    @Published var notifications: [NotificationRecord] = []
    @Published var isLoading = false

    init() { load() }

    func load() {
        guard let uid = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }
        isLoading = true
        let db = Firestore.firestore()
        db.collection("notifications")
            .whereField("userId", isEqualTo: uid)
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    print("Notifications error: \(error.localizedDescription)")
                    return
                }
                self.notifications = (snapshot?.documents ?? []).compactMap { doc in
                    let data = doc.data()
                    return NotificationRecord(
                        id: doc.documentID,
                        type: data["type"] as? String ?? "",
                        title: data["title"] as? String ?? "",
                        body: data["body"] as? String ?? "",
                        imageUrl: data["imageUrl"] as? String,
                        data: data["data"] as? [String: String] ?? [:],
                        read: data["read"] as? Bool ?? false,
                        delivered: data["delivered"] as? Bool ?? false,
                        createdAt: data["createdAt"] as? Int64 ?? Int64(Date().timeIntervalSince1970 * 1000)
                    )
                }
            }
    }

    func markAsRead(_ id: String) {
        if let idx = notifications.firstIndex(where: { $0.id == id }) {
            notifications[idx].read = true
        }
    }

    func markAllRead() {
        for i in notifications.indices { notifications[i].read = true }
    }

    func dismiss(_ id: String) {
        notifications.removeAll { $0.id == id }
    }
}
