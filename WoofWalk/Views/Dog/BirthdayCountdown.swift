import SwiftUI

struct BirthdayCountdown: View {
    let birthdateString: String
    let dogName: String

    private var daysUntil: Int? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: birthdateString) else { return nil }
        let epochMs = Int64(date.timeIntervalSince1970 * 1000)
        return BirthdayUtils.daysUntilBirthday(epochMs)
    }

    private var isBirthday: Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: birthdateString) else { return false }
        let epochMs = Int64(date.timeIntervalSince1970 * 1000)
        return BirthdayUtils.isBirthdayToday(epochMs)
    }

    var body: some View {
        if isBirthday {
            HStack {
                Text("\u{1F382}")
                    .font(.title)
                VStack(alignment: .leading) {
                    Text("Happy Birthday, \(dogName)!")
                        .font(.headline)
                    Text("Celebrating today!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\u{1F389}").font(.title)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: [Color.pink.opacity(0.15), Color.purple.opacity(0.1)], startPoint: .leading, endPoint: .trailing))
            )
        } else if let days = daysUntil, days <= 30 {
            HStack {
                Text("\u{1F382}").font(.title2)
                VStack(alignment: .leading) {
                    Text("\(dogName)'s Birthday")
                        .font(.subheadline.bold())
                    Text(days == 1 ? "Tomorrow!" : "In \(days) days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.purple.opacity(0.05)))
        }
    }
}
