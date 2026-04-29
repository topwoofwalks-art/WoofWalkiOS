import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Daycare Models

struct DaycareActivity: Identifiable {
    let id: String
    let type: String // "meal", "play", "bathroom", "nap", "socialisation", "note"
    let title: String
    let description: String
    let timestamp: Date
    let photoUrl: String?

    var icon: String {
        switch type {
        case "meal": return "fork.knife"
        case "play": return "tennisball.fill"
        case "bathroom": return "leaf.fill"
        case "nap": return "moon.zzz.fill"
        case "socialisation": return "dog.fill"
        case "note": return "note.text"
        default: return "circle.fill"
        }
    }

    var iconColor: Color {
        switch type {
        case "meal": return .orange60
        case "play": return .turquoise60
        case "bathroom": return Color(hex: 0x8B6914)
        case "nap": return Color(hex: 0x5C6BC0)
        case "socialisation": return Color.success60
        case "note": return .neutral60
        default: return .neutral50
        }
    }
}

struct PlaySummary: Identifiable {
    let id: String
    let groupName: String
    let duration: Int // minutes
    let playmates: [String]
    let notes: String
}

struct SocialisationNote: Identifiable {
    let id: String
    let text: String
    let dogInteracted: String?
    let timestamp: Date
}

struct DaycarePhoto: Identifiable {
    let id: String
    let url: String
    let caption: String
    let timestamp: Date
}

// MARK: - ViewModel

@MainActor
class DaycareLiveViewModel: ObservableObject {
    // MARK: - Published State

    @Published var facilityName: String = ""
    @Published var dogName: String = ""
    @Published var status: String = "checked_in"
    @Published var mood: String = "happy"
    @Published var moodNote: String = ""
    @Published var isNapping = false
    @Published var napStartTime: Date?
    @Published var napDurationMinutes: Int = 0
    @Published var activities: [DaycareActivity] = []
    @Published var playSummaries: [PlaySummary] = []
    @Published var socialisationNotes: [SocialisationNote] = []
    @Published var photos: [DaycarePhoto] = []
    @Published var checkInTime: Date?
    @Published var expectedPickupTime: Date?
    @Published var facilityPhone: String?
    @Published var pickupRequested = false
    @Published var isLoading = true
    @Published var error: String?
    @Published var snackbarMessage: String?

    // MARK: - Private

    private let db = Firestore.firestore()
    private var sessionListener: ListenerRegistration?
    private var activitiesListener: ListenerRegistration?
    private var photosListener: ListenerRegistration?
    private let sessionId: String
    private var napTimer: Timer?

    // MARK: - Init / Deinit

    init(sessionId: String) {
        self.sessionId = sessionId
        startListening()
    }

    deinit {
        sessionListener?.remove()
        activitiesListener?.remove()
        photosListener?.remove()
        napTimer?.invalidate()
    }

    // MARK: - Computed Properties

    var moodEmoji: String {
        switch mood {
        case "happy": return "😊"
        case "excited": return "🤩"
        case "calm": return "😌"
        case "tired": return "😴"
        case "anxious": return "😰"
        case "playful": return "🐕"
        case "sleeping": return "😴"
        default: return "🐶"
        }
    }

    var moodLabel: String {
        mood.capitalized
    }

    var moodBannerColor: Color {
        switch mood {
        case "happy", "excited", "playful": return Color.success60
        case "calm": return .turquoise60
        case "tired", "sleeping": return Color(hex: 0x5C6BC0)
        case "anxious": return .orange60
        default: return .turquoise60
        }
    }

    var sessionProgressFraction: Double {
        guard let checkIn = checkInTime, let pickup = expectedPickupTime else { return 0 }
        let total = pickup.timeIntervalSince(checkIn)
        guard total > 0 else { return 0 }
        let elapsed = Date().timeIntervalSince(checkIn)
        return min(1.0, max(0, elapsed / total))
    }

    var sessionProgressPercent: Int {
        Int(sessionProgressFraction * 100)
    }

    var napDurationString: String {
        if napDurationMinutes < 60 {
            return "\(napDurationMinutes) min"
        }
        return "\(napDurationMinutes / 60)h \(napDurationMinutes % 60)m"
    }

    var statusDisplayText: String {
        switch status {
        case "checked_in": return "Checked In"
        case "playing": return "Playing"
        case "napping": return "Napping"
        case "feeding": return "Feeding"
        case "pickup_requested": return "Pickup Requested"
        case "checked_out": return "Checked Out"
        default: return status.capitalized
        }
    }

    // MARK: - Actions

    func requestPickup() {
        guard !pickupRequested else { return }

        Task {
            do {
                try await db.collection("daycare_sessions")
                    .document(sessionId)
                    .updateData([
                        "pickupRequested": true,
                        "pickupRequestedAt": FieldValue.serverTimestamp()
                    ])
                pickupRequested = true
                snackbarMessage = "Pickup notification sent!"
            } catch {
                print("[DaycareLiveVM] Pickup request error: \(error.localizedDescription)")
                snackbarMessage = "Failed to send pickup request"
            }
        }
    }

    // MARK: - Firestore Listeners

    private func startListening() {
        isLoading = true

        sessionListener = db.collection("daycare_sessions")
            .document(sessionId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false

                if let error = error {
                    print("[DaycareLiveVM] Listener error: \(error.localizedDescription)")
                    self.error = error.localizedDescription
                    return
                }

                guard let data = snapshot?.data() else {
                    self.error = "Session not found"
                    return
                }

                self.parseSession(data)
            }

        // Activities subcollection
        activitiesListener = db.collection("daycare_sessions")
            .document(sessionId)
            .collection("activities")
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error = error {
                    print("[DaycareLiveVM] Activities listener error: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else { return }

                self.activities = documents.compactMap { doc in
                    let data = doc.data()
                    return DaycareActivity(
                        id: doc.documentID,
                        type: data["type"] as? String ?? "note",
                        title: data["title"] as? String ?? "",
                        description: data["description"] as? String ?? "",
                        timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                        photoUrl: data["photoUrl"] as? String
                    )
                }
            }

        // Photos subcollection
        photosListener = db.collection("daycare_sessions")
            .document(sessionId)
            .collection("photos")
            .order(by: "timestamp", descending: true)
            .limit(to: 30)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error = error {
                    print("[DaycareLiveVM] Photos listener error: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else { return }

                self.photos = documents.compactMap { doc in
                    let data = doc.data()
                    guard let url = data["url"] as? String else { return nil }
                    return DaycarePhoto(
                        id: doc.documentID,
                        url: url,
                        caption: data["caption"] as? String ?? "",
                        timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    )
                }
            }
    }

    private func parseSession(_ data: [String: Any]) {
        facilityName = data["facilityName"] as? String ?? "Daycare"
        dogName = data["dogName"] as? String ?? "Your Dog"
        status = data["status"] as? String ?? "checked_in"
        mood = data["mood"] as? String ?? "happy"
        moodNote = data["moodNote"] as? String ?? ""
        facilityPhone = data["facilityPhone"] as? String
        pickupRequested = data["pickupRequested"] as? Bool ?? false

        if let ts = data["checkInTime"] as? Timestamp { checkInTime = ts.dateValue() }
        if let ts = data["expectedPickupTime"] as? Timestamp { expectedPickupTime = ts.dateValue() }

        // Nap tracking
        let wasNapping = isNapping
        isNapping = data["isNapping"] as? Bool ?? false

        if isNapping {
            if let ts = data["napStartTime"] as? Timestamp {
                napStartTime = ts.dateValue()
                napDurationMinutes = Int(Date().timeIntervalSince(ts.dateValue()) / 60)
            }
            if !wasNapping { startNapTimer() }
        } else {
            napTimer?.invalidate()
            napTimer = nil
            napDurationMinutes = data["lastNapDuration"] as? Int ?? 0
        }

        // Parse play summaries
        if let playData = data["playSummaries"] as? [[String: Any]] {
            playSummaries = playData.compactMap { dict in
                let id = dict["id"] as? String ?? UUID().uuidString
                let groupName = dict["groupName"] as? String ?? ""
                let duration = dict["duration"] as? Int ?? 0
                let playmates = dict["playmates"] as? [String] ?? []
                let notes = dict["notes"] as? String ?? ""
                return PlaySummary(id: id, groupName: groupName, duration: duration, playmates: playmates, notes: notes)
            }
        }

        // Parse socialisation notes
        if let socData = data["socialisationNotes"] as? [[String: Any]] {
            socialisationNotes = socData.compactMap { dict in
                let id = dict["id"] as? String ?? UUID().uuidString
                let text = dict["text"] as? String ?? ""
                let dog = dict["dogInteracted"] as? String
                let ts = (dict["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                return SocialisationNote(id: id, text: text, dogInteracted: dog, timestamp: ts)
            }
        }
    }

    private func startNapTimer() {
        napTimer?.invalidate()
        napTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let start = self.napStartTime else { return }
                self.napDurationMinutes = Int(Date().timeIntervalSince(start) / 60)
            }
        }
    }
}
