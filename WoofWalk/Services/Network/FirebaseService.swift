import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

class FirebaseService {
    static let shared = FirebaseService()

    let auth: Auth
    let firestore: Firestore
    let storage: Storage

    private init() {
        self.auth = Auth.auth()
        self.firestore = Firestore.firestore()
        self.storage = Storage.storage()

        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        firestore.settings = settings
    }

    var currentUser: User? {
        return auth.currentUser
    }

    var isAuthenticated: Bool {
        return currentUser != nil
    }

    func signIn(email: String, password: String) async throws -> User {
        let result = try await auth.signIn(withEmail: email, password: password)
        return result.user
    }

    func signUp(email: String, password: String) async throws -> User {
        let result = try await auth.createUser(withEmail: email, password: password)
        return result.user
    }

    func signOut() throws {
        try auth.signOut()
    }

    func resetPassword(email: String) async throws {
        try await auth.sendPasswordReset(withEmail: email)
    }

    func uploadImage(data: Data, path: String) async throws -> URL {
        let storageRef = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await storageRef.putDataAsync(data, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        return downloadURL
    }

    func downloadImage(path: String) async throws -> Data {
        let storageRef = storage.reference().child(path)
        let maxSize: Int64 = 10 * 1024 * 1024
        let data = try await storageRef.data(maxSize: maxSize)
        return data
    }

    func deleteFile(path: String) async throws {
        let storageRef = storage.reference().child(path)
        try await storageRef.delete()
    }
}

extension FirebaseService {
    func getDocument<T: Decodable>(collection: String, documentId: String) async throws -> T {
        let docRef = firestore.collection(collection).document(documentId)
        let snapshot = try await docRef.getDocument()

        guard let data = snapshot.data() else {
            throw NetworkError.noData
        }

        let jsonData = try JSONSerialization.data(withJSONObject: data)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: jsonData)
    }

    func getDocuments<T: Decodable>(collection: String) async throws -> [T] {
        let collectionRef = firestore.collection(collection)
        let snapshot = try await collectionRef.getDocuments()

        return try snapshot.documents.compactMap { document in
            let data = document.data()
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(T.self, from: jsonData)
        }
    }

    func setDocument<T: Encodable>(collection: String, documentId: String, data: T) async throws {
        let docRef = firestore.collection(collection).document(documentId)
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let jsonData = try encoder.encode(data)
        let dict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] ?? [:]
        try await docRef.setData(dict)
    }

    func updateDocument(collection: String, documentId: String, fields: [String: Any]) async throws {
        let docRef = firestore.collection(collection).document(documentId)
        try await docRef.updateData(fields)
    }

    func deleteDocument(collection: String, documentId: String) async throws {
        let docRef = firestore.collection(collection).document(documentId)
        try await docRef.delete()
    }

    func queryDocuments<T: Decodable>(
        collection: String,
        field: String,
        isEqualTo value: Any
    ) async throws -> [T] {
        let collectionRef = firestore.collection(collection)
        let query = collectionRef.whereField(field, isEqualTo: value)
        let snapshot = try await query.getDocuments()

        return try snapshot.documents.compactMap { document in
            let data = document.data()
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(T.self, from: jsonData)
        }
    }
}
