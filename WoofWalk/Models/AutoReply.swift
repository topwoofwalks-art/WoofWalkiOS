import Foundation

struct AutoReply: Codable {
    var enabled: Bool
    var message: String
    var autoReplyEnabled: Bool
    var activeFrom: String? // HH:mm
    var activeTo: String? // HH:mm

    init(enabled: Bool = false, message: String = "Thanks for your message! I'm currently away and will respond within 24 hours.", autoReplyEnabled: Bool = true, activeFrom: String? = nil, activeTo: String? = nil) {
        self.enabled = enabled; self.message = message; self.autoReplyEnabled = autoReplyEnabled; self.activeFrom = activeFrom; self.activeTo = activeTo
    }

    var isCurrentlyActive: Bool {
        guard enabled else { return false }
        guard let from = activeFrom, let to = activeTo else { return enabled }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let now = formatter.string(from: Date())

        if from <= to {
            return now >= from && now <= to
        } else {
            return now >= from || now <= to
        }
    }
}

struct HolidayMode: Codable {
    var enabled: Bool
    var startDate: Date?
    var endDate: Date?
    var message: String

    init(enabled: Bool = false, startDate: Date? = nil, endDate: Date? = nil, message: String = "") {
        self.enabled = enabled; self.startDate = startDate; self.endDate = endDate; self.message = message
    }

    var isCurrentlyActive: Bool {
        guard enabled else { return false }
        let now = Date()
        if let start = startDate, let end = endDate {
            return now >= start && now <= end
        }
        return enabled
    }
}

struct QuickReplyTemplate: Identifiable, Codable {
    let id: String
    var text: String
    var category: String

    init(id: String = UUID().uuidString, text: String, category: String = "General") {
        self.id = id; self.text = text; self.category = category
    }

    static let defaults: [QuickReplyTemplate] = [
        QuickReplyTemplate(id: "1", text: "Thanks for your message! I'll get back to you shortly.", category: "Acknowledgment"),
        QuickReplyTemplate(id: "2", text: "Your booking has been confirmed for the requested time.", category: "Booking"),
        QuickReplyTemplate(id: "3", text: "I'm on my way to pick up your dog now!", category: "Walk Updates"),
        QuickReplyTemplate(id: "4", text: "The walk is complete. Your pup had a great time!", category: "Walk Updates"),
        QuickReplyTemplate(id: "5", text: "Please let me know if you have any questions.", category: "General"),
        QuickReplyTemplate(id: "6", text: "I'll be there in about 5 minutes.", category: "Arrival"),
        QuickReplyTemplate(id: "7", text: "Running a few minutes late, apologies for the delay.", category: "Arrival"),
        QuickReplyTemplate(id: "8", text: "Here are some photos from today's walk!", category: "Walk Updates")
    ]
}
