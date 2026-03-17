import Foundation

class MedicationSchedulerService {

    // MARK: - Category-specific default intervals (in days)

    static func defaultInterval(for category: String) -> Int {
        switch category {
        case "Flea & Tick": return 30
        case "Worming": return 90
        case "Heart": return 30
        case "Vaccination": return 365
        case "Joint Care": return 30
        case "Supplement": return 30
        default: return 30
        }
    }

    // MARK: - Frequency to days conversion

    static func frequencyToDays(_ frequency: String, customDays: Int? = nil) -> Int? {
        switch frequency {
        case "daily": return 1
        case "twice_daily": return 1
        case "weekly": return 7
        case "biweekly", "fortnightly": return 14
        case "monthly": return 30
        case "quarterly": return 90
        case "every_6_months": return 180
        case "yearly", "annually": return 365
        case "custom": return customDays
        case "as_needed": return nil
        default: return 30
        }
    }

    // MARK: - Default frequency for a category

    static func defaultFrequency(for category: String) -> String {
        switch category {
        case "Flea & Tick": return "monthly"
        case "Worming": return "quarterly"
        case "Heart": return "monthly"
        case "Vaccination": return "yearly"
        case "Joint Care": return "daily"
        case "Supplement": return "daily"
        case "Antibiotic": return "daily"
        case "Pain Relief": return "as_needed"
        default: return "daily"
        }
    }

    // MARK: - Late dose detection

    static func isLateDose(lastAdministered: Date?, frequency: Int) -> Bool {
        guard let lastDate = lastAdministered else { return false }
        let dueDate = Calendar.current.date(byAdding: .day, value: frequency, to: lastDate) ?? lastDate
        return Date() > dueDate
    }

    static func isLateDose(lastAdministeredMs: Int64?, frequency: Int) -> Bool {
        guard let ms = lastAdministeredMs else { return false }
        let lastDate = Date(timeIntervalSince1970: Double(ms) / 1000.0)
        return isLateDose(lastAdministered: lastDate, frequency: frequency)
    }

    // MARK: - Next due date calculation

    static func nextDueDate(lastAdministered: Date, frequency: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: frequency, to: lastAdministered) ?? lastAdministered
    }

    static func nextDueDateFromMs(_ lastAdministeredMs: Int64, frequency: Int) -> Date {
        let lastDate = Date(timeIntervalSince1970: Double(lastAdministeredMs) / 1000.0)
        return nextDueDate(lastAdministered: lastDate, frequency: frequency)
    }

    // MARK: - Days until next dose (negative = overdue)

    static func daysUntilDue(lastAdministeredMs: Int64?, frequency: Int) -> Int? {
        guard let ms = lastAdministeredMs else { return nil }
        let dueDate = nextDueDateFromMs(ms, frequency: frequency)
        return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: dueDate)).day
    }

    // MARK: - Days late

    static func daysLate(lastAdministeredMs: Int64?, frequency: Int) -> Int {
        guard let days = daysUntilDue(lastAdministeredMs: lastAdministeredMs, frequency: frequency) else { return 0 }
        return days < 0 ? abs(days) : 0
    }

    // MARK: - Late administration message

    static func lateMessage(for category: String, daysLate: Int) -> String {
        guard daysLate > 0 else { return "" }

        let urgency: String
        switch category {
        case "Flea & Tick":
            urgency = daysLate > 7 ? "Your dog may be unprotected against fleas and ticks." : "Administer soon to maintain protection."
        case "Worming":
            urgency = daysLate > 14 ? "Worming treatment is significantly overdue." : "Schedule worming treatment soon."
        case "Heart":
            urgency = "Heart medication should be given as soon as possible."
        case "Vaccination":
            urgency = daysLate > 30 ? "Vaccination is significantly overdue - contact your vet." : "Book a vaccination appointment soon."
        default:
            urgency = "Please administer as soon as possible."
        }

        return "\(daysLate) day\(daysLate == 1 ? "" : "s") overdue. \(urgency)"
    }

    // MARK: - Countdown label

    static func countdownLabel(lastAdministeredMs: Int64?, frequency: Int) -> String {
        guard let days = daysUntilDue(lastAdministeredMs: lastAdministeredMs, frequency: frequency) else {
            return "No date recorded"
        }
        if days < 0 {
            return "\(abs(days)) day\(abs(days) == 1 ? "" : "s") overdue"
        } else if days == 0 {
            return "Due today"
        } else if days == 1 {
            return "Due tomorrow"
        } else {
            return "Due in \(days) days"
        }
    }
}
