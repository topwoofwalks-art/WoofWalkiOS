import Foundation

struct PendingMessage: Codable, Identifiable {
    let id: String
    let chatId: String
    let text: String
    let imageData: Data?
    let createdAt: Date
    var status: MessageStatus
    var retryCount: Int

    enum MessageStatus: String, Codable {
        case pending, sending, failed
    }

    init(chatId: String, text: String, imageData: Data? = nil) {
        self.id = UUID().uuidString
        self.chatId = chatId
        self.text = text
        self.imageData = imageData
        self.createdAt = Date()
        self.status = .pending
        self.retryCount = 0
    }
}

@MainActor
class OfflineMessageQueue: ObservableObject {
    static let shared = OfflineMessageQueue()

    @Published var pendingMessages: [PendingMessage] = []

    private let storageKey = "offline_message_queue"

    init() { load() }

    func enqueue(_ message: PendingMessage) {
        pendingMessages.append(message)
        save()
    }

    func markSending(_ id: String) {
        if let idx = pendingMessages.firstIndex(where: { $0.id == id }) {
            pendingMessages[idx].status = .sending
            save()
        }
    }

    func markFailed(_ id: String) {
        if let idx = pendingMessages.firstIndex(where: { $0.id == id }) {
            pendingMessages[idx].status = .failed
            pendingMessages[idx].retryCount += 1
            save()
        }
    }

    func remove(_ id: String) {
        pendingMessages.removeAll { $0.id == id }
        save()
    }

    func retryFailed() {
        for i in pendingMessages.indices where pendingMessages[i].status == .failed {
            pendingMessages[i].status = .pending
        }
        save()
    }

    var hasPending: Bool { !pendingMessages.filter { $0.status == .pending }.isEmpty }

    private func save() {
        if let data = try? JSONEncoder().encode(pendingMessages) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let messages = try? JSONDecoder().decode([PendingMessage].self, from: data) {
            pendingMessages = messages
        }
    }
}
