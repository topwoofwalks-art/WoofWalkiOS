import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// All daycare enum and data-model types (DaycareUpdateType, DogTemperament,
// DaycareIncidentType, DaycareIncidentSeverity, DaycareSessionStatus,
// DaycareEvent, DaycareIncident, DaycareDog, DaycareSession) live canonically
// in `Models/DaycareModels.swift`, including computed UI accessors
// (isActive, elapsedMinutes, progressPercent, elapsedFormatted, remainingFormatted).
// Plain UI helper extensions live in `ViewModels/Daycare+UIExtensions.swift`.

// MARK: - ViewModel

@MainActor
class DaycareConsoleViewModel: ObservableObject {

    // MARK: - Published State

    @Published var session: DaycareSession?
    @Published var isLoading = false
    @Published var error: String?
    @Published var uploadingPhoto = false
    @Published var selectedTab = 0 // 0 = Timeline, 1 = Dogs, 2 = Photos
    @Published var selectedDogId: String?

    // Sheet / dialog state
    @Published var showIncidentSheet = false
    @Published var showCompletionSheet = false
    @Published var showNoteSheet = false
    @Published var showTemperamentSheet = false
    @Published var showFeedingSheet = false
    @Published var showNapSheet = false
    @Published var showPlaySheet = false
    @Published var showSocialisationSheet = false
    @Published var showPhotoCapture = false
    @Published var fabExpanded = false

    // MARK: - Computed

    var hasActiveSession: Bool { session?.isActive ?? false }
    var totalDogCount: Int { session?.dogs.count ?? 0 }
    var nappingDogCount: Int { session?.dogs.filter { $0.isNapping }.count ?? 0 }
    var eventCount: Int { session?.events.count ?? 0 }
    var incidentCount: Int { session?.incidents.count ?? 0 }

    // MARK: - Private

    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private var sessionListener: ListenerRegistration?
    private var timer: Timer?

    // MARK: - Deinit

    deinit {
        sessionListener?.remove()
        timer?.invalidate()
    }

    // MARK: - Session Lifecycle

    func startSession(bookingId: String, dogIds: [String]) {
        guard let userId = auth.currentUser?.uid else {
            error = "Not signed in"
            return
        }

        isLoading = true
        error = nil

        Task {
            do {
                // Load booking data
                let bookingDoc = try? await db.collection("bookings").document(bookingId).getDocument()
                let clientName = bookingDoc?.data()?["clientName"] as? String ?? "Client"
                let clientPhone = bookingDoc?.data()?["clientPhone"] as? String
                let specialInstructions = bookingDoc?.data()?["specialInstructions"] as? String

                // Load dog details
                var dogs: [DaycareDog] = []
                for (index, dogId) in dogIds.enumerated() {
                    let dogDoc = try? await db.collection("dogs").document(dogId).getDocument()
                    let dog = DaycareDog(
                        id: dogId,
                        name: dogDoc?.data()?["name"] as? String ?? "Dog \(index + 1)",
                        breed: dogDoc?.data()?["breed"] as? String,
                        photoUrl: dogDoc?.data()?["photoUrl"] as? String,
                        ownerName: clientName,
                        ownerPhone: clientPhone,
                        specialInstructions: dogDoc?.data()?["specialInstructions"] as? String,
                        feedingInstructions: dogDoc?.data()?["feedingInstructions"] as? String,
                        medicationInstructions: dogDoc?.data()?["medicationInstructions"] as? String
                    )
                    dogs.append(dog)
                }

                let now = Date()
                let sessionId = UUID().uuidString
                let newSession = DaycareSession(
                    id: sessionId,
                    bookingId: bookingId,
                    clientName: clientName,
                    clientPhone: clientPhone,
                    dogs: dogs,
                    startedAt: now,
                    scheduledEndAt: now.addingTimeInterval(8 * 3600),
                    status: .inProgress,
                    specialInstructions: specialInstructions
                )

                // Persist to Firestore
                try await persistSession(newSession, userId: userId)

                session = newSession
                isLoading = false
                startElapsedTimer()

                print("[DaycareConsole] Session started: \(sessionId) with \(dogs.count) dogs")

            } catch {
                self.error = "Failed to start session: \(error.localizedDescription)"
                isLoading = false
                print("[DaycareConsole] Error starting session: \(error)")
            }
        }
    }

    func loadExistingSession(sessionId: String) {
        isLoading = true
        error = nil

        sessionListener = db.collection("daycare_sessions")
            .document(sessionId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("[DaycareConsole] Session listener error: \(error)")
                    self.error = error.localizedDescription
                    self.isLoading = false
                    return
                }

                guard let doc = snapshot, doc.exists, let data = doc.data() else {
                    self.error = "Session not found"
                    self.isLoading = false
                    return
                }

                Task { @MainActor in
                    await self.parseSessionDocument(sessionId: sessionId, data: data)
                    self.isLoading = false
                    self.startElapsedTimer()
                }
            }
    }

    // MARK: - Event Logging

    func logEvent(
        type: DaycareUpdateType,
        dogId: String? = nil,
        note: String? = nil,
        photoUri: String? = nil,
        temperament: DogTemperament? = nil,
        napDurationMinutes: Int? = nil
    ) {
        guard let session = session else { return }
        let dog = dogId.flatMap { id in session.dogs.first { $0.id == id } }

        let event = DaycareEvent(
            sessionId: session.id,
            dogId: dogId,
            dogName: dog?.name,
            type: type,
            note: note,
            photoUri: photoUri,
            temperament: temperament,
            napDurationMinutes: napDurationMinutes
        )

        // Update local state
        var updatedSession = session
        updatedSession.events.append(event)

        if type == .photo, let uri = photoUri {
            updatedSession.photos.append(uri)
        }

        // Update dog state
        if let dogId = dogId, let idx = updatedSession.dogs.firstIndex(where: { $0.id == dogId }) {
            switch type {
            case .napStart:
                updatedSession.dogs[idx].isNapping = true
                updatedSession.dogs[idx].napStartTime = Int64(Date().timeIntervalSince1970 * 1000)
                updatedSession.dogs[idx].eventCount += 1
            case .napEnd:
                updatedSession.dogs[idx].isNapping = false
                updatedSession.dogs[idx].napStartTime = nil
                updatedSession.dogs[idx].eventCount += 1
            case .temperament:
                updatedSession.dogs[idx].currentTemperament = temperament ?? updatedSession.dogs[idx].currentTemperament
                updatedSession.dogs[idx].eventCount += 1
            default:
                updatedSession.dogs[idx].eventCount += 1
            }
        }

        self.session = updatedSession
        dismissAllSheets()

        // Persist to Firestore
        Task {
            await persistEvent(sessionId: session.id, event: event)
            print("[DaycareConsole] Logged event: \(type.label) for \(dog?.name ?? "all dogs")")
        }
    }

    func logIncident(
        type: DaycareIncidentType,
        description: String,
        severity: DaycareIncidentSeverity,
        actionTaken: String?,
        dogId: String? = nil
    ) {
        guard let session = session else { return }
        let dog = dogId.flatMap { id in session.dogs.first { $0.id == id } }

        let incident = DaycareIncident(
            sessionId: session.id,
            dogId: dogId,
            dogName: dog?.name,
            type: type,
            severity: severity,
            description: description,
            actionTaken: actionTaken
        )

        var updatedSession = session
        updatedSession.incidents.append(incident)
        self.session = updatedSession
        showIncidentSheet = false

        Task {
            await persistIncident(sessionId: session.id, incident: incident)
            print("[DaycareConsole] Logged incident: \(type.label) (\(severity.label))")
        }
    }

    func uploadPhoto(image: UIImage, dogId: String?, caption: String?) {
        guard session != nil else { return }

        uploadingPhoto = true

        // In production, upload to Firebase Storage first.
        // For now, log a photo event with a placeholder URI.
        let placeholderUri = "local://photo_\(UUID().uuidString)"

        logEvent(
            type: .photo,
            dogId: dogId,
            note: caption,
            photoUri: placeholderUri
        )

        uploadingPhoto = false
        print("[DaycareConsole] Photo captured")
    }

    func updateSessionNotes(_ notes: String) {
        guard var s = session else { return }
        s.sessionNotes = notes
        session = s
        showNoteSheet = false

        Task {
            do {
                try await db.collection("daycare_sessions")
                    .document(s.id)
                    .updateData(["sessionNotes": notes])
            } catch {
                print("[DaycareConsole] Failed to persist session notes: \(error)")
            }
        }
    }

    // MARK: - Session Completion

    func completeSession(summary: String) {
        guard var s = session else { return }
        isLoading = true

        s.status = .completed
        s.endedAt = Date()
        s.sessionNotes = summary
        session = s
        showCompletionSheet = false

        Task {
            do {
                let data: [String: Any] = [
                    "status": DaycareSessionStatus.completed.rawValue,
                    "endedAt": Int64(Date().timeIntervalSince1970 * 1000),
                    "sessionNotes": summary,
                    "completedBy": auth.currentUser?.uid ?? "unknown",
                    "totalEvents": s.events.count,
                    "totalIncidents": s.incidents.count,
                    "totalPhotos": s.photos.count,
                    "elapsedMinutes": s.elapsedMinutes
                ]

                try await db.collection("daycare_sessions")
                    .document(s.id)
                    .updateData(data)

                isLoading = false
                timer?.invalidate()
                print("[DaycareConsole] Session completed: \(s.id)")
            } catch {
                self.error = "Failed to complete session: \(error.localizedDescription)"
                isLoading = false
                print("[DaycareConsole] Error completing session: \(error)")
            }
        }
    }

    func generateSessionSummary() -> String {
        guard let session = session else { return "" }
        let events = session.events

        let feedCount = events.filter { $0.type.isFeedType }.count
        let waterCount = events.filter { $0.type == .water }.count
        let playCount = events.filter { $0.type.isPlayType }.count
        let bathroomCount = events.filter { $0.type.isBathroomType }.count
        let napCount = events.filter { $0.type == .napStart }.count
        let photoCount = events.filter { $0.type == .photo }.count

        var lines: [String] = []
        lines.append("Daycare Session Summary")
        lines.append("Duration: \(session.elapsedFormatted)")
        lines.append("Dogs: \(session.dogs.map { $0.name }.joined(separator: ", "))")
        lines.append("")
        if feedCount > 0 { lines.append("Meals/snacks: \(feedCount)") }
        if waterCount > 0 { lines.append("Water breaks: \(waterCount)") }
        if playCount > 0 { lines.append("Play sessions: \(playCount)") }
        if bathroomCount > 0 { lines.append("Bathroom breaks: \(bathroomCount)") }
        if napCount > 0 { lines.append("Naps: \(napCount)") }
        if photoCount > 0 { lines.append("Photos taken: \(photoCount)") }
        if !session.incidents.isEmpty {
            lines.append("Incidents: \(session.incidents.count)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    func selectTab(_ tab: Int) { selectedTab = tab }
    func selectDog(_ dogId: String?) { selectedDogId = dogId }
    func clearError() { error = nil }

    func dismissAllSheets() {
        showIncidentSheet = false
        showCompletionSheet = false
        showNoteSheet = false
        showTemperamentSheet = false
        showFeedingSheet = false
        showNapSheet = false
        showPlaySheet = false
        showSocialisationSheet = false
        showPhotoCapture = false
        fabExpanded = false
    }

    // MARK: - Timer

    private func startElapsedTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.objectWillChange.send()
            }
        }
    }

    // MARK: - Firestore Persistence

    private func persistSession(_ session: DaycareSession, userId: String) async throws {
        var data: [String: Any] = [
            "bookingId": session.bookingId,
            "clientName": session.clientName,
            "dogIds": session.dogs.map { $0.id },
            "status": session.status.rawValue,
            "startedAt": Int64(Date().timeIntervalSince1970 * 1000),
            "createdBy": userId,
            "createdAt": Int64(Date().timeIntervalSince1970 * 1000)
        ]

        if let phone = session.clientPhone { data["clientPhone"] = phone }
        if let instructions = session.specialInstructions { data["specialInstructions"] = instructions }

        if let end = session.scheduledEndAt {
            data["scheduledEndAt"] = Int64(end.timeIntervalSince1970 * 1000)
        }

        for dog in session.dogs {
            data["dogName_\(dog.id)"] = dog.name
        }

        try await db.collection("daycare_sessions")
            .document(session.id)
            .setData(data)
    }

    private func persistEvent(sessionId: String, event: DaycareEvent) async {
        do {
            var data: [String: Any] = [
                "sessionId": sessionId,
                "timestamp": event.timestamp,
                "type": event.type.rawValue,
                "userId": auth.currentUser?.uid ?? "unknown"
            ]
            if let v = event.dogId { data["dogId"] = v }
            if let v = event.dogName { data["dogName"] = v }
            if let v = event.note { data["note"] = v }
            if let v = event.photoUri { data["photoUri"] = v }
            if let v = event.temperament { data["temperament"] = v.rawValue }
            if let v = event.napDurationMinutes { data["napDurationMinutes"] = v }

            try await db.collection("daycare_sessions")
                .document(sessionId)
                .collection("events")
                .document(event.id)
                .setData(data)
        } catch {
            print("[DaycareConsole] Failed to persist event: \(error)")
        }
    }

    private func persistIncident(sessionId: String, incident: DaycareIncident) async {
        do {
            var data: [String: Any] = [
                "sessionId": sessionId,
                "type": incident.type.rawValue,
                "severity": incident.severity.rawValue,
                "description": incident.description,
                "timestamp": incident.timestamp,
                "userId": auth.currentUser?.uid ?? "unknown"
            ]
            if let v = incident.dogId { data["dogId"] = v }
            if let v = incident.dogName { data["dogName"] = v }
            if let v = incident.actionTaken { data["actionTaken"] = v }
            if let v = incident.photoUri { data["photoUri"] = v }

            try await db.collection("daycare_sessions")
                .document(sessionId)
                .collection("incidents")
                .document(incident.id)
                .setData(data)
        } catch {
            print("[DaycareConsole] Failed to persist incident: \(error)")
        }
    }

    private func parseSessionDocument(sessionId: String, data: [String: Any]) async {
        let clientName = data["clientName"] as? String ?? "Client"
        let clientPhone = data["clientPhone"] as? String
        let specialInstructions = data["specialInstructions"] as? String
        let dogIds = data["dogIds"] as? [String] ?? []
        let statusRaw = data["status"] as? String ?? "IN_PROGRESS"
        let startedAtMs = data["startedAt"] as? Int64
        let scheduledEndMs = data["scheduledEndAt"] as? Int64
        let sessionNotes = data["sessionNotes"] as? String

        let dogs = dogIds.enumerated().map { (index, dogId) in
            DaycareDog(
                id: dogId,
                name: data["dogName_\(dogId)"] as? String ?? "Dog \(index + 1)",
                ownerName: clientName
            )
        }

        // Load events subcollection
        var events: [DaycareEvent] = []
        do {
            let eventsSnap = try await db.collection("daycare_sessions")
                .document(sessionId)
                .collection("events")
                .order(by: "timestamp")
                .getDocuments()

            events = eventsSnap.documents.compactMap { doc in
                let d = doc.data()
                return DaycareEvent(
                    id: doc.documentID,
                    sessionId: sessionId,
                    dogId: d["dogId"] as? String,
                    dogName: d["dogName"] as? String,
                    timestamp: d["timestamp"] as? Int64 ?? 0,
                    type: DaycareUpdateType.from(string: d["type"] as? String ?? "NOTE"),
                    note: d["note"] as? String,
                    photoUri: d["photoUri"] as? String,
                    temperament: (d["temperament"] as? String).flatMap { DogTemperament(rawValue: $0) },
                    napDurationMinutes: d["napDurationMinutes"] as? Int
                )
            }
        } catch {
            print("[DaycareConsole] Failed to load events: \(error)")
        }

        // Load incidents subcollection
        var incidents: [DaycareIncident] = []
        do {
            let incidentsSnap = try await db.collection("daycare_sessions")
                .document(sessionId)
                .collection("incidents")
                .order(by: "timestamp")
                .getDocuments()

            incidents = incidentsSnap.documents.compactMap { doc in
                let d = doc.data()
                return DaycareIncident(
                    id: doc.documentID,
                    sessionId: sessionId,
                    dogId: d["dogId"] as? String,
                    dogName: d["dogName"] as? String,
                    type: DaycareIncidentType(rawValue: d["type"] as? String ?? "OTHER") ?? .other,
                    severity: DaycareIncidentSeverity(rawValue: d["severity"] as? String ?? "LOW") ?? .low,
                    description: d["description"] as? String ?? "",
                    actionTaken: d["actionTaken"] as? String,
                    timestamp: d["timestamp"] as? Int64 ?? 0,
                    photoUri: d["photoUri"] as? String
                )
            }
        } catch {
            print("[DaycareConsole] Failed to load incidents: \(error)")
        }

        let photos = events.filter { $0.type == .photo }.compactMap { $0.photoUri }

        session = DaycareSession(
            id: sessionId,
            bookingId: data["bookingId"] as? String ?? "",
            clientName: clientName,
            clientPhone: clientPhone,
            dogs: dogs,
            events: events,
            incidents: incidents,
            photos: photos,
            sessionNotes: sessionNotes,
            startedAt: startedAtMs.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) },
            scheduledEndAt: scheduledEndMs.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) },
            status: DaycareSessionStatus(rawValue: statusRaw) ?? .inProgress,
            specialInstructions: specialInstructions
        )
    }
}
