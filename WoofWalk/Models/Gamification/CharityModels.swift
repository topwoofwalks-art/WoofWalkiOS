import Foundation
import FirebaseFirestore

struct CharityOrg: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let logoEmoji: String

    init(id: String, name: String, description: String, logoEmoji: String) {
        self.id = id; self.name = name; self.description = description; self.logoEmoji = logoEmoji
    }

    static let supportedCharities: [CharityOrg] = [
        CharityOrg(id: "dogs_trust", name: "Dogs Trust", description: "UK's largest dog welfare charity", logoEmoji: "🐕"),
        CharityOrg(id: "battersea", name: "Battersea Dogs & Cats Home", description: "Rescuing and rehoming animals since 1860", logoEmoji: "🏠"),
        CharityOrg(id: "rspca", name: "RSPCA", description: "Preventing cruelty and promoting kindness to animals", logoEmoji: "🐾"),
        CharityOrg(id: "blue_cross", name: "Blue Cross", description: "Helping sick, injured and homeless pets", logoEmoji: "💙"),
        CharityOrg(id: "kennel_club", name: "The Kennel Club Charitable Trust", description: "Supporting dog health and welfare", logoEmoji: "🏅")
    ]
}

struct CharityProfile: Codable {
    var enabled: Bool
    var selectedCharityId: String
    var lifetimePoints: Int64
    var monthlyPoints: Int64
    var lastWalkCharityPoints: Int64

    init(enabled: Bool = false, selectedCharityId: String = "dogs_trust", lifetimePoints: Int64 = 0, monthlyPoints: Int64 = 0, lastWalkCharityPoints: Int64 = 0) {
        self.enabled = enabled; self.selectedCharityId = selectedCharityId; self.lifetimePoints = lifetimePoints; self.monthlyPoints = monthlyPoints; self.lastWalkCharityPoints = lastWalkCharityPoints
    }

    var selectedCharity: CharityOrg? {
        CharityOrg.supportedCharities.first { $0.id == selectedCharityId }
    }
}
