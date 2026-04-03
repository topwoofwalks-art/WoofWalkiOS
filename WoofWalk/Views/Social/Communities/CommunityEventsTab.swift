import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct CommunityEventsTab: View {
    let communityId: String
    @StateObject private var viewModel: CommunityEventsViewModel

    private let brandColor = Color(red: 0/255, green: 160/255, blue: 176/255)

    init(communityId: String) {
        self.communityId = communityId
        _viewModel = StateObject(wrappedValue: CommunityEventsViewModel(communityId: communityId))
    }

    var body: some View {
        if viewModel.isLoading && viewModel.events.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.events.isEmpty {
            eventsEmptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.events) { event in
                        CommunityEventCard(event: event, brandColor: brandColor)
                    }
                }
                .padding(16)
            }
        }
    }

    private var eventsEmptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.3))
            Text("No Events")
                .font(.title3.bold())
            Text("No community events have been scheduled yet.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
}

// MARK: - Model

struct CommunityEvent: Identifiable {
    let id: String
    let title: String
    let description: String
    let datetime: Date
    let locationName: String
    let attendeeCount: Int
    let maxAttendees: Int
    let organizerName: String
}

// MARK: - Event Card

private struct CommunityEventCard: View {
    let event: CommunityEvent
    let brandColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Date badge + Title
            HStack(alignment: .top, spacing: 12) {
                // Date badge
                VStack(spacing: 0) {
                    Text(monthAbbrev(event.datetime))
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 2)
                        .background(brandColor)

                    Text(dayString(event.datetime))
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .frame(width: 48)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.subheadline.bold())

                    if !event.description.isEmpty {
                        Text(event.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()
            }

            // Details
            HStack(spacing: 16) {
                Label {
                    Text(formatTime(event.datetime))
                        .font(.caption)
                } icon: {
                    Image(systemName: "clock")
                        .font(.caption2)
                }

                if !event.locationName.isEmpty {
                    Label {
                        Text(event.locationName)
                            .font(.caption)
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: "mappin")
                            .font(.caption2)
                    }
                }
            }
            .foregroundColor(.secondary)

            // Footer
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption2)
                    Text("\(event.attendeeCount)/\(event.maxAttendees) attending")
                        .font(.caption)
                }
                .foregroundColor(event.attendeeCount >= event.maxAttendees ? .orange : .secondary)

                Spacer()

                Text(event.organizerName)
                    .font(.caption)
                    .foregroundColor(brandColor)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        )
    }

    private func monthAbbrev(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date).uppercased()
    }

    private func dayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - ViewModel

@MainActor
class CommunityEventsViewModel: ObservableObject {
    @Published var events: [CommunityEvent] = []
    @Published var isLoading = false

    private let communityId: String
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    init(communityId: String) {
        self.communityId = communityId
        loadEvents()
    }

    func loadEvents() {
        isLoading = true
        listener = db.collection("communities").document(communityId)
            .collection("events")
            .whereField("datetime", isGreaterThan: Timestamp(date: Date()))
            .order(by: "datetime")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    print("Community events error: \(error.localizedDescription)")
                    return
                }
                self.events = (snapshot?.documents ?? []).compactMap { doc in
                    let data = doc.data()
                    guard let title = data["title"] as? String,
                          let datetime = (data["datetime"] as? Timestamp)?.dateValue() else { return nil }
                    let attendees = data["attendees"] as? [String] ?? []
                    return CommunityEvent(
                        id: doc.documentID,
                        title: title,
                        description: data["description"] as? String ?? "",
                        datetime: datetime,
                        locationName: data["locationName"] as? String ?? "",
                        attendeeCount: attendees.count,
                        maxAttendees: data["maxAttendees"] as? Int ?? 50,
                        organizerName: data["organizerName"] as? String ?? "Unknown"
                    )
                }
            }
    }

    deinit { listener?.remove() }
}
