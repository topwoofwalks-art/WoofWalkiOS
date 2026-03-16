import Foundation

struct AutoReply: Codable {
    var enabled: Bool
    var message: String
    var activeFrom: String? // HH:mm
    var activeTo: String? // HH:mm

    init(enabled: Bool = false, message: String = "Thanks for your message! I'll get back to you shortly.", activeFrom: String? = nil, activeTo: String? = nil) {
        self.enabled = enabled; self.message = message; self.activeFrom = activeFrom; self.activeTo = activeTo
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
