import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

/// Repository for booking operations against the "bookings" Firestore collection.
/// Mirrors the Android BookingRepository's Firestore queries and field names.
class BookingRepository: ObservableObject {
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private var listeners: [ListenerRegistration] = []

    private static let collectionBookings = "bookings"

    private var currentUserId: String? {
        auth.currentUser?.uid
    }

    // MARK: - Real-Time Listeners (Combine)

    /// Listen to bookings for a specific client (real-time).
    func getClientBookings(clientId: String) -> AnyPublisher<[Booking], Error> {
        let subject = PassthroughSubject<[Booking], Error>()

        let listener = db.collection(Self.collectionBookings)
            .whereField("clientId", isEqualTo: clientId)
            .order(by: "startTime", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("[BookingRepository] Error listening to client bookings: \(error.localizedDescription)")
                    subject.send([])
                    return
                }

                let bookings = self.mapSnapshotToBookings(snapshot)
                subject.send(bookings)
            }

        listeners.append(listener)

        return subject
            .handleEvents(receiveCancel: { [weak self] in
                listener.remove()
                self?.listeners.removeAll { $0 === listener }
            })
            .eraseToAnyPublisher()
    }

    /// Listen to bookings for a business/professional (real-time).
    func getBusinessBookings(businessId: String) -> AnyPublisher<[Booking], Error> {
        let subject = PassthroughSubject<[Booking], Error>()

        let listener = db.collection(Self.collectionBookings)
            .whereField("assignedTo", isEqualTo: businessId)
            .order(by: "startTime", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("[BookingRepository] Error listening to business bookings: \(error.localizedDescription)")
                    subject.send([])
                    return
                }

                let bookings = self.mapSnapshotToBookings(snapshot)
                subject.send(bookings)
            }

        listeners.append(listener)

        return subject
            .handleEvents(receiveCancel: { [weak self] in
                listener.remove()
                self?.listeners.removeAll { $0 === listener }
            })
            .eraseToAnyPublisher()
    }

    /// Listen to a single booking by ID (real-time).
    func getBookingById(_ bookingId: String) -> AnyPublisher<Booking?, Error> {
        let subject = PassthroughSubject<Booking?, Error>()

        let listener = db.collection(Self.collectionBookings)
            .document(bookingId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("[BookingRepository] Error listening to booking \(bookingId): \(error.localizedDescription)")
                    subject.send(nil)
                    return
                }

                guard let snapshot = snapshot, snapshot.exists,
                      let data = snapshot.data() else {
                    subject.send(nil)
                    return
                }

                let booking = self.mapDocumentToBooking(id: snapshot.documentID, data: data)
                subject.send(booking)
            }

        listeners.append(listener)

        return subject
            .handleEvents(receiveCancel: { [weak self] in
                listener.remove()
                self?.listeners.removeAll { $0 === listener }
            })
            .eraseToAnyPublisher()
    }

    // MARK: - One-Shot Reads

    /// Fetch bookings for the current authenticated client.
    func getBookingsForCurrentClient() async throws -> [Booking] {
        guard let userId = currentUserId else {
            throw BookingError.notAuthenticated
        }

        let snapshot = try await db.collection(Self.collectionBookings)
            .whereField("clientId", isEqualTo: userId)
            .order(by: "startTime", descending: true)
            .getDocuments()

        return mapSnapshotToBookings(snapshot)
    }

    /// Fetch a single booking by ID.
    func fetchBooking(bookingId: String) async throws -> Booking {
        let doc = try await db.collection(Self.collectionBookings)
            .document(bookingId)
            .getDocument()

        guard doc.exists, let data = doc.data() else {
            throw BookingError.notFound
        }

        return mapDocumentToBooking(id: doc.documentID, data: data)
    }

    // MARK: - Write Operations

    /// Create a new booking. Returns the new document ID.
    func createBooking(_ booking: Booking) async throws -> String {
        let now = Int64(Date().timeIntervalSince1970 * 1000)

        var data: [String: Any] = [
            "clientId": booking.clientId,
            "clientName": booking.clientName,
            "businessId": booking.businessId,
            "orgId": booking.orgId,
            "organizationId": booking.organizationId,
            "dogName": booking.dogName,
            "serviceType": booking.serviceType,
            "startTime": booking.startTime,
            "endTime": booking.endTime,
            "status": BookingStatus.pending.rawValue,
            "location": booking.location,
            "price": booking.price,
            "isPaid": false,
            "createdAt": now,
            "updatedAt": now
        ]

        // Optional fields
        if let v = booking.dogBreed { data["dogBreed"] = v }
        if let v = booking.notes { data["notes"] = v }
        if let v = booking.assignedTo { data["assignedTo"] = v }
        if let v = booking.clientPhone { data["clientPhone"] = v }
        if let v = booking.clientEmail { data["clientEmail"] = v }
        if let v = booking.clientAvatar { data["clientAvatar"] = v }
        if let v = booking.dogAvatar { data["dogAvatar"] = v }
        if let v = booking.petId { data["petId"] = v }
        if let v = booking.specialInstructions { data["specialInstructions"] = v }
        if let v = booking.specialRequirements { data["specialRequirements"] = v }

        let docRef = try await db.collection(Self.collectionBookings).addDocument(data: data)
        print("[BookingRepository] Created booking: \(docRef.documentID)")
        return docRef.documentID
    }

    /// Check the caller is a participant in the booking (client, business, or assigned provider).
    private func assertCallerIsParticipant(bookingId: String) async throws {
        guard let uid = currentUserId else {
            throw NSError(domain: "BookingRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        let snap = try await db.collection(Self.collectionBookings).document(bookingId).getDocument()
        guard let data = snap.data() else {
            throw NSError(domain: "BookingRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Booking not found"])
        }
        let clientId = data["clientId"] as? String
        let businessId = data["businessId"] as? String
        let assignedTo = data["assignedTo"] as? String
        let participants: [String] = [clientId, businessId, assignedTo].compactMap { $0 }
        guard participants.contains(uid) else {
            throw NSError(domain: "BookingRepository", code: 403, userInfo: [NSLocalizedDescriptionKey: "Not authorized to modify this booking"])
        }
    }

    /// Update the status of a booking.
    func updateBookingStatus(bookingId: String, status: BookingStatus) async throws {
        try await assertCallerIsParticipant(bookingId: bookingId)

        let updates: [String: Any] = [
            "status": status.rawValue,
            "updatedAt": Int64(Date().timeIntervalSince1970 * 1000)
        ]

        try await db.collection(Self.collectionBookings)
            .document(bookingId)
            .updateData(updates)

        print("[BookingRepository] Updated booking \(bookingId) status to \(status.rawValue)")
    }

    /// Cancel a booking with an optional reason.
    func cancelBooking(bookingId: String, reason: String? = nil) async throws {
        try await assertCallerIsParticipant(bookingId: bookingId)

        var updates: [String: Any] = [
            "status": BookingStatus.cancelled.rawValue,
            "updatedAt": Int64(Date().timeIntervalSince1970 * 1000)
        ]

        if let reason = reason {
            updates["cancellationReason"] = reason
        }

        try await db.collection(Self.collectionBookings)
            .document(bookingId)
            .updateData(updates)

        print("[BookingRepository] Cancelled booking \(bookingId)")
    }

    // MARK: - Cleanup

    /// Remove all active snapshot listeners.
    func cleanup() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }

    deinit {
        cleanup()
    }

    // MARK: - Mapping

    private func mapSnapshotToBookings(_ snapshot: QuerySnapshot?) -> [Booking] {
        guard let documents = snapshot?.documents else { return [] }
        return documents.map { doc in
            mapDocumentToBooking(id: doc.documentID, data: doc.data())
        }
    }

    private func mapDocumentToBooking(id: String, data: [String: Any]) -> Booking {
        Booking(
            id: id,
            clientId: data["clientId"] as? String ?? "",
            clientName: data["clientName"] as? String ?? "",
            businessId: data["businessId"] as? String ?? "",
            orgId: data["orgId"] as? String ?? "",
            organizationId: data["organizationId"] as? String ?? "",
            dogName: data["dogName"] as? String ?? "",
            dogBreed: data["dogBreed"] as? String,
            serviceType: data["serviceType"] as? String ?? BookingServiceType.walk.rawValue,
            startTime: (data["startTime"] as? NSNumber)?.int64Value ?? 0,
            endTime: (data["endTime"] as? NSNumber)?.int64Value ?? 0,
            status: data["status"] as? String ?? BookingStatus.pending.rawValue,
            location: data["location"] as? String ?? "",
            notes: data["notes"] as? String,
            price: (data["price"] as? NSNumber)?.doubleValue ?? 0.0,
            isPaid: data["isPaid"] as? Bool ?? false,
            assignedTo: data["assignedTo"] as? String,
            clientPhone: data["clientPhone"] as? String,
            clientEmail: data["clientEmail"] as? String,
            clientAvatar: data["clientAvatar"] as? String,
            dogAvatar: data["dogAvatar"] as? String,
            petId: data["petId"] as? String,
            specialInstructions: data["specialInstructions"] as? String,
            specialRequirements: data["specialRequirements"] as? String,
            cancellationReason: data["cancellationReason"] as? String,
            createdAt: (data["createdAt"] as? NSNumber)?.int64Value ?? Int64(Date().timeIntervalSince1970 * 1000),
            updatedAt: (data["updatedAt"] as? NSNumber)?.int64Value ?? Int64(Date().timeIntervalSince1970 * 1000)
        )
    }
}

// MARK: - Errors

enum BookingError: LocalizedError {
    case notAuthenticated
    case notFound
    case invalidStatusTransition(from: BookingStatus, to: BookingStatus)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .notFound:
            return "Booking not found"
        case .invalidStatusTransition(let from, let to):
            return "Invalid status transition: \(from.displayName) -> \(to.displayName)"
        }
    }
}
