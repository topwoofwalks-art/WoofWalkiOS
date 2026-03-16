import Foundation

struct MedicationScheduleEntry: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var category: String
    var dosage: String
    var dosageUnit: String
    var frequency: String // daily, twice_daily, weekly, biweekly, fortnightly, monthly, quarterly, every_6_months, yearly, annually, as_needed, custom
    var customFrequencyDays: Int?
    var timeOfDay: [String]
    var withFood: Bool
    var prescribedBy: String
    var pharmacy: String
    var startDate: Int64?
    var endDate: Int64?
    var nextDueDate: Int64?
    var lastAdministered: Int64?
    var notes: String
    var isActive: Bool
    var remindersEnabled: Bool
    var createdAt: Int64?
    var updatedAt: Int64?

    init(id: String = UUID().uuidString, name: String = "", category: String = "", dosage: String = "", dosageUnit: String = "mg", frequency: String = "daily", customFrequencyDays: Int? = nil, timeOfDay: [String] = ["morning"], withFood: Bool = false, prescribedBy: String = "", pharmacy: String = "", startDate: Int64? = nil, endDate: Int64? = nil, nextDueDate: Int64? = nil, lastAdministered: Int64? = nil, notes: String = "", isActive: Bool = true, remindersEnabled: Bool = true, createdAt: Int64? = nil, updatedAt: Int64? = nil) {
        self.id = id; self.name = name; self.category = category; self.dosage = dosage; self.dosageUnit = dosageUnit; self.frequency = frequency; self.customFrequencyDays = customFrequencyDays; self.timeOfDay = timeOfDay; self.withFood = withFood; self.prescribedBy = prescribedBy; self.pharmacy = pharmacy; self.startDate = startDate; self.endDate = endDate; self.nextDueDate = nextDueDate; self.lastAdministered = lastAdministered; self.notes = notes; self.isActive = isActive; self.remindersEnabled = remindersEnabled; self.createdAt = createdAt; self.updatedAt = updatedAt
    }

    static let frequencyOptions = ["daily", "twice_daily", "weekly", "biweekly", "fortnightly", "monthly", "quarterly", "every_6_months", "yearly", "annually", "as_needed", "custom"]

    static let categoryOptions = ["Flea & Tick", "Worming", "Joint Care", "Heart", "Anxiety", "Allergy", "Pain Relief", "Antibiotic", "Supplement", "Other"]
}
