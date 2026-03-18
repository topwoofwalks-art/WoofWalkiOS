import SwiftUI

// MARK: - Story Viewer Screen

struct StoryViewerScreen: View {
    let userId: String

    @State private var currentIndex: Int = 0
    @State private var progress: CGFloat = 0
    @State private var isPaused: Bool = false
    @Environment(\.dismiss) private var dismiss

    private let storyDuration: TimeInterval = 5.0

    private var sampleStories: [StoryItem] {
        [
            StoryItem(id: "1", imageSystemName: "photo.fill", caption: "Morning walk with Bella", timeAgo: "2h ago"),
            StoryItem(id: "2", imageSystemName: "pawprint.fill", caption: "Found a new trail!", timeAgo: "4h ago"),
            StoryItem(id: "3", imageSystemName: "leaf.fill", caption: "Beautiful park day", timeAgo: "6h ago"),
        ]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if sampleStories.isEmpty {
                storyEmptyState
            } else {
                storyContent
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden()
    }

    // MARK: - Story Content

    private var storyContent: some View {
        ZStack {
            // Background story image placeholder
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    VStack(spacing: 16) {
                        Image(systemName: sampleStories[currentIndex].imageSystemName)
                            .font(.system(size: 80))
                            .foregroundColor(.white.opacity(0.8))
                        Text(sampleStories[currentIndex].caption)
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .ignoresSafeArea()

            // Tap zones for navigation
            HStack(spacing: 0) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { previousStory() }
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { nextStory() }
            }

            // Top overlay: progress bars + user info
            VStack {
                storyProgressBars
                    .padding(.horizontal, 8)
                    .padding(.top, 8)

                storyHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                Spacer()

                // Caption bar
                HStack {
                    Text(sampleStories[currentIndex].caption)
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding()
                .background(.ultraThinMaterial.opacity(0.5))
            }
        }
    }

    // MARK: - Progress Bars

    private var storyProgressBars: some View {
        HStack(spacing: 4) {
            ForEach(0..<sampleStories.count, id: \.self) { index in
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.3))
                        Capsule()
                            .fill(Color.white)
                            .frame(width: barWidth(for: index, totalWidth: geo.size.width))
                    }
                }
                .frame(height: 3)
            }
        }
    }

    private func barWidth(for index: Int, totalWidth: CGFloat) -> CGFloat {
        if index < currentIndex {
            return totalWidth
        } else if index == currentIndex {
            return totalWidth * progress
        }
        return 0
    }

    // MARK: - Header

    private var storyHeader: some View {
        HStack {
            Circle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "person.fill")
                        .foregroundColor(.white)
                        .font(.caption)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text("Walker")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text(sampleStories[currentIndex].timeAgo)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Circle().fill(Color.black.opacity(0.3)))
            }
        }
    }

    // MARK: - Empty State

    private var storyEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "eye.slash")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.5))
            Text("No Stories")
                .font(.title2.bold())
                .foregroundColor(.white)
            Text("This user hasn't shared any stories yet.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
            Button("Close") { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.top)
        }
    }

    // MARK: - Navigation

    private func nextStory() {
        if currentIndex < sampleStories.count - 1 {
            currentIndex += 1
            progress = 0
        } else {
            dismiss()
        }
    }

    private func previousStory() {
        if currentIndex > 0 {
            currentIndex -= 1
            progress = 0
        }
    }
}

// MARK: - Story Item Model

private struct StoryItem: Identifiable {
    let id: String
    let imageSystemName: String
    let caption: String
    let timeAgo: String
}

// MARK: - Follow List Screen

struct FollowListScreen: View {
    let userId: String
    let type: String

    @State private var searchText: String = ""
    @Environment(\.dismiss) private var dismiss

    private var isFollowers: Bool {
        type.lowercased() == "followers"
    }

    private var sampleUsers: [FollowUser] {
        [
            FollowUser(id: "1", name: "Sarah & Bella", breed: "Labrador", avatar: "person.circle.fill", isFollowing: true),
            FollowUser(id: "2", name: "Tom & Max", breed: "Border Collie", avatar: "person.circle.fill", isFollowing: false),
            FollowUser(id: "3", name: "Emma & Luna", breed: "Golden Retriever", avatar: "person.circle.fill", isFollowing: true),
            FollowUser(id: "4", name: "James & Rocky", breed: "German Shepherd", avatar: "person.circle.fill", isFollowing: false),
            FollowUser(id: "5", name: "Lucy & Daisy", breed: "Cocker Spaniel", avatar: "person.circle.fill", isFollowing: true),
        ]
    }

    private var filteredUsers: [FollowUser] {
        if searchText.isEmpty { return sampleUsers }
        return sampleUsers.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List {
            if filteredUsers.isEmpty {
                emptyState
            } else {
                ForEach(filteredUsers) { user in
                    followUserRow(user)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search \(type.lowercased())")
        .navigationTitle(type.capitalized)
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - User Row

    private func followUserRow(_ user: FollowUser) -> some View {
        HStack(spacing: 12) {
            Image(systemName: user.avatar)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(user.name)
                    .font(.body.bold())
                Text(user.breed)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                // Toggle follow state
            } label: {
                Text(user.isFollowing ? "Following" : "Follow")
                    .font(.subheadline.bold())
                    .foregroundColor(user.isFollowing ? .secondary : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(user.isFollowing ? Color(.systemGray5) : Color.accentColor)
                    .cornerRadius(20)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(isFollowers ? "No Followers Yet" : "Not Following Anyone")
                .font(.headline)
            Text(isFollowers
                 ? "When people follow this user, they'll appear here."
                 : "People this user follows will appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .listRowBackground(Color.clear)
    }
}

// MARK: - Follow User Model

private struct FollowUser: Identifiable {
    let id: String
    let name: String
    let breed: String
    let avatar: String
    var isFollowing: Bool
}
