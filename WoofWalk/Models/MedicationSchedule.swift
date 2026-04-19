import Foundation
import FirebaseFirestore

/// Active medication schedule for a dog, stored in
/// `/dogs/{dogId}/medicationSchedules/{scheduleId}`.
///
/// Administration events are logged as MedicalRecord entries with
/// `type == .medicationLog` so the medical audit trail stays unified.
struct MedicationSchedule: Identifiable, Codable {
    @DocumentID var id: String?
    var dogId: String
    var name: String
    var category: String
    var dosage: String
    var dosageUnit: String
    var frequency: String                   // daily | weekly | monthly | custom | ...
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
    var createdAt: Int64
    var updatedAt: Int64

    init(
        id: String? = nil,
        dogId: String = "",
        name: String = "",
        category: String = "",
        dosage: String = "",
        dosageUnit: String = "",
        frequency: String = "daily",
        customFrequencyDays: Int? = nil,
        timeOfDay: [String] = [],
        withFood: Bool = false,
        prescribedBy: String = "",
        pharmacy: String = "",
        startDate: Int64? = nil,
        endDate: Int64? = nil,
        nextDueDate: Int64? = nil,
        lastAdministered: Int64? = nil,
        notes: String = "",
        isActive: Bool = true,
        remindersEnabled: Bool = false,
        createdAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        updatedAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) {
        self.id = id
        self.dogId = dogId
        self.name = name
        self.category = category
        self.dosage = dosage
        self.dosageUnit = dosageUnit
        self.frequency = frequency
        self.customFrequencyDays = customFrequencyDays
        self.timeOfDay = timeOfDay
        self.withFood = withFood
        self.prescribedBy = prescribedBy
        self.pharmacy = pharmacy
        self.startDate = startDate
        self.endDate = endDate
        self.nextDueDate = nextDueDate
        self.lastAdministered = lastAdministered
        self.notes = notes
        self.isActive = isActive
        self.remindersEnabled = remindersEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// True if this medication's next dose is overdue as of now.
    var isOverdue: Bool {
        guard let due = nextDueDate, isActive else { return false }
        return due < Int64(Date().timeIntervalSince1970 * 1000)
    }

    /// Compute the next-due timestamp given an administration time.
    /// Returns nil if the frequency isn't recurring (e.g. `as_needed`).
    func calculateNextDueDate(administeredAt: Int64, isLateAdministration: Bool = false) -> Int64? {
        let day: Int64 = 24 * 60 * 60 * 1000
        let intervalMs: Int64
        switch frequency.lowercased() {
        case "daily": intervalMs = day
        case "weekly": intervalMs = 7 * day
        case "monthly": intervalMs = 30 * day
        case "custom":
            guard let days = customFrequencyDays else { return nil }
            intervalMs = Int64(days) * day
        default: return nil
        }
        // When a dose is late, reschedule from the administration time
        // (not the original due time) so the next reminder isn't also late.
        let base = isLateAdministration ? administeredAt : (nextDueDate ?? administeredAt)
        return base + intervalMs
    }
}
