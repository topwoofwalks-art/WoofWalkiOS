import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Enums

enum DaycareUpdateType: String, CaseIterable {
    case feedBreakfast = "FEED_BREAKFAST"
    case feedLunch = "FEED_LUNCH"
    case feedSnack = "FEED_SNACK"
    case water = "WATER"
    case napStart = "NAP_START"
    case napEnd = "NAP_END"
    case playSoloIndoor = "PLAY_SOLO_INDOOR"
    case playSoloOutdoor = "PLAY_SOLO_OUTDOOR"
    case playGroupIndoor = "PLAY_GROUP_INDOOR"
    case playGroupOutdoor = "PLAY_GROUP_OUTDOOR"
    case bathroomPee = "BATHROOM_PEE"
    case bathroomPoo = "BATHROOM_POO"
    case socialisation = "SOCIALISATION"
    case temperament = "TEMPERAMENT"
    case photo = "PHOTO"
    case note = "NOTE"
    case incident = "INCIDENT"

    var label: String {
        switch self {
        case .feedBreakfast: return "Breakfast"
        case .feedLunch: return "Lunch"
        case .feedSnack: return "Snack"
        case .water: return "Water"
        case .napStart: return "Nap Started"
        case .napEnd: return "Nap Ended"
        case .playSoloIndoor: return "Solo Play (Indoor)"
        case .playSoloOutdoor: return "Solo Play (Outdoor)"
        case .playGroupIndoor: return "Group Play (Indoor)"
        case .playGroupOutdoor: return "Group Play (Outdoor)"
        case .bathroomPee: return "Pee"
        case .bathroomPoo: return "Poo"
        case .socialisation: return "Socialisation"
        case .temperament: return "Temperament Check"
        case .photo: return "Photo"
        case .note: return "Note"
        case .incident: return "Incident"
        }
    }

    var icon: String {
        switch self {
        case .feedBreakfast, .feedLunch: return "fork.knife"
        case .feedSnack: return "birthday.cake"
        case .water: return "drop.fill"
        case .napStart: return "bed.double.fill"
        case .napEnd: return "sun.max.fill"
        case .playSoloIndoor: return "sportscourt.fill"
        case .playSoloOutdoor: return "leaf.fill"
        case .playGroupIndoor: return "person.3.fill"
        case .playGroupOutdoor: return "tree.fill"
        case .bathroomPee: return "drop"
        case .bathroomPoo: return "leaf.circle"
        case .socialisation: return "heart.fill"
        case .temperament: return "brain.head.profile"
        case .photo: return "camera.fill"
        case .note: return "note.text"
        case .incident: return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .feedBreakfast, .feedLunch: return Color(red: 1.0, green: 0.6, blue: 0.0)
        case .feedSnack: return Color(red: 1.0, green: 0.72, blue: 0.3)
        case .water: return Color(red: 0.13, green: 0.59, blue: 0.95)
        case .napStart: return Color(red: 0.49, green: 0.34, blue: 0.76)
        case .napEnd: return Color(red: 1.0, green: 0.79, blue: 0.16)
        case .playSoloIndoor: return Color(red: 0.3, green: 0.69, blue: 0.31)
        case .playSoloOutdoor: return Color(red: 0.4, green: 0.73, blue: 0.42)
        case .playGroupIndoor: return Color(red: 0.15, green: 0.65, blue: 0.6)
        case .playGroupOutdoor: return Color(red: 0.18, green: 0.49, blue: 0.2)
        case .bathroomPee: return Color(red: 0.26, green: 0.65, blue: 0.96)
        case .bathroomPoo: return Color(red: 0.55, green: 0.43, blue: 0.39)
        case .socialisation: return Color(red: 0.93, green: 0.25, blue: 0.48)
        case .temperament: return Color(red: 0.36, green: 0.42, blue: 0.75)
        case .photo: return Color(red: 0.0, green: 0.54, blue: 0.48)
        case .note: return Color(red: 0.47, green: 0.56, blue: 0.61)
        case .incident: return Color(red: 0.96, green: 0.26, blue: 0.21)
        }
    }

    var isFeedType: Bool {
        self == .feedBreakfast || self == .feedLunch || self == .feedSnack
    }

    var isPlayType: Bool {
        self == .playSoloIndoor || self == .playSoloOutdoor || self == .playGroupIndoor || self == .playGroupOutdoor
    }

    var isBathroomType: Bool {
        self == .bathroomPee || self == .bathroomPoo
    }

    static func from(_ value: String) -> DaycareUpdateType {
        DaycareUpdateType(rawValue: value) ?? .note
    }
}

enum DogTemperament: String, CaseIterable {
    case happy = "HAPPY"
    case anxious = "ANXIOUS"
    case tired = "TIRED"
    case energetic = "ENERGETIC"
    case calm = "CALM"
    case playful = "PLAYFUL"

    var label: String {
        switch self {
        case .happy: return "Happy"
        case .anxious: return "Anxious"
        case .tired: return "Tired"
        case .energetic: return "Energetic"
        case .calm: return "Calm"
        case .playful: return "Playful"
        }
    }

    var emoji: String {
        switch self {
        case .happy: return "😃"
        case .anxious: return "😟"
        case .tired: return "😴"
        case .energetic: return "🔥"
        case .calm: return "☺️"
        case .playful: return "🥳"
        }
    }
}

enum DaycareIncidentType: String, CaseIterable {
    case injury = "INJURY"
    case illness = "ILLNESS"
    case fight = "FIGHT"
    case escapeAttempt = "ESCAPE_ATTEMPT"
    case propertyDamage = "PROPERTY_DAMAGE"
    case behaviouralIssue = "BEHAVIOURAL_ISSUE"
    case feedingRefused = "FEEDING_REFUSED"
    case allergicReaction = "ALLERGIC_REACTION"
    case other = "OTHER"

    var label: String {
        switch self {
        case .injury: return "Injury"
        case .illness: return "Illness"
        case .fight: return "Fight"
        case .escapeAttempt: return "Escape Attempt"
        case .propertyDamage: return "Property Damage"
        case .behaviouralIssue: return "Behavioural Issue"
        case .feedingRefused: return "Feeding Refused"
        case .allergicReaction: return "Allergic Reaction"
        case .other: return "Other"
        }
    }
}

enum DaycareIncidentSeverity: String, CaseIterable {
    case low = "LOW"
    case medium = "MEDIUM"
    case high = "HIGH"
    case critical = "CRITICAL"

    var label: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

enum DaycareSessionStatus: String {
    case scheduled = "SCHEDULED"
    case inProgress = "IN_PROGRESS"
    case completed = "COMPLETED"
    case cancelled = "CANCELLED"
}

// MARK: - Models

struct DaycareEvent: Identifiable {
    let id: String
    let sessionId: String
    var dogId: String?
    var dogName: String?
    let timestamp: Int64
    let type: DaycareUpdateType
    var note: String?
    var photoUri: String?
    var temperament: DogTemperament?
    var napDurationMinutes: Int?

    init(
        id: String = UUID().uuidString,
        sessionId: String,
        dogId: String? = nil,
        dogName: String? = nil,
        timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        type: DaycareUpdateType,
        note: String? = nil,
        photoUri: String? = nil,
        temperament: DogTemperament? = nil,
        napDurationMinutes: Int? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.dogId = dogId
        self.dogName = dogName
        self.timestamp = timestamp
        self.type = type
        self.note = note
        self.photoUri = photoUri
        self.temperament = temperament
        self.napDurationMinutes = napDurationMinutes
    }

    var formattedTime: String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    func toMap() -> [String: Any?] {
        [
            "sessionId": sessionId,
            "dogId": dogId,
            "dogName": dogName,
            "timestamp": timestamp,
            "type": type.rawValue,
            "note": note,
            "photoUri": photoUri,
            "temperament": temperament?.rawValue,
            "napDurationMinutes": napDurationMinutes
        ]
    }
}

struct DaycareIncident: Identifiable {
    let id: String
    let sessionId: String
    var dogId: String?
    var dogName: String?
    let type: DaycareIncidentType
    let severity: DaycareIncidentSeverity
    let description: String
    var actionTaken: String?
    let timestamp: Int64
    var photoUri: String?

    init(
        id: String = UUID().uuidString,
        sessionId: String,
        dogId: String? = nil,
        dogName: String? = nil,
        type: DaycareIncidentType,
        severity: DaycareIncidentSeverity,
        description: String,
        actionTaken: String? = nil,
        timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        photoUri: String? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.dogId = dogId
        self.dogName = dogName
        self.type = type
        self.severity = severity
        self.description = description
        self.actionTaken = actionTaken
        self.timestamp = timestamp
        self.photoUri = photoUri
    }

    var formattedTime: String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    func toMap() -> [String: Any?] {
        [
            "sessionId": sessionId,
            "dogId": dogId,
            "dogName": dogName,
            "type": type.rawValue,
            "severity": severity.rawValue,
            "description": description,
            "actionTaken": actionTaken,
            "timestamp": timestamp,
            "photoUri": photoUri
        ]
    }
}

struct DaycareDog: Identifiable {
    let id: String
    let name: String
    var breed: String?
    var photoUrl: String?
    let ownerName: String
    var ownerPhone: String?
    var specialInstructions: String?
    var feedingInstructions: String?
    var medicationInstructions: String?
    var currentTemperament: DogTemperament = .happy
    var isNapping: Bool = false
    var napStartTime: Int64?
    var eventCount: Int = 0
}

struct DaycareSession {
    let id: String
    let bookingId: String
    let clientName: String
    var clientPhone: String?
    var facilityName: String?
    var dogs: [DaycareDog]
    var events: [DaycareEvent] = []
    var incidents: [DaycareIncident] = []
    var photos: [String] = []
    var sessionNotes: String?
    var startedAt: Date?
    var scheduledEndAt: Date?
    var endedAt: Date?
    var status: DaycareSessionStatus = .scheduled
    var specialInstructions: String?

    var isActive: Bool { status == .inProgress }

    var elapsedMinutes: Int {
        guard let start = startedAt else { return 0 }
        let end = endedAt ?? Date()
        return Int(end.timeIntervalSince(start) / 60)
    }

    var totalSessionMinutes: Int {
        guard let start = startedAt else { return 480 }
        let end = scheduledEndAt ?? start.addingTimeInterval(8 * 3600)
        return Int(end.timeIntervalSince(start) / 60)
    }

    var progressPercent: Double {
        let total = totalSessionMinutes
        guard total > 0 else { return 0 }
        return min(max(Double(elapsedMinutes) / Double(total), 0), 1)
    }

    var elapsedFormatted: String {
        let h = elapsedMinutes / 60
        let m = elapsedMinutes % 60
        return "\(h)h \(m)m"
    }

    var remainingFormatted: String {
        let remaining = max(totalSessionMinutes - elapsedMinutes, 0)
        let h = remaining / 60
        let m = remaining % 60
        return "\(h)h \(m)m"
    }
}

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
                    type: DaycareUpdateType.from(d["type"] as? String ?? "NOTE"),
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
