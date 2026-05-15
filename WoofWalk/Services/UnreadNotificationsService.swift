import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class UnreadNotificationsService: ObservableObject {
    static let shared = UnreadNotificationsService()

    @Published private(set) var unreadCount: Int = 0

    private var listener: ListenerRegistration?
    private var authHandle: AuthStateDidChangeListenerHandle?

    private init() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                self.attach(uid: user?.uid)
            }
        }
        attach(uid: Auth.auth().currentUser?.uid)
    }

    deinit {
        listener?.remove()
        if let authHandle {
            Auth.auth().removeStateDidChangeListener(authHandle)
        }
    }

    private func attach(uid: String?) {
        listener?.remove()
        listener = nil
        guard let uid else {
            unreadCount = 0
            return
        }
        listener = Firestore.firestore()
            .collection("notifications")
            .whereField("userId", isEqualTo: uid)
            .whereField("read", isEqualTo: false)
            .limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    print("[UnreadNotifications] listener error: \(error.localizedDescription)")
                    return
                }
                self.unreadCount = snapshot?.documents.count ?? 0
            }
    }
}
