import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Care Models

enum CareServiceType: String {
    case sitting = "IN_SITTING"
    case boarding = "BOARDING"

    var displayName: String {
        switch self {
        case .sitting: return "Pet Sitting"
        case .boarding: return "Boarding"
        }
    }

    var icon: String {
        switch self {
        case .sitting: return "house.fill"
        case .boarding: return "building.2.fill"
        }
    }

    var collectionName: String {
        switch self {
        case .sitting: return "sitter_sessions"
        case .boarding: return "boarding_sessions"
        }
    }
}

struct CareActivity: Identifiable {
    let id: String
    let type: String // "feeding", "walk", "play", "medication", "bathroom", "sleep", "note"
    let title: String
    let description: String
    let timestamp: Date
    let photoUrl: String?

    var icon: String {
        switch type {
        case "feeding": return "fork.knife"
        case "walk": return "figure.walk"
        case "play": return "tennisball.fill"
        case "medication": return "pills.fill"
        case "bathroom": return "leaf.fill"
        case "sleep": return "moon.fill"
        case "note": return "note.text"
        default: return "circle.fill"
        }
    }

    var iconColor: Color {
        switch type {
        case "feeding": return .orange60
        case "walk": return Color.success60
        case "play": return .turquoise60
        case "medication": return .error60
        case "bathroom": return Color(hex: 0x8B6914)
        case "sleep": return Color(hex: 0x5C6BC0)
        case "note": return .neutral60
        default: return .neutral50
        }
    }
}

struct CareTask: Identifiable {
    let id: String
    let name: String
    let isCompleted: Bool
    let completedAt: Date?
}

struct FeedingStatus: Identifiable {
    let id: String
    let mealName: String // "Breakfast", "Lunch", "Dinner"
    let isCompleted: Bool
    let time: Date?
    let notes: String
}

struct CarePhoto: Identifiable {
    let id: String
    let url: String
    let caption: String
    let timestamp: Date
}

// MARK: - ViewModel

@MainActor
class CareLiveViewModel: ObservableObject {
    // MARK: - Published State

    @Published var sitterName: String = ""
    @Published var dogName: String = ""
    @Published var status: String = "active"
    @Published var serviceType: CareServiceType
    @Published var startDate: Date?
    @Published var endDate: Date?
    @Published var activities: [CareActivity] = []
    @Published var tasks: [CareTask] = []
    @Published var feedings: [FeedingStatus] = []
    @Published var medications: [CareTask] = []
    @Published var mood: String = "happy"
    @Published var moodNote: String = ""
    @Published var photos: [CarePhoto] = []
    @Published var dailySummaryUrl: String?
    @Published var sitterPhone: String?
    @Published var isLoading = true
    @Published var error: String?

    // MARK: - Private

    private let db = Firestore.firestore()
    private var sessionListener: ListenerRegistration?
    private var activitiesListener: ListenerRegistration?
    private let sessionId: String

    // MARK: - Init / Deinit

    init(sessionId: String, serviceType: CareServiceType) {
        self.sessionId = sessionId
        self.serviceType = serviceType
        startListening()
    }

    deinit {
        sessionListener?.remove()
        activitiesListener?.remove()
    }

    // MARK: - Computed Properties

    var dayCount: Int {
        guard let start = startDate else { return 1 }
        let days = Calendar.current.dateComponents([.day], from: start, to: Date()).day ?? 0
        return max(1, days + 1)
    }

    var totalDays: Int {
        guard let start = startDate, let end = endDate else { return 1 }
        let days = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
        return max(1, days + 1)
    }

    var taskCompletionFraction: Double {
        guard !tasks.isEmpty else { return 0 }
        let completed = tasks.filter(\.isCompleted).count
        return Double(completed) / Double(tasks.count)
    }

    var taskCompletionPercent: Int {
        Int(taskCompletionFraction * 100)
    }

    var moodEmoji: String {
        switch mood {
        case "happy": return "😊"
        case "excited": return "🤩"
        case "calm": return "😌"
        case "tired": return "😴"
        case "anxious": return "😰"
        case "playful": return "🐕"
        default: return "🐶"
        }
    }

    var moodLabel: String {
        mood.capitalized
    }

    var todayActivities: [CareActivity] {
        let calendar = Calendar.current
        return activities.filter { calendar.isDateInToday($0.timestamp) }
            .sorted { $0.timestamp > $1.timestamp }
    }

    // MARK: - Firestore Listener

    private func startListening() {
        isLoading = true

        let collection = serviceType.collectionName

        sessionListener = db.collection(collection)
            .document(sessionId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false

                if let error = error {
                    print("[CareLiveVM] Listener error: \(error.localizedDescription)")
                    self.error = error.localizedDescription
                    return
                }

                guard let data = snapshot?.data() else {
                    self.error = "Session not found"
                    return
                }

                self.parseSession(data)
            }

        // Listen to activities subcollection
        activitiesListener = db.collection(collection)
            .document(sessionId)
            .collection("activities")
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error = error {
                    print("[CareLiveVM] Activities listener error: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else { return }

                self.activities = documents.compactMap { doc in
                    let data = doc.data()
                    let type = data["type"] as? String ?? "note"
                    let title = data["title"] as? String ?? ""
                    let description = data["description"] as? String ?? ""
                    let ts = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    let photoUrl = data["photoUrl"] as? String
                    return CareActivity(
                        id: doc.documentID,
                        type: type,
                        title: title,
                        description: description,
                        timestamp: ts,
                        photoUrl: photoUrl
                    )
                }
            }
    }

    private func parseSession(_ data: [String: Any]) {
        sitterName = data["sitterName"] as? String ?? "Your Sitter"
        dogName = data["dogName"] as? String ?? "Your Dog"
        status = data["status"] as? String ?? "active"
        sitterPhone = data["sitterPhone"] as? String
        mood = data["mood"] as? String ?? "happy"
        moodNote = data["moodNote"] as? String ?? ""
        dailySummaryUrl = data["dailySummaryUrl"] as? String

        if let ts = data["startDate"] as? Timestamp { startDate = ts.dateValue() }
        if let ts = data["endDate"] as? Timestamp { endDate = ts.dateValue() }

        // Parse tasks
        if let taskData = data["tasks"] as? [[String: Any]] {
            tasks = taskData.compactMap { dict in
                let id = dict["id"] as? String ?? UUID().uuidString
                let name = dict["name"] as? String ?? ""
                let isCompleted = dict["isCompleted"] as? Bool ?? false
                let completedAt = (dict["completedAt"] as? Timestamp)?.dateValue()
                return CareTask(id: id, name: name, isCompleted: isCompleted, completedAt: completedAt)
            }
        }

        // Parse feedings
        if let feedingData = data["feedings"] as? [[String: Any]] {
            feedings = feedingData.compactMap { dict in
                let id = dict["id"] as? String ?? UUID().uuidString
                let mealName = dict["mealName"] as? String ?? ""
                let isCompleted = dict["isCompleted"] as? Bool ?? false
                let time = (dict["time"] as? Timestamp)?.dateValue()
                let notes = dict["notes"] as? String ?? ""
                return FeedingStatus(id: id, mealName: mealName, isCompleted: isCompleted, time: time, notes: notes)
            }
        }

        // Parse medications
        if let medData = data["medications"] as? [[String: Any]] {
            medications = medData.compactMap { dict in
                let id = dict["id"] as? String ?? UUID().uuidString
                let name = dict["name"] as? String ?? ""
                let isCompleted = dict["isCompleted"] as? Bool ?? false
                let completedAt = (dict["completedAt"] as? Timestamp)?.dateValue()
                return CareTask(id: id, name: name, isCompleted: isCompleted, completedAt: completedAt)
            }
        }

        // Parse photos
        if let photoData = data["photos"] as? [[String: Any]] {
            photos = photoData.compactMap { dict in
                guard let url = dict["url"] as? String else { return nil }
                let id = dict["id"] as? String ?? UUID().uuidString
                let caption = dict["caption"] as? String ?? ""
                let ts = (dict["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                return CarePhoto(id: id, url: url, caption: caption, timestamp: ts)
            }
            .sorted { $0.timestamp > $1.timestamp }
        }
    }
}
