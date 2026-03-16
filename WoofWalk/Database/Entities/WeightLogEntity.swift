import SwiftData
import Foundation

@Model
final class WeightLogEntity {
    var dogId: String
    var loggedAt: Date
    var weightKg: Double

    init(dogId: String, loggedAt: Date, weightKg: Double) {
        self.dogId = dogId
        self.loggedAt = loggedAt
        self.weightKg = weightKg
    }
}
