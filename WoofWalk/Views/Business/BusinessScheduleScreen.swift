import SwiftUI

struct BusinessScheduleScreen: View {
    @State private var selectedDate: Date = Date()
    @State private var selectedTab: ScheduleTab = .upcoming

    private enum ScheduleTab: String, CaseIterable {
        case upcoming = "Upcoming"
        case past = "Past"
        case cancelled = "Cancelled"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Date picker
            DatePicker(
                "Select Date",
                selection: $selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding(.horizontal)

            // Tab selector
            Picker("Filter", selection: $selectedTab) {
                ForEach(ScheduleTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Bookings list
            bookingsList
        }
        .navigationTitle("Schedule")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    // Add booking
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    // MARK: - Bookings List

    private var bookingsList: some View {
        ScrollView {
            if sampleBookings.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(sampleBookings) { booking in
                        bookingCard(booking)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func bookingCard(_ booking: ScheduleBooking) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "pawprint.fill")
                    .foregroundColor(.accentColor)
                Text(booking.dogName)
                    .font(.headline)
                Spacer()
                Text(booking.status)
                    .font(.caption.bold())
                    .foregroundColor(statusColor(booking.status))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(statusColor(booking.status).opacity(0.1))
                    .cornerRadius(8)
            }

            HStack {
                Image(systemName: "person.fill")
                    .foregroundColor(.secondary)
                    .font(.caption)
                Text(booking.ownerName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
                    .font(.caption)
                Text(booking.timeSlot)
                    .font(.subheadline)
                Spacer()
                Image(systemName: "sterlingsign.circle")
                    .foregroundColor(.secondary)
                    .font(.caption)
                Text(booking.price)
                    .font(.subheadline.bold())
            }

            if !booking.notes.isEmpty {
                HStack(alignment: .top) {
                    Image(systemName: "note.text")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text(booking.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Bookings")
                .font(.headline)
            Text("You don't have any \(selectedTab.rawValue.lowercased()) bookings for this date.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 60)
    }

    // MARK: - Helpers

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "Confirmed": return .green
        case "Pending": return .orange
        case "Cancelled": return .red
        default: return .gray
        }
    }

    private var sampleBookings: [ScheduleBooking] {
        switch selectedTab {
        case .upcoming:
            return [
                ScheduleBooking(id: "1", dogName: "Bella", ownerName: "Sarah Thompson", timeSlot: "9:00 - 10:00 AM", price: "£15.00", status: "Confirmed", notes: "Bella needs her harness, not collar"),
                ScheduleBooking(id: "2", dogName: "Max", ownerName: "Tom Wilson", timeSlot: "11:00 - 12:00 PM", price: "£15.00", status: "Pending", notes: ""),
                ScheduleBooking(id: "3", dogName: "Luna & Daisy", ownerName: "Emma Clarke", timeSlot: "2:00 - 3:30 PM", price: "£22.50", status: "Confirmed", notes: "Group walk, both on leads please"),
            ]
        case .past:
            return [
                ScheduleBooking(id: "4", dogName: "Rocky", ownerName: "James Miller", timeSlot: "9:00 - 10:00 AM", price: "£15.00", status: "Completed", notes: ""),
            ]
        case .cancelled:
            return []
        }
    }
}

// MARK: - Schedule Booking Model

private struct ScheduleBooking: Identifiable {
    let id: String
    let dogName: String
    let ownerName: String
    let timeSlot: String
    let price: String
    let status: String
    let notes: String
}
