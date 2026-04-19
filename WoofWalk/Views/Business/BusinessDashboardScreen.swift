import SwiftUI

struct BusinessDashboardScreen: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Today's stats
                VStack(alignment: .leading, spacing: 12) {
                    Text("Today")
                        .font(.title2.bold())

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        DashboardStat(title: "Walks", value: "0", icon: "figure.walk", color: .blue)
                        DashboardStat(title: "Earnings", value: CurrencyFormatter.shared.formatPrice(0), icon: "sterlingsign.circle", color: .green)
                        DashboardStat(title: "Clients", value: "0", icon: "person.2", color: .purple)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)

                // Upcoming walks section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Upcoming Walks")
                        .font(.headline)

                    HStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("No upcoming walks scheduled")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
                }
                .padding()

                // Recent activity
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Activity")
                        .font(.headline)

                    ForEach(0..<3, id: \.self) { _ in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "pawprint.fill")
                                        .foregroundColor(.gray)
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.15))
                                    .frame(width: 120, height: 14)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(width: 80, height: 12)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }

                    Text("Activity will appear here once you start walking")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
                .padding()

                // Quick actions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Actions")
                        .font(.headline)

                    HStack(spacing: 12) {
                        QuickActionButton(title: "New Walk", icon: "plus.circle.fill", color: .blue)
                        QuickActionButton(title: "Messages", icon: "message.fill", color: .green)
                        QuickActionButton(title: "Schedule", icon: "calendar", color: .orange)
                    }
                }
                .padding()

                // This week summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("This Week")
                        .font(.headline)

                    HStack(spacing: 0) {
                        WeekDayBar(day: "M", height: 0.2, isToday: false)
                        WeekDayBar(day: "T", height: 0.4, isToday: false)
                        WeekDayBar(day: "W", height: 0.6, isToday: false)
                        WeekDayBar(day: "T", height: 0.3, isToday: false)
                        WeekDayBar(day: "F", height: 0.0, isToday: true)
                        WeekDayBar(day: "S", height: 0.0, isToday: false)
                        WeekDayBar(day: "S", height: 0.0, isToday: false)
                    }
                    .frame(height: 80)
                    .padding(.vertical, 8)

                    HStack {
                        Label("0 walks completed", systemImage: "checkmark.circle")
                        Spacer()
                        Label("\(CurrencyFormatter.shared.formatPrice(0)) earned", systemImage: "sterlingsign.circle")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            }
            .padding()
        }
        .navigationTitle("Dashboard")
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Supporting Views

struct DashboardStat: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(value)
                .font(.title3.bold())
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.1)))
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

struct WeekDayBar: View {
    let day: String
    let height: CGFloat
    let isToday: Bool

    var body: some View {
        VStack(spacing: 4) {
            Spacer()
            RoundedRectangle(cornerRadius: 4)
                .fill(isToday ? Color.blue : Color.blue.opacity(0.3))
                .frame(height: max(4, height * 60))
            Text(day)
                .font(.caption2)
                .foregroundColor(isToday ? .blue : .secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        BusinessDashboardScreen()
    }
}
