import Foundation

struct BirthdayUtils {
    static func ageFromBirthdate(_ epochMs: Int64) -> Int {
        let birthdate = Date(timeIntervalSince1970: Double(epochMs) / 1000.0)
        let components = Calendar.current.dateComponents([.year], from: birthdate, to: Date())
        return components.year ?? 0
    }

    static func ageFromEpochDays(_ epochDays: Int) -> Int {
        let birthdate = Date(timeIntervalSince1970: TimeInterval(epochDays * 86400))
        let components = Calendar.current.dateComponents([.year], from: birthdate, to: Date())
        return components.year ?? 0
    }

    static func daysUntilBirthday(_ epochMs: Int64) -> Int? {
        let birthdate = Date(timeIntervalSince1970: Double(epochMs) / 1000.0)
        let calendar = Calendar.current
        let now = Date()

        var nextBirthday = calendar.dateComponents([.month, .day], from: birthdate)
        nextBirthday.year = calendar.component(.year, from: now)

        guard let nextDate = calendar.date(from: nextBirthday) else { return nil }

        let target = nextDate < now ? calendar.date(byAdding: .year, value: 1, to: nextDate)! : nextDate
        return calendar.dateComponents([.day], from: now, to: target).day
    }

    static func isBirthdayToday(_ epochMs: Int64) -> Bool {
        let birthdate = Date(timeIntervalSince1970: Double(epochMs) / 1000.0)
        let calendar = Calendar.current
        let now = Date()
        return calendar.isDate(birthdate, equalTo: now, toGranularity: .month) &&
               calendar.component(.day, from: birthdate) == calendar.component(.day, from: now)
    }

    static func formatAge(_ epochMs: Int64) -> String {
        let age = ageFromBirthdate(epochMs)
        if age == 0 {
            let months = Calendar.current.dateComponents([.month], from: Date(timeIntervalSince1970: Double(epochMs) / 1000.0), to: Date()).month ?? 0
            return months <= 1 ? "Puppy" : "\(months) months"
        }
        return age == 1 ? "1 year" : "\(age) years"
    }
}
