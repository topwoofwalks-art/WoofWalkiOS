import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import Combine

/// Repository for booking operations against the "bookings" Firestore collection.
/// Mirrors the Android BookingRepository's Firestore queries and field names.
class BookingRepository: ObservableObject {
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private lazy var functions = Functions.functions(region: "europe-west2")
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
    ///
    /// **P0 SECURITY:** routes through the `createClientBooking` Cloud
    /// Function (parity with Android `UnifiedBookingFlowViewModel` and
    /// the Portal `ClientNewBookingSheet`). The CF re-resolves the price
    /// from the listing's sub-config server-side, so the client cannot
    /// pick the cheapest grooming size and charge Stripe for the most
    /// expensive. Direct `addDocument(...)` writes are unsafe — the
    /// pricing path bypasses `resolveSubSelection`.
    ///
    /// `subSelection` (R9) — optional per-vertical sub-config selection
    /// (e.g. `["walk": ["durationOptionId": "..."]]`). The CF resolves
    /// the actual price from this. `subSelectionLabel` is a pre-formatted
    /// human echo persisted on the doc for receipt UI.
    ///
    /// iOS-only fields on the local `Booking` struct (telemetry, optimistic
    /// UI markers, computed display strings) are NOT forwarded — the CF
    /// rejects unknown keys. Caller-side state lives in the local model.
    func createBooking(
        _ booking: Booking,
        subSelection: [String: Any]? = nil,
        subSelectionLabel: String? = nil
    ) async throws -> String {
        // Resolve dog IDs. Booking carries a single `petId` today; the CF
        // expects an array. If absent, fall back to empty (CF will reject
        // with invalid-argument — surface that error).
        let dogIds: [String] = booking.petId.map { [$0] } ?? []

        // CF expects providerId == org doc ID. Booking.orgId / businessId
        // are all set to provider.id by the call site; prefer orgId, fall
        // back through the same chain we've used in mappers.
        let providerId: String = !booking.orgId.isEmpty
            ? booking.orgId
            : (!booking.businessId.isEmpty ? booking.businessId : booking.organizationId)

        var payload: [String: Any] = [
            "providerId": providerId,
            "serviceType": booking.serviceType,
            "dogIds": dogIds,
            "startTime": booking.startTime,
            "endTime": booking.endTime
        ]

        // Notes — concatenate the structured iOS instructions blocks the
        // way Android does in `buildNotes`. Caller has already merged
        // them into `booking.notes`, so just forward.
        if let notes = booking.notes, !notes.isEmpty {
            payload["notes"] = notes
        }

        // R9 sub-selection (CF resolves price from this).
        if let sel = subSelection {
            payload["subSelection"] = sel
        }
        if let label = subSelectionLabel {
            payload["subSelectionLabel"] = label
        }

        // Per-vertical config dicts — CF accepts these as pass-through and
        // persists them on the booking doc. iOS' `Booking` struct flattens
        // the picker output into top-level fields (selectedVariantId,
        // selectedPackageId, dogSize, selectedAddOns, specialism), so
        // re-shape them into the dict-shape the CF / portal use.
        switch booking.serviceTypeEnum {
        case .walk:
            var walkConfig: [String: Any] = [:]
            if let id = booking.selectedVariantId { walkConfig["selectedDurationId"] = id }
            if !walkConfig.isEmpty { payload["walkConfig"] = walkConfig }
        case .grooming:
            var groomingConfig: [String: Any] = [:]
            if let id = booking.selectedVariantId { groomingConfig["selectedMenuItemId"] = id }
            if let id = booking.selectedPackageId { groomingConfig["selectedPackageId"] = id }
            if let addOns = booking.selectedAddOns, !addOns.isEmpty { groomingConfig["selectedAddOnIds"] = addOns }
            if let size = booking.dogSize { groomingConfig["dogSize"] = size }
            if !groomingConfig.isEmpty { payload["groomingConfig"] = groomingConfig }
        case .boarding:
            var boardingConfig: [String: Any] = [:]
            if let id = booking.selectedPackageId { boardingConfig["selectedRoomTypeId"] = id }
            if !boardingConfig.isEmpty { payload["boardingConfig"] = boardingConfig }
        case .training:
            var trainingConfig: [String: Any] = [:]
            if let id = booking.selectedVariantId { trainingConfig["sessionTypeId"] = id }
            if let id = booking.selectedPackageId { trainingConfig["programmeId"] = id }
            if let s = booking.specialism { trainingConfig["specialismId"] = s }
            if !trainingConfig.isEmpty { payload["trainingConfig"] = trainingConfig }
        case .daycare:
            var daycareConfig: [String: Any] = [:]
            if let id = booking.selectedVariantId { daycareConfig["sessionType"] = id }
            if !daycareConfig.isEmpty { payload["daycareConfig"] = daycareConfig }
        case .petSitting, .inSitting, .outSitting:
            var petSittingConfig: [String: Any] = [:]
            if let id = booking.selectedVariantId { petSittingConfig["visitType"] = id }
            if !petSittingConfig.isEmpty { payload["petSittingConfig"] = petSittingConfig }
        case .meetGreet:
            break // No per-vertical config — CF uses listing.basePrice.
        }

        // Call the CF. CF returns { bookingId, status, price }.
        let result = try await functions
            .httpsCallable("createClientBooking")
            .call(payload)

        guard let response = result.data as? [String: Any],
              let bookingId = response["bookingId"] as? String else {
            print("[BookingRepository] createClientBooking returned malformed response: \(String(describing: result.data))")
            throw BookingError.notFound
        }

        let resolvedPrice = (response["price"] as? NSNumber)?.doubleValue
        print("[BookingRepository] Created booking via CF: \(bookingId) (server price: \(resolvedPrice ?? -1))")
        return bookingId
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
