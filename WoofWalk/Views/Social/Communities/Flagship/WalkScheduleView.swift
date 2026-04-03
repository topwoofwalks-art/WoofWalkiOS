import SwiftUI
import MapKit
import FirebaseAuth
import FirebaseFirestore

// MARK: - View Model

@MainActor
class WalkScheduleViewModel: ObservableObject {
    @Published var schedules: [WalkSchedule] = []
    @Published var selectedDay: Date = Date()
    @Published var weekDates: [Date] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showCreateSheet = false
    @Published var selectedSchedule: WalkSchedule?

    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    let communityId: String

    init(communityId: String) {
        self.communityId = communityId
        calculateWeekDates()
    }

    var currentUserId: String? { auth.currentUser?.uid }

    var filteredSchedules: [WalkSchedule] {
        let calendar = Calendar.current
        return schedules.filter { schedule in
            let scheduleDate = Date(timeIntervalSince1970: schedule.startTime / 1000)
            return calendar.isDate(scheduleDate, inSameDayAs: selectedDay)
        }
        .sorted { $0.startTime < $1.startTime }
    }

    func calculateWeekDates() {
        let calendar = Calendar.current
        let today = Date()
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else { return }
        weekDates = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    func navigateWeek(forward: Bool) {
        let calendar = Calendar.current
        if let first = weekDates.first,
           let newStart = calendar.date(byAdding: .day, value: forward ? 7 : -7, to: first) {
            weekDates = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: newStart) }
            selectedDay = weekDates.first ?? Date()
        }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let snapshot = try await db.collection("communities").document(communityId)
                .collection("posts")
                .whereField("type", isEqualTo: CommunityPostType.WALK_SCHEDULE.rawValue)
                .whereField("isDeleted", isEqualTo: false)
                .limit(to: 50)
                .getDocuments()

            let posts = snapshot.documents.compactMap { try? $0.data(as: CommunityPost.self) }
            schedules = posts.compactMap { post -> WalkSchedule? in
                guard let meta = post.metadata else { return nil }
                let startTime = Double(meta["startTime"] ?? "0") ?? post.createdAt
                return WalkSchedule(
                    id: post.id,
                    communityId: communityId,
                    postId: post.id ?? "",
                    title: post.title,
                    description: post.content,
                    createdBy: post.authorId,
                    creatorName: post.authorName,
                    startTime: startTime,
                    meetingPointName: meta["meetingPoint"] ?? "",
                    difficulty: meta["difficulty"] ?? "EASY",
                    participantIds: post.likedBy, // reuse likedBy as participant list
                    createdAt: post.createdAt
                )
            }
            isLoading = false
        } catch {
            errorMessage = "Failed to load walk schedules"
            isLoading = false
        }
    }

    func toggleJoin(_ schedule: WalkSchedule) {
        guard let uid = auth.currentUser?.uid, let postId = schedule.id else { return }

        let docRef = db.collection("communities").document(communityId)
            .collection("posts").document(postId)

        Task {
            if schedule.isParticipating(userId: uid) {
                try? await docRef.updateData([
                    "likedBy": FieldValue.arrayRemove([uid])
                ])
            } else {
                try? await docRef.updateData([
                    "likedBy": FieldValue.arrayUnion([uid])
                ])
            }
            await load()
        }
    }

    func dayHasWalks(_ date: Date) -> Bool {
        let calendar = Calendar.current
        return schedules.contains { schedule in
            let scheduleDate = Date(timeIntervalSince1970: schedule.startTime / 1000)
            return calendar.isDate(scheduleDate, inSameDayAs: date)
        }
    }

    func difficultyColor(_ difficulty: String) -> Color {
        switch difficulty {
        case "EASY": return .green
        case "MODERATE": return .orange
        case "CHALLENGING": return .red
        default: return .secondary
        }
    }
}

// MARK: - View

struct WalkScheduleView: View {
    let communityId: String
    @StateObject private var viewModel: WalkScheduleViewModel

    init(communityId: String) {
        self.communityId = communityId
        _viewModel = StateObject(wrappedValue: WalkScheduleViewModel(communityId: communityId))
    }

    var body: some View {
        VStack(spacing: 0) {
            weekCalendar
            Divider()

            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.filteredSchedules.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.filteredSchedules) { schedule in
                            WalkScheduleCard(schedule: schedule, viewModel: viewModel)
                                .onTapGesture { viewModel.selectedSchedule = schedule }
                        }
                    }
                    .padding()
                }
                .refreshable { await viewModel.load() }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                viewModel.showCreateSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Create Walk")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Capsule().fill(Color.turquoise60))
                .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
            }
            .padding()
        }
        .sheet(isPresented: $viewModel.showCreateSheet) {
            CreateCommunityPostSheet(communityId: communityId) {
                Task { await viewModel.load() }
            }
        }
        .sheet(item: $viewModel.selectedSchedule) { schedule in
            WalkScheduleDetailSheet(schedule: schedule, viewModel: viewModel)
        }
        .task { await viewModel.load() }
    }

    // MARK: - Week Calendar

    private var weekCalendar: some View {
        VStack(spacing: 8) {
            HStack {
                Button { viewModel.navigateWeek(forward: false) } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.turquoise60)
                }

                Spacer()

                if let first = viewModel.weekDates.first, let last = viewModel.weekDates.last {
                    Text("\(first, format: .dateTime.month().day()) - \(last, format: .dateTime.month().day().year())")
                        .font(.subheadline.bold())
                }

                Spacer()

                Button { viewModel.navigateWeek(forward: true) } label: {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.turquoise60)
                }
            }
            .padding(.horizontal)

            HStack(spacing: 0) {
                ForEach(viewModel.weekDates, id: \.self) { date in
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDay)
                    let isToday = Calendar.current.isDateInToday(date)
                    let hasWalks = viewModel.dayHasWalks(date)

                    Button {
                        viewModel.selectedDay = date
                    } label: {
                        VStack(spacing: 4) {
                            Text(date, format: .dateTime.weekday(.abbreviated))
                                .font(.caption2)
                                .foregroundColor(isSelected ? .white : .secondary)
                            Text(date, format: .dateTime.day())
                                .font(.subheadline)
                                .fontWeight(isToday ? .bold : .regular)
                                .foregroundColor(isSelected ? .white : .primary)
                            Circle()
                                .fill(hasWalks ? Color.turquoise60 : Color.clear)
                                .frame(width: 5, height: 5)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isSelected ? Color.turquoise60 : Color.clear)
                        )
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            Text("No Walks Scheduled")
                .font(.headline)
            Text("No group walks on this day. Create one to get the community walking together!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button {
                viewModel.showCreateSheet = true
            } label: {
                Label("Schedule a Walk", systemImage: "plus.circle")
                    .font(.subheadline.bold())
                    .foregroundColor(.turquoise60)
            }
            .padding(.top, 4)
            Spacer()
        }
        .padding()
    }
}

// MARK: - Walk Schedule Card

private struct WalkScheduleCard: View {
    let schedule: WalkSchedule
    let viewModel: WalkScheduleViewModel

    private var isJoined: Bool {
        schedule.isParticipating(userId: viewModel.currentUserId ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(schedule.title)
                        .font(.headline)
                    Text("by \(schedule.creatorName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(schedule.difficulty.capitalized)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(viewModel.difficultyColor(schedule.difficulty).opacity(0.15)))
                    .foregroundColor(viewModel.difficultyColor(schedule.difficulty))
            }

            // Time & Location
            HStack(spacing: 16) {
                Label(formatTime(schedule.startTime), systemImage: "clock")
                    .font(.subheadline)
                    .foregroundColor(.turquoise60)

                if !schedule.meetingPointName.isEmpty {
                    Label(schedule.meetingPointName, systemImage: "mappin")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            // Mini map if coordinates available
            if let lat = schedule.meetingLatitude, let lon = schedule.meetingLongitude {
                Map(coordinateRegion: .constant(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                )), annotationItems: [MapPin(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))]) { pin in
                    MapMarker(coordinate: pin.coordinate, tint: .turquoise60)
                }
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .disabled(true)
            }

            if !schedule.description.isEmpty {
                Text(schedule.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            // Participants & Join
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "person.2")
                        .font(.caption)
                    Text("\(schedule.participantIds.count) joined")
                        .font(.caption)
                    if let max = schedule.maxParticipants {
                        Text("/ \(max)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .foregroundColor(.secondary)

                Spacer()

                Button {
                    viewModel.toggleJoin(schedule)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isJoined ? "checkmark.circle.fill" : "plus.circle")
                        Text(isJoined ? "Joined" : "Join")
                    }
                    .font(.subheadline.bold())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        Capsule().fill(isJoined ? Color.turquoise60 : Color(.systemGray6))
                    )
                    .foregroundColor(isJoined ? .white : .turquoise60)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(color: .black.opacity(0.06), radius: 4, y: 2))
    }

    private func formatTime(_ timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Map Pin

private struct MapPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Walk Schedule Detail Sheet

private struct WalkScheduleDetailSheet: View {
    let schedule: WalkSchedule
    let viewModel: WalkScheduleViewModel
    @Environment(\.dismiss) private var dismiss

    private var isJoined: Bool {
        schedule.isParticipating(userId: viewModel.currentUserId ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    Text(schedule.title)
                        .font(.title2.bold())

                    // Creator
                    HStack(spacing: 8) {
                        Circle().fill(Color.neutral90).frame(width: 36, height: 36)
                            .overlay(Text(String(schedule.creatorName.prefix(1))).font(.caption.bold()))
                        VStack(alignment: .leading) {
                            Text(schedule.creatorName).font(.subheadline.bold())
                            Text("Organiser").font(.caption).foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    // Details
                    VStack(alignment: .leading, spacing: 12) {
                        detailRow(icon: "clock", label: "Time", value: formatDateTime(schedule.startTime))
                        detailRow(icon: "mappin", label: "Meeting Point", value: schedule.meetingPointName.isEmpty ? "Not specified" : schedule.meetingPointName)
                        detailRow(icon: "figure.walk", label: "Difficulty", value: schedule.difficulty.capitalized)

                        if let distance = schedule.estimatedDistanceKm {
                            detailRow(icon: "ruler", label: "Distance", value: String(format: "%.1f km", distance))
                        }
                        if let duration = schedule.estimatedDurationMin {
                            detailRow(icon: "timer", label: "Duration", value: "\(duration) min")
                        }
                    }

                    // Map
                    if let lat = schedule.meetingLatitude, let lon = schedule.meetingLongitude {
                        Map(coordinateRegion: .constant(MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )), annotationItems: [MapPin(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))]) { pin in
                            MapMarker(coordinate: pin.coordinate, tint: .turquoise60)
                        }
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Description
                    if !schedule.description.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Description").font(.headline)
                            Text(schedule.description).font(.body)
                        }
                    }

                    // Participants
                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.turquoise60)
                        Text("\(schedule.participantIds.count) participant\(schedule.participantIds.count == 1 ? "" : "s")")
                            .font(.subheadline)
                        if let max = schedule.maxParticipants {
                            Text("of \(max) max")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Join/Leave button
                    Button {
                        viewModel.toggleJoin(schedule)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: isJoined ? "xmark.circle" : "plus.circle.fill")
                            Text(isJoined ? "Leave Walk" : "Join Walk")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(isJoined ? Color.red : Color.turquoise60))
                    }
                }
                .padding()
            }
            .navigationTitle("Walk Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.turquoise60)
                .frame(width: 20)
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
        }
    }

    private func formatDateTime(_ timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
