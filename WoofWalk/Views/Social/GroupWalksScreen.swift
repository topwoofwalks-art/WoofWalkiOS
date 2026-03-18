import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct GroupWalksScreen: View {
    @StateObject private var viewModel = GroupWalksViewModel()
    @State private var selectedSegment = 0
    @State private var showCreateSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Segment control: Upcoming / My Walks
            Picker("", selection: $selectedSegment) {
                Text("Upcoming").tag(0)
                Text("My Walks").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                let walks = selectedSegment == 0 ? viewModel.upcomingWalks : viewModel.myWalks
                if walks.isEmpty {
                    emptyState
                } else {
                    List(walks) { walk in
                        GroupWalkRow(walk: walk)
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

            Image(systemName: "figure.walk")
                .font(.system(size: 56))
                .foregroundColor(Color(red: 0/255, green: 160/255, blue: 176/255).opacity(0.3))

            Text("No Group Walks")
                .font(.title3)
                .fontWeight(.semibold)

            Text(selectedSegment == 0
                 ? "No group walks scheduled nearby. Be the first to organise one!"
                 : "You haven't joined any group walks yet.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: { showCreateSheet = true }) {
                Label("Create Group Walk", systemImage: "plus.circle.fill")
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

struct GroupWalkItem: Identifiable {
    let id: String
    let title: String
    let organiserName: String
    let datetime: Date
    let locationName: String
    let attendeeCount: Int
    let maxAttendees: Int
    let difficulty: String
    let distanceKm: Double
}

struct GroupWalkRow: View {
    let walk: GroupWalkItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(walk.title)
                    .font(.subheadline.bold())
                Spacer()
                difficultyBadge
            }

            HStack(spacing: 4) {
                Image(systemName: "person.fill")
                    .font(.caption2)
                Text(walk.organiserName)
                    .font(.caption)
            }
            .foregroundColor(.secondary)

            HStack(spacing: 16) {
                Label {
                    Text(formatDate(walk.datetime))
                        .font(.caption)
                } icon: {
                    Image(systemName: "calendar")
                        .font(.caption2)
                }

                Label {
                    Text(walk.locationName)
                        .font(.caption)
                        .lineLimit(1)
                } icon: {
                    Image(systemName: "mappin")
                        .font(.caption2)
                }
            }
            .foregroundColor(.secondary)

            HStack(spacing: 16) {
                Label {
                    Text(String(format: "%.1f km", walk.distanceKm))
                        .font(.caption)
                } icon: {
                    Image(systemName: "figure.walk")
                        .font(.caption2)
                }

                Label {
                    Text("\(walk.attendeeCount)/\(walk.maxAttendees)")
                        .font(.caption)
                } icon: {
                    Image(systemName: "person.2.fill")
                        .font(.caption2)
                }
                .foregroundColor(walk.attendeeCount >= walk.maxAttendees
                                 ? .orange : Color(red: 0/255, green: 160/255, blue: 176/255))
            }
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var difficultyBadge: some View {
        let color: Color = {
            switch walk.difficulty.uppercased() {
            case "EASY": return .green
            case "MODERATE": return .orange
            case "HARD": return .red
            default: return .gray
            }
        }()

        return Text(walk.difficulty.capitalized)
            .font(.caption2.bold())
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(color.opacity(0.12))
            )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM, HH:mm"
        return formatter.string(from: date)
    }
}

@MainActor
class GroupWalksViewModel: ObservableObject {
    @Published var upcomingWalks: [GroupWalkItem] = []
    @Published var myWalks: [GroupWalkItem] = []
    @Published var isLoading = false

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private let currentUserId: String

    init() {
        currentUserId = Auth.auth().currentUser?.uid ?? ""
        loadGroupWalks()
    }

    func loadGroupWalks() {
        guard !currentUserId.isEmpty else { return }
        isLoading = true

        listener = db.collection("groupWalks")
            .whereField("datetime", isGreaterThan: Timestamp(date: Date()))
            .order(by: "datetime")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    print("Group walks error: \(error.localizedDescription)")
                    return
                }
                let docs = snapshot?.documents ?? []
                let walks: [GroupWalkItem] = docs.compactMap { doc in
                    let data = doc.data()
                    guard let title = data["title"] as? String,
                          let datetime = (data["datetime"] as? Timestamp)?.dateValue() else { return nil }
                    return GroupWalkItem(
                        id: doc.documentID,
                        title: title,
                        organiserName: data["creatorName"] as? String ?? "Unknown",
                        datetime: datetime,
                        locationName: data["locationName"] as? String ?? "",
                        attendeeCount: (data["attendees"] as? [String])?.count ?? 0,
                        maxAttendees: data["maxAttendees"] as? Int ?? 20,
                        difficulty: data["difficulty"] as? String ?? "EASY",
                        distanceKm: data["distanceKm"] as? Double ?? 0.0
                    )
                }
                self.upcomingWalks = walks
                self.myWalks = walks.filter { _ in
                    // Filter for walks the user has joined
                    docs.contains { doc in
                        let attendees = doc.data()["attendees"] as? [String] ?? []
                        return attendees.contains(self.currentUserId)
                    }
                }
            }
    }

    deinit { listener?.remove() }
}
