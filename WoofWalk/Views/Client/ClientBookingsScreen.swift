import SwiftUI

struct ClientBookingsScreen: View {
    @State private var selectedTab: BookingTab = .upcoming

    var body: some View {
        VStack(spacing: 0) {
            // Segmented picker
            Picker("Bookings", selection: $selectedTab) {
                ForEach(BookingTab.allCases, id: \.self) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Content
            switch selectedTab {
            case .upcoming:
                BookingsEmptyState(
                    icon: "calendar.badge.clock",
                    title: "No upcoming bookings",
                    message: "When you book a walk, it will appear here.",
                    actionTitle: "Find a Walker",
                    color: .blue
                )
            case .past:
                BookingsEmptyState(
                    icon: "clock.arrow.circlepath",
                    title: "No past bookings",
                    message: "Your completed walks will appear here.",
                    actionTitle: nil,
                    color: .gray
                )
            case .cancelled:
                BookingsEmptyState(
                    icon: "xmark.circle",
                    title: "No cancelled bookings",
                    message: "Any cancelled bookings will appear here.",
                    actionTitle: nil,
                    color: .gray
                )
            }
        }
        .navigationTitle("Bookings")
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Booking Tab

enum BookingTab: String, CaseIterable {
    case upcoming
    case past
    case cancelled

    var title: String {
        switch self {
        case .upcoming: return "Upcoming"
        case .past: return "Past"
        case .cancelled: return "Cancelled"
        }
    }
}

// MARK: - Empty State

private struct BookingsEmptyState: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let color: Color

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(color)
            }

            Text(title)
                .font(.title3.bold())

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if let actionTitle {
                Button {
                    // Navigate to discovery
                } label: {
                    Text(actionTitle)
                        .font(.subheadline.bold())
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.blue))
                        .foregroundColor(.white)
                }
                .padding(.top, 8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        ClientBookingsScreen()
    }
}
