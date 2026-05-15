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

// NOTE: `FollowListScreen` lives in `Views/Social/FollowListScreen.swift`
// — that's the Firestore-backed real implementation. The placeholder that
// previously lived here has been removed to resolve a duplicate-declaration
// build error; do not re-add it.
