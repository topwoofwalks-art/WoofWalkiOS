import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Grooming Models

struct GroomingStep: Identifiable {
    let id: Int
    let name: String
    let icon: String
    var isCompleted: Bool
    var isActive: Bool
    var completedAt: Date?
}

struct GroomingPhoto: Identifiable {
    let id: String
    let url: String
    let caption: String
    let type: String // "before", "during", "after"
    let timestamp: Date
}

struct HealthFinding: Identifiable {
    let id: String
    let title: String
    let description: String
    let severity: String // "low", "medium", "high"
    let timestamp: Date

    var severityColor: Color {
        switch severity {
        case "high": return .error60
        case "medium": return .orange60
        default: return Color.success60
        }
    }

    var severityIcon: String {
        switch severity {
        case "high": return "exclamationmark.triangle.fill"
        case "medium": return "exclamationmark.circle.fill"
        default: return "info.circle.fill"
        }
    }
}

// MARK: - ViewModel

@MainActor
class GroomingLiveViewModel: ObservableObject {
    // MARK: - Published State

    @Published var groomerName: String = ""
    @Published var dogName: String = ""
    @Published var status: String = "waiting"
    @Published var currentStepIndex: Int = 0
    @Published var steps: [GroomingStep] = []
    @Published var photos: [GroomingPhoto] = []
    @Published var healthFindings: [HealthFinding] = []
    @Published var groomerPhone: String?
    @Published var startedAt: Date?
    @Published var estimatedEndTime: Date?
    @Published var notes: String = ""
    @Published var isLoading = true
    @Published var error: String?

    // MARK: - Private

    private let db = Firestore.firestore()
    private var sessionListener: ListenerRegistration?
    private let sessionId: String

    private static let stepDefinitions: [(name: String, icon: String)] = [
        ("Pre-inspection", "magnifyingglass"),
        ("Bath", "drop.fill"),
        ("Dry", "wind"),
        ("Brush", "comb.fill"),
        ("Nails", "scissors"),
        ("Ears", "ear.fill"),
        ("Teeth", "mouth.fill"),
        ("Styling", "sparkles"),
        ("Final Check", "checkmark.seal.fill")
    ]

    // MARK: - Init / Deinit

    init(sessionId: String) {
        self.sessionId = sessionId
        self.steps = Self.stepDefinitions.enumerated().map { index, def in
            GroomingStep(
                id: index,
                name: def.name,
                icon: def.icon,
                isCompleted: false,
                isActive: index == 0
            )
        }
        startListening()
    }

    deinit {
        sessionListener?.remove()
    }

    // MARK: - Computed Properties

    var progressFraction: Double {
        guard !steps.isEmpty else { return 0 }
        let completed = steps.filter(\.isCompleted).count
        return Double(completed) / Double(steps.count)
    }

    var etaString: String {
        guard let end = estimatedEndTime else { return "Calculating..." }
        let remaining = end.timeIntervalSince(Date())
        if remaining <= 0 { return "Almost done!" }
        let minutes = Int(remaining / 60)
        if minutes < 60 {
            return "\(minutes) min remaining"
        }
        return "\(minutes / 60)h \(minutes % 60)m remaining"
    }

    var statusDisplayText: String {
        switch status {
        case "in_progress": return "In Progress"
        case "completed": return "Completed"
        case "waiting": return "Waiting to Start"
        case "paused": return "Paused"
        default: return status.capitalized
        }
    }

    // MARK: - Firestore Listener

    private func startListening() {
        isLoading = true

        sessionListener = db.collection("grooming_sessions")
            .document(sessionId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false

                if let error = error {
                    print("[GroomingLiveVM] Listener error: \(error.localizedDescription)")
                    self.error = error.localizedDescription
                    return
                }

                guard let data = snapshot?.data() else {
                    self.error = "Session not found"
                    return
                }

                self.parseSession(data)
            }
    }

    private func parseSession(_ data: [String: Any]) {
        groomerName = data["groomerName"] as? String ?? "Your Groomer"
        dogName = data["dogName"] as? String ?? "Your Dog"
        status = data["status"] as? String ?? "waiting"
        groomerPhone = data["groomerPhone"] as? String
        notes = data["notes"] as? String ?? ""

        if let ts = data["startedAt"] as? Timestamp {
            startedAt = ts.dateValue()
        }

        if let ts = data["estimatedEndTime"] as? Timestamp {
            estimatedEndTime = ts.dateValue()
        }

        // Parse current step
        let currentStep = data["currentStep"] as? Int ?? 0
        currentStepIndex = currentStep

        // Update step states
        let completedSteps = data["completedSteps"] as? [Int] ?? []
        let stepTimestamps = data["stepTimestamps"] as? [String: Timestamp] ?? [:]

        for i in 0..<steps.count {
            steps[i].isCompleted = completedSteps.contains(i)
            steps[i].isActive = (i == currentStep)
            if let ts = stepTimestamps["\(i)"] {
                steps[i].completedAt = ts.dateValue()
            }
        }

        // Parse photos
        if let photoData = data["photos"] as? [[String: Any]] {
            photos = photoData.compactMap { dict in
                guard let url = dict["url"] as? String else { return nil }
                let id = dict["id"] as? String ?? UUID().uuidString
                let caption = dict["caption"] as? String ?? ""
                let type = dict["type"] as? String ?? "during"
                let ts = (dict["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                return GroomingPhoto(id: id, url: url, caption: caption, type: type, timestamp: ts)
            }
            .sorted { $0.timestamp > $1.timestamp }
        }

        // Parse health findings
        if let findingsData = data["healthFindings"] as? [[String: Any]] {
            healthFindings = findingsData.compactMap { dict in
                let id = dict["id"] as? String ?? UUID().uuidString
                let title = dict["title"] as? String ?? ""
                let description = dict["description"] as? String ?? ""
                let severity = dict["severity"] as? String ?? "low"
                let ts = (dict["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                return HealthFinding(id: id, title: title, description: description, severity: severity, timestamp: ts)
            }
        }

        // Estimate end time if not provided
        if estimatedEndTime == nil, let start = startedAt {
            let avgMinutesPerStep = 10.0
            let remainingSteps = steps.count - completedSteps.count
            estimatedEndTime = start.addingTimeInterval(Double(steps.count) * avgMinutesPerStep * 60)
            if remainingSteps > 0 {
                estimatedEndTime = Date().addingTimeInterval(Double(remainingSteps) * avgMinutesPerStep * 60)
            }
        }
    }
}
