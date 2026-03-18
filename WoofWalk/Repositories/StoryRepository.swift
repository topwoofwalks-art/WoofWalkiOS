import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Combine

class StoryRepository: ObservableObject {
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private let storage = Storage.storage()

    private var listener: ListenerRegistration?

    /// Fetch stories from the last 24 hours, grouped by user, as a real-time stream.
    func getStories() -> AnyPublisher<[StoryGroup], Never> {
        let subject = CurrentValueSubject<[StoryGroup], Never>([])

        listener?.remove()
        let now = Timestamp(date: Date())

        listener = db.collection("stories")
            .whereField("expiresAt", isGreaterThan: now)
            .order(by: "expiresAt", descending: false)
            .order(by: "createdAt", descending: true)
            .limit(to: 200)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error {
                    print("[Stories] Snapshot error: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    subject.send([])
                    return
                }

                let currentUserId = self?.auth.currentUser?.uid ?? ""
                let stories = documents.compactMap { doc -> Story? in
                    var story = try? doc.data(as: Story.self)
                    story?.id = doc.documentID
                    return story
                }

                // Group by userId
                let grouped = Dictionary(grouping: stories, by: { $0.userId })
                var groups = grouped.map { (userId, userStories) -> StoryGroup in
                    let first = userStories[0]
                    let sorted = userStories.sorted {
                        ($0.createdAt?.dateValue() ?? .distantPast) < ($1.createdAt?.dateValue() ?? .distantPast)
                    }
                    let hasUnviewed = sorted.contains { !$0.viewedBy.contains(currentUserId) }
                    let latestTimestamp = sorted.compactMap { $0.createdAt?.dateValue().timeIntervalSince1970 }.max() ?? 0

                    return StoryGroup(
                        userId: userId,
                        userName: first.userName,
                        userAvatar: first.userAvatar,
                        stories: sorted,
                        hasUnviewed: hasUnviewed,
                        latestTimestamp: Int64(latestTimestamp * 1000)
                    )
                }

                // Sort: unseen first, then by recency
                groups.sort {
                    if $0.hasUnviewed != $1.hasUnviewed {
                        return $0.hasUnviewed && !$1.hasUnviewed
                    }
                    return $0.latestTimestamp > $1.latestTimestamp
                }

                // Filter out current user's own stories from the row (they use "Your Story")
                let filtered = groups.filter { $0.userId != currentUserId }
                subject.send(filtered)
            }

        return subject.eraseToAnyPublisher()
    }

    /// Create a story: upload image to Storage, save doc to Firestore.
    func createStory(imageData: Data, caption: String) async throws -> String {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(domain: "StoryRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        let userName = auth.currentUser?.displayName ?? "Anonymous"
        let userAvatar = auth.currentUser?.photoURL?.absoluteString

        // Upload image
        let fileName = "stories/\(userId)/\(UUID().uuidString).jpg"
        let storageRef = storage.reference().child(fileName)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()

        // Create Firestore doc
        let expiresAt = Timestamp(date: Date().addingTimeInterval(24 * 60 * 60))

        let data: [String: Any] = [
            "userId": userId,
            "userName": userName,
            "userAvatar": userAvatar as Any,
            "mediaUrl": downloadURL.absoluteString,
            "mediaType": "PHOTO",
            "caption": caption,
            "createdAt": FieldValue.serverTimestamp(),
            "expiresAt": expiresAt,
            "viewedBy": [String]()
        ]

        let docRef = try await db.collection("stories").addDocument(data: data)
        print("[Stories] Created story: \(docRef.documentID)")
        return docRef.documentID
    }

    /// Mark a story as seen by the current user.
    func markStorySeen(storyId: String) async {
        guard let userId = auth.currentUser?.uid else { return }
        do {
            try await db.collection("stories").document(storyId)
                .updateData(["viewedBy": FieldValue.arrayUnion([userId])])
        } catch {
            print("[Stories] Failed to mark seen: \(error.localizedDescription)")
        }
    }

    /// Check if current user has any active stories.
    func currentUserHasStories() async -> Bool {
        guard let userId = auth.currentUser?.uid else { return false }
        let now = Timestamp(date: Date())
        do {
            let snapshot = try await db.collection("stories")
                .whereField("userId", isEqualTo: userId)
                .whereField("expiresAt", isGreaterThan: now)
                .limit(to: 1)
                .getDocuments()
            return !snapshot.documents.isEmpty
        } catch {
            return false
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    deinit {
        listener?.remove()
    }
}
