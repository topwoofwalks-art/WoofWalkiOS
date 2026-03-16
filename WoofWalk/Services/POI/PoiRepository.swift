import Foundation
import FirebaseAuth
import FirebaseFirestore
import CoreLocation
import Combine

class PoiRepository {
    static let shared = PoiRepository()

    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private let poiManager = PoiManager.shared

    private init() {}

    func createPoi(_ poi: POI) async throws -> String {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(domain: "PoiRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let geohash = Geohash.encode(latitude: poi.lat, longitude: poi.lng, precision: 9)

        let addressComponents = try await reverseGeocode(latitude: poi.lat, longitude: poi.lng)

        var newPoi = poi
        newPoi.createdBy = userId
        newPoi.geohash = geohash
        newPoi.status = PoiStatus.active.rawValue
        newPoi.streetAddress = addressComponents.streetAddress
        newPoi.locality = addressComponents.locality
        newPoi.administrativeArea = addressComponents.administrativeArea
        newPoi.formattedAddress = addressComponents.formattedAddress

        let docRef = try await db.collection("pois").addDocument(data: try Firestore.Encoder().encode(newPoi))

        print("POI created: \(docRef.documentID) at \(addressComponents.formattedAddress)")

        return docRef.documentID
    }

    func updatePoi(poiId: String, updates: [String: Any]) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(domain: "PoiRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let poiDoc = try await db.collection("pois").document(poiId).getDocument()

        guard let poiData = poiDoc.data(),
              let createdBy = poiData["createdBy"] as? String,
              createdBy == userId else {
            throw NSError(domain: "PoiRepository", code: 403, userInfo: [NSLocalizedDescriptionKey: "Not authorized to update this POI"])
        }

        try await db.collection("pois").document(poiId).updateData(updates)
        print("POI updated: \(poiId)")
    }

    func votePoi(poiId: String, upvote: Bool) async throws {
        guard auth.currentUser?.uid != nil else {
            throw NSError(domain: "PoiRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let field = upvote ? "voteUp" : "voteDown"

        try await db.collection("pois").document(poiId).updateData([
            field: FieldValue.increment(Int64(1))
        ])

        print("POI voted: \(poiId), upvote=\(upvote)")
    }

    func getPoisNearby(center: CLLocationCoordinate2D, radiusKm: Double = 5.0) -> AnyPublisher<[POI], Error> {
        let firestorePois = getFirestorePoisNearby(center: center, radiusKm: radiusKm)

        return firestorePois.map { [weak self] firestorePois in
            Task {
                do {
                    let osmPois = try await self?.poiManager.fetchPoisWithCache(
                        lat: center.latitude,
                        lng: center.longitude,
                        radiusKm: radiusKm
                    ) ?? []

                    return firestorePois + osmPois
                } catch {
                    print("Failed to fetch OSM POIs: \(error)")
                    return firestorePois
                }
            }
            return firestorePois
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    private func getFirestorePoisNearby(center: CLLocationCoordinate2D, radiusKm: Double) -> AnyPublisher<[POI], Error> {
        let subject = PassthroughSubject<[POI], Error>()

        let bounds = Geohash.queryBounds(latitude: center.latitude, longitude: center.longitude, radiusKm: radiusKm)

        var allPois: [POI] = []
        var queriesCompleted = 0

        for (startHash, endHash) in bounds {
            db.collection("pois")
                .order(by: "geohash")
                .start(at: [startHash])
                .end(at: [endHash])
                .whereField("status", isEqualTo: PoiStatus.active.rawValue)
                .limit(to: 200)
                .addSnapshotListener { snapshot, error in
                    if let error = error {
                        subject.send(completion: .failure(error))
                        return
                    }

                    let pois = snapshot?.documents.compactMap { doc -> POI? in
                        try? doc.data(as: POI.self)
                    } ?? []

                    allPois.append(contentsOf: pois)

                    queriesCompleted += 1
                    if queriesCompleted == bounds.count {
                        let filteredPois = allPois
                            .filter { poi in
                                let poiLocation = CLLocation(latitude: poi.lat, longitude: poi.lng)
                                let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
                                return poiLocation.distance(from: centerLocation) <= radiusKm * 1000
                            }
                            .uniqued(by: \.id)

                        subject.send(filteredPois)
                    }
                }
        }

        return subject.eraseToAnyPublisher()
    }

    func getPoiById(_ poiId: String) -> AnyPublisher<POI?, Error> {
        let subject = PassthroughSubject<POI?, Error>()

        db.collection("pois").document(poiId).addSnapshotListener { snapshot, error in
            if let error = error {
                subject.send(completion: .failure(error))
                return
            }

            let poi = try? snapshot?.data(as: POI.self)
            subject.send(poi)
        }

        return subject.eraseToAnyPublisher()
    }

    func addComment(poiId: String, text: String) async throws -> String {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(domain: "PoiRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let userName = auth.currentUser?.displayName ?? "Anonymous"

        let comment = PoiComment(
            poiId: poiId,
            authorId: userId,
            authorName: userName,
            text: text,
            createdAt: Timestamp(date: Date())
        )

        let docRef = try await db.collection("pois").document(poiId)
            .collection("comments")
            .addDocument(data: try Firestore.Encoder().encode(comment))

        print("Comment added: \(docRef.documentID)")
        return docRef.documentID
    }

    func getComments(poiId: String) -> AnyPublisher<[PoiComment], Error> {
        let subject = PassthroughSubject<[PoiComment], Error>()

        db.collection("pois").document(poiId)
            .collection("comments")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    subject.send(completion: .failure(error))
                    return
                }

                let comments = snapshot?.documents.compactMap { doc -> PoiComment? in
                    try? doc.data(as: PoiComment.self)
                } ?? []

                subject.send(comments)
            }

        return subject.eraseToAnyPublisher()
    }

    func reportPoi(poiId: String, reason: String) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(domain: "PoiRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let report: [String: Any] = [
            "poiId": poiId,
            "reportedBy": userId,
            "reason": reason,
            "timestamp": Timestamp(date: Date())
        ]

        try await db.collection("moderationQueue").addDocument(data: report)
        print("POI reported: \(poiId)")
    }

    func reportPoiMissing(poiId: String) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(domain: "PoiRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        try await db.collection("pois").document(poiId).updateData([
            "status": PoiStatus.removed.rawValue,
            "removedBy": userId,
            "removedAt": Timestamp(date: Date())
        ])

        print("POI marked as not here: \(poiId) by user \(userId)")
    }

    private func reverseGeocode(latitude: Double, longitude: Double) async throws -> AddressComponents {
        return AddressComponents()
    }
}

struct AddressComponents {
    var streetAddress: String = ""
    var locality: String = ""
    var administrativeArea: String = ""
    var formattedAddress: String = ""
}

extension Array {
    func uniqued<T: Hashable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        var seen = Set<T>()
        return filter { element in
            let key = element[keyPath: keyPath]
            return seen.insert(key).inserted
        }
    }
}
