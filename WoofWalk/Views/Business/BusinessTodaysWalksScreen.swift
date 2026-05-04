import SwiftUI

/// "Today's walking jobs" — entry point list the walker taps to launch
/// the Walk Console for a specific booking. Mirrors the Android entry
/// point on `WalkConsoleScreen`: pick a booking, hit it, console opens.
///
/// The schedule screen already shows the same booking list across all
/// service types. This screen filters to walking-only and routes
/// straight to the Walk Console — saves the walker two taps when
/// they're heading out for the next visit.
struct BusinessTodaysWalksScreen: View {
    @ObservedObject var viewModel: BusinessViewModel
    @Environment(\.colorScheme) private var colorScheme

    private var todaysWalks: [BusinessBooking] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: Date())
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        return viewModel.allBookings.filter { booking in
            let isWalking = booking.serviceType.lowercased().contains("walk")
            let isToday = booking.scheduledDate >= dayStart && booking.scheduledDate < dayEnd
            return isWalking && isToday
        }
        .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    var body: some View {
        Group {
            if todaysWalks.isEmpty {
                emptyState
            } else {
                List(todaysWalks) { booking in
                    NavigationLink(value: AppRoute.businessWalkConsole(bookingId: booking.id)) {
                        bookingRow(booking)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Today's Walks")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.walk")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            Text("No walks scheduled for today")
                .font(.headline)
            Text("Walks will appear here once a client confirms a booking.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func bookingRow(_ booking: BusinessBooking) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(booking.timeRangeString)
                    .font(.subheadline.bold())
                Spacer()
                Text(booking.statusEnum.displayName)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(booking.statusEnum.color.opacity(0.2))
                    .foregroundColor(booking.statusEnum.color)
                    .clipShape(Capsule())
            }
            Text(booking.displayTitle)
                .font(.body)
            Text(booking.location)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            if let dog = booking.dogName {
                HStack(spacing: 4) {
                    Image(systemName: "pawprint.fill")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    Text(dog)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        BusinessTodaysWalksScreen(viewModel: BusinessViewModel())
    }
}
