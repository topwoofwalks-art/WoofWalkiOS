import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

class DogRepository: ObservableObject {
    private let db = Firestore.firestore()
    private let auth = Auth.auth()

    @Published var dogs: [UnifiedDog] = []

    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
    }

    // MARK: - Real-time listener for current user's dogs

    func observeDogs() -> AnyPublisher<[UnifiedDog], Error> {
        guard let userId = auth.currentUser?.uid else {
            return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
        }

        let publisher = PassthroughSubject<[UnifiedDog], Error>()

        listener?.remove()
        listener = db.collection("dogs")
            .whereField("primaryOwnerId", isEqualTo: userId)
            .whereField("isArchived", isEqualTo: false)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    publisher.send(completion: .failure(error))
                    return
                }

                let dogs = snapshot?.documents.compactMap { doc -> UnifiedDog? in
                    try? doc.data(as: UnifiedDog.self)
                } ?? []

                publisher.send(dogs)
            }

        return publisher.eraseToAnyPublisher()
    }

    // MARK: - Fetch dogs for a specific user (e.g. public profile)

    func fetchDogs(forUserId userId: String) async throws -> [UnifiedDog] {
        let snapshot = try await db.collection("dogs")
            .whereField("primaryOwnerId", isEqualTo: userId)
            .whereField("isArchived", isEqualTo: false)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: UnifiedDog.self)
        }
    }

    // MARK: - Fetch dogs for current user

    func fetchMyDogs() async throws -> [UnifiedDog] {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(domain: "DogRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        return try await fetchDogs(forUserId: userId)
    }

    // MARK: - Fetch a single dog by id

    /// Fetch a single dog document by id. Returns nil if the doc doesn't
    /// exist, is archived, or can't be decoded. Used by walk-history /
    /// booking flows to resolve dogIds → dog name + photo.
    func getDog(id: String) async throws -> UnifiedDog? {
        let doc = try await db.collection("dogs").document(id).getDocument()
        guard doc.exists else { return nil }
        return try? doc.data(as: UnifiedDog.self)
    }

    /// Batched fetch — resolves a list of dogIds to UnifiedDogs.
    /// Best-effort: missing / undecodable ids are silently dropped so a
    /// single bad reference doesn't poison the whole list.
    func getDogs(ids: [String]) async throws -> [UnifiedDog] {
        guard !ids.isEmpty else { return [] }
        // Firestore caps `in` queries at 30 ids; chunk to stay safe.
        let chunks = stride(from: 0, to: ids.count, by: 30).map {
            Array(ids[$0 ..< min($0 + 30, ids.count)])
        }
        var result: [UnifiedDog] = []
        for chunk in chunks {
            let snapshot = try await db.collection("dogs")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()
            let dogs = snapshot.documents.compactMap { try? $0.data(as: UnifiedDog.self) }
            result.append(contentsOf: dogs)
        }
        return result
    }

    // MARK: - Add a dog to the dogs collection

    func addDog(_ dog: UnifiedDog) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(domain: "DogRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        var dogToSave = dog
        dogToSave.primaryOwnerId = userId
        dogToSave.isArchived = false
        dogToSave.createdAt = Int64(Date().timeIntervalSince1970 * 1000)
        dogToSave.updatedAt = Int64(Date().timeIntervalSince1970 * 1000)

        let docId = dog.id ?? UUID().uuidString
        try db.collection("dogs").document(docId).setData(from: dogToSave)
    }

    // MARK: - Update an existing dog

    func updateDog(dogId: String, dog: UnifiedDog) async throws {
        guard auth.currentUser?.uid != nil else {
            throw NSError(domain: "DogRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        var dogToSave = dog
        dogToSave.updatedAt = Int64(Date().timeIntervalSince1970 * 1000)

        try db.collection("dogs").document(dogId).setData(from: dogToSave, merge: true)
    }

    // MARK: - Remove (archive) a dog

    func removeDog(dogId: String) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(domain: "DogRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        try await db.collection("dogs").document(dogId).updateData([
            "isArchived": true,
            "updatedAt": Int64(Date().timeIntervalSince1970 * 1000)
        ])

        // Storage cascade — delete the primary photo and every gallery
        // object. Best-effort; logged but non-fatal so archival completes
        // even if a single Storage object fails to remove.
        let primary = "dogProfiles/\(userId)/\(dogId).jpg"
        let galleryRoot = "dogProfiles/\(userId)/\(dogId)"
        do {
            try await FirebaseService.shared.deleteFile(path: primary)
        } catch {
            print("removeDog: primary photo cleanup failed — \(error.localizedDescription)")
        }
        do {
            try await FirebaseService.shared.deleteFolder(path: galleryRoot)
        } catch {
            print("removeDog: gallery cleanup failed — \(error.localizedDescription)")
        }
    }

    /// Hard-delete a dog plus all its photos. Prefer `removeDog` (archive)
    /// for user-facing flows; this is for administrative cleanup.
    func hardDeleteDog(dogId: String) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(domain: "DogRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        try await db.collection("dogs").document(dogId).delete()

        let galleryRoot = "dogProfiles/\(userId)/\(dogId)"
        try? await FirebaseService.shared.deleteFile(path: "\(galleryRoot).jpg")
        try? await FirebaseService.shared.deleteFolder(path: galleryRoot)
    }
}
