import Foundation
import FirebaseFirestore

struct ClientPack: Identifiable, Codable {
    @DocumentID var id: String?
    var orgId: String = ""
    var discountId: String = ""
    var serviceType: String = ""
    var totalSessions: Int = 0
    var usedSessions: Int = 0
    var purchasedAt: Timestamp?
    var expiresAt: Timestamp?
    var pricePerSession: Double = 0

    var remainingSessions: Int { totalSessions - usedSessions }
    var isExpired: Bool {
        guard let exp = expiresAt else { return false }
        return Timestamp().seconds > exp.seconds
    }
    var isUsable: Bool { remainingSessions > 0 && !isExpired }
}
