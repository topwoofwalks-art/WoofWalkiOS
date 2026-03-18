import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct EventsScreen: View {
    @StateObject private var viewModel = EventsViewModel()
    @State private var selectedSegment = 0
    @State private var showCreateSheet = false

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedSegment) {
                Text("Upcoming").tag(0)
                Text("My Events").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                let events = selectedSegment == 0 ? viewModel.upcomingEvents : viewModel.myEvents
                if events.isEmpty {
                    emptyState
                } else {
                    List(events) { event in
                        EventRow(event: event)
                    }
                    .listStyle(.plain)
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button(action: { showCreateSheet = true }) {
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color(red: 0/255, green: 160/255, blue: 176/255)))
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
            }
            .padding(16)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 56))
                .foregroundColor(Color(red: 0/255, green: 160/255, blue: 176/255).opacity(0.3))

            Text("No Events")
                .font(.title3)
                .fontWeight(.semibold)

            Text(selectedSegment == 0
                 ? "No events scheduled nearby. Create one to meet fellow dog walkers!"
                 : "You haven't joined any events yet.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: { showCreateSheet = true }) {
                Label("Create Event", systemImage: "plus.circle.fill")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(Color(red: 0/255, green: 160/255, blue: 176/255))
                    )
            }
            .padding(.top, 8)

            Spacer()
        }
    }
}

struct EventItem: Identifiable {
    let id: String
    let title: String
    let description: String
    let organiserName: String
    let datetime: Date
    let locationName: String
    let attendeeCount: Int
    let maxAttendees: Int
    let photoUrl: String?
}

struct EventRow: View {
    let event: EventItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(event.title)
                    .font(.subheadline.bold())
                Spacer()
                if event.attendeeCount >= event.maxAttendees {
                    Text("Full")
                        .font(.caption2.bold())
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.orange.opacity(0.12)))
                }
            }

            if !event.description.isEmpty {
                Text(event.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 16) {
                Label {
                    Text(formatDate(event.datetime))
                        .font(.caption)
                } icon: {
                    Image(systemName: "calendar")
                        .font(.caption2)
                }

                Label {
                    Text(event.locationName)
                        .font(.caption)
                        .lineLimit(1)
                } icon: {
                    Image(systemName: "mappin")
                        .font(.caption2)
                }
            }
            .foregroundColor(.secondary)

            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.caption2)
                Text("\(event.attendeeCount)/\(event.maxAttendees) attending")
                    .font(.caption)

                Spacer()

                Text(event.organiserName)
                    .font(.caption)
                    .foregroundColor(Color(red: 0/255, green: 160/255, blue: 176/255))
            }
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM, HH:mm"
        return formatter.string(from: date)
    }
}

@MainActor
class EventsViewModel: ObservableObject {
    @Published var upcomingEvents: [EventItem] = []
    @Published var myEvents: [EventItem] = []
    @Published var isLoading = false

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private let currentUserId: String

    init() {
        currentUserId = Auth.auth().currentUser?.uid ?? ""
        loadEvents()
    }

    func loadEvents() {
        guard !currentUserId.isEmpty else { return }
        isLoading = true

        listener = db.collection("events")
            .whereField("datetime", isGreaterThan: Timestamp(date: Date()))
            .whereField("cancelled", isEqualTo: false)
            .order(by: "datetime")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    print("Events error: \(error.localizedDescription)")
                    return
                }
                let docs = snapshot?.documents ?? []
                let events: [EventItem] = docs.compactMap { doc in
                    let data = doc.data()
                    guard let title = data["title"] as? String,
                          let datetime = (data["datetime"] as? Timestamp)?.dateValue() else { return nil }
                    let attendees = data["attendees"] as? [String] ?? []
                    return EventItem(
                        id: doc.documentID,
                        title: title,
                        description: data["description"] as? String ?? "",
                        organiserName: data["creatorName"] as? String ?? "Unknown",
                        datetime: datetime,
                        locationName: data["locationName"] as? String ?? "",
                        attendeeCount: attendees.count,
                        maxAttendees: data["maxAttendees"] as? Int ?? 20,
                        photoUrl: data["photoUrl"] as? String
                    )
                }
                self.upcomingEvents = events
                self.myEvents = events.filter { _ in
                    docs.contains { doc in
                        let attendees = doc.data()["attendees"] as? [String] ?? []
                        return attendees.contains(self.currentUserId)
                    }
                }
            }
    }

    deinit { listener?.remove() }
}
