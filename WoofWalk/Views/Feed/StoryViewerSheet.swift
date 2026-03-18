import SwiftUI

struct StoryViewerSheet: View {
    @ObservedObject var viewModel: StoryViewModel
    @State private var progress: CGFloat = 0
    @State private var isPaused = false
    @State private var timerTask: Task<Void, Never>?
    @State private var dragOffset: CGFloat = 0

    private let storyDuration: TimeInterval = 5.0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                if let group = viewModel.currentGroup,
                   let story = viewModel.currentStory {
                    // Story image
                    AsyncImage(url: URL(string: story.mediaUrl)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        case .failure:
                            Image(systemName: "photo")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                        default:
                            ProgressView()
                                .tint(.white)
                        }
                    }

                    // Top overlay: progress bars + user info
                    VStack(spacing: 0) {
                        topOverlay(group: group, story: story)
                        Spacer()

                        // Caption at bottom
                        if !story.caption.isEmpty {
                            captionOverlay(caption: story.caption)
                        }
                    }

                    // Tap zones (left = previous, right = next)
                    HStack(spacing: 0) {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.previousStory()
                                restartTimer()
                            }

                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                advanceOrDismiss()
                            }
                    }
                    .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                        isPaused = pressing
                    }, perform: {})
                }
            }
            .offset(y: dragOffset)
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onChanged { value in
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 100 {
                            viewModel.dismissViewer()
                        }
                        withAnimation(.easeOut(duration: 0.2)) {
                            dragOffset = 0
                        }
                    }
            )
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .onAppear { startTimer() }
        .onDisappear { timerTask?.cancel() }
        .onChange(of: viewModel.currentStoryIndex) { _ in restartTimer() }
        .onChange(of: viewModel.currentGroupIndex) { _ in restartTimer() }
        .onChange(of: isPaused) { paused in
            if paused {
                timerTask?.cancel()
            } else {
                startTimer()
            }
        }
    }

    // MARK: - Top Overlay

    private func topOverlay(group: StoryGroup, story: Story) -> some View {
        VStack(spacing: 8) {
            // Segmented progress bars
            HStack(spacing: 2) {
                ForEach(Array(group.stories.enumerated()), id: \.offset) { index, _ in
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.3))
                                .frame(height: 2)

                            Capsule()
                                .fill(Color.white)
                                .frame(
                                    width: segmentWidth(index: index, totalWidth: geo.size.width),
                                    height: 2
                                )
                        }
                    }
                    .frame(height: 2)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            // User info row
            HStack {
                // User avatar
                if let avatarUrl = group.userAvatar, let url = URL(string: avatarUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .foregroundColor(.white)
                        }
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 32, height: 32)
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(group.userName)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)

                    if let createdAt = story.createdAt?.dateValue() {
                        Text(timeAgo(from: createdAt))
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()

                Button {
                    viewModel.dismissViewer()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 12)
        }
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.5), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            .allowsHitTesting(false),
            alignment: .top
        )
    }

    // MARK: - Caption Overlay

    private func captionOverlay(caption: String) -> some View {
        Text(caption)
            .font(.body)
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    // MARK: - Progress Helpers

    private func segmentWidth(index: Int, totalWidth: CGFloat) -> CGFloat {
        let storyIndex = viewModel.currentStoryIndex
        if index < storyIndex {
            return totalWidth
        } else if index == storyIndex {
            return totalWidth * progress
        } else {
            return 0
        }
    }

    // MARK: - Timer

    private func startTimer() {
        timerTask?.cancel()
        progress = 0

        timerTask = Task { @MainActor in
            let steps = 100
            let stepDuration = storyDuration / Double(steps)

            for i in 1...steps {
                if Task.isCancelled { return }
                try? await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
                if Task.isCancelled { return }
                progress = CGFloat(i) / CGFloat(steps)
            }

            if !Task.isCancelled {
                advanceOrDismiss()
            }
        }
    }

    private func restartTimer() {
        viewModel.markCurrentStorySeen()
        startTimer()
    }

    private func advanceOrDismiss() {
        if viewModel.hasMoreStories() {
            viewModel.nextStory()
        } else {
            viewModel.dismissViewer()
        }
    }

    // MARK: - Time Formatting

    private func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "Just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        return "\(hours / 24)d ago"
    }
}
