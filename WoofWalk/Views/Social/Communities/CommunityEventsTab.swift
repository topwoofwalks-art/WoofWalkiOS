import SwiftUI

/// Events tab — list of upcoming community events. Tapping the attend row
/// toggles the user in/out of the attendee list (transactional). The
/// "Create Event" entry is reserved for moderators+ in the same screen,
/// matching Android's behaviour.
struct CommunityEventsTab: View {
    @ObservedObject var viewModel: CommunityDetailViewModel

    var body: some View {
        VStack(spacing: 12) {
            if viewModel.events.isEmpty {
                emptyState
            } else {
                ForEach(viewModel.events) { event in
                    EventCard(event: event, currentUserId: viewModel.currentUserId) {
                        if let id = event.id {
                            Task { await viewModel.toggleEventAttendance(id) }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .padding(.vertical, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.4))
            Text("No upcoming events")
                .font(.headline)
            Text("Check back later — moderators can schedule group walks and meetups.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

private struct EventCard: View {
    let event: CommunityEvent
    let currentUserId: String?
    let onAttend: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                dateBlock
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.headline)
                    Text(event.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                    if !event.locationName.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(event.locationName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Spacer()
            }

            HStack {
                Label(
                    "\(event.attendeeCount)\(event.maxAttendees.map { " / \($0)" } ?? "") going",
                    systemImage: "person.3.fill"
                )
                .font(.caption)
                .foregroundColor(.secondary)

                Spacer()

                Button(action: onAttend) {
                    Text(isAttending ? "Going" : (event.isFull ? "Full" : "Attend"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(buttonForeground)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(buttonBackground)
                        .clipShape(Capsule())
                }
                .disabled(event.isFull && !isAttending)
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var isAttending: Bool {
        guard let uid = currentUserId else { return false }
        return event.isAttending(uid)
    }

    private var buttonBackground: Color {
        if isAttending { return Color.green.opacity(0.18) }
        if event.isFull { return Color.secondary.opacity(0.15) }
        return Color.accentColor
    }

    private var buttonForeground: Color {
        if isAttending { return .green }
        if event.isFull { return .secondary }
        return .white
    }

    private var dateBlock: some View {
        let date = event.startDate
        let day = Calendar.current.component(.day, from: date)
        let month = Calendar.current.shortMonthSymbols[max(0, Calendar.current.component(.month, from: date) - 1)].uppercased()
        return VStack(spacing: 0) {
            Text(month)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .frame(maxWidth: .infinity)
                .background(Color.accentColor)
            Text("\(day)")
                .font(.title3)
                .fontWeight(.bold)
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground))
            Text(timeStr(date))
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground))
        }
        .frame(width: 56)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func timeStr(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
