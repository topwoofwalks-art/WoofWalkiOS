import SwiftUI
import FirebaseAuth
import Combine

@MainActor
class StoryViewModel: ObservableObject {
    @Published var storyGroups: [StoryGroup] = []
    @Published var currentUserHasStory = false
    @Published var isCreating = false
    @Published var showCreateStory = false
    @Published var showViewer = false
    @Published var selectedGroupUserId: String?

    // Viewer state
    @Published var currentGroupIndex = 0
    @Published var currentStoryIndex = 0

    private let repository = StoryRepository()
    private var cancellables = Set<AnyCancellable>()

    var currentGroup: StoryGroup? {
        guard currentGroupIndex >= 0 && currentGroupIndex < storyGroups.count else { return nil }
        return storyGroups[currentGroupIndex]
    }

    var currentStory: Story? {
        guard let group = currentGroup,
              currentStoryIndex >= 0 && currentStoryIndex < group.stories.count else { return nil }
        return group.stories[currentStoryIndex]
    }

    init() {
        loadStories()
        checkCurrentUserStory()
    }

    func loadStories() {
        repository.getStories()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] groups in
                self?.storyGroups = groups
            }
            .store(in: &cancellables)
    }

    func checkCurrentUserStory() {
        Task {
            currentUserHasStory = await repository.currentUserHasStories()
        }
    }

    // MARK: - Create Story

    func createStory(imageData: Data, caption: String) {
        isCreating = true
        Task {
            do {
                _ = try await repository.createStory(imageData: imageData, caption: caption)
                currentUserHasStory = true
            } catch {
                print("[Stories] Failed to create: \(error.localizedDescription)")
            }
            isCreating = false
        }
    }

    // MARK: - Viewer Navigation

    func openStoryGroup(userId: String) {
        guard let index = storyGroups.firstIndex(where: { $0.userId == userId }) else { return }
        currentGroupIndex = index
        currentStoryIndex = 0
        selectedGroupUserId = userId
        showViewer = true

        markCurrentStorySeen()
    }

    func nextStory() {
        guard let group = currentGroup else { return }

        if currentStoryIndex < group.stories.count - 1 {
            currentStoryIndex += 1
            markCurrentStorySeen()
        } else if currentGroupIndex < storyGroups.count - 1 {
            currentGroupIndex += 1
            currentStoryIndex = 0
            markCurrentStorySeen()
        } else {
            // End of all stories
            showViewer = false
        }
    }

    func previousStory() {
        if currentStoryIndex > 0 {
            currentStoryIndex -= 1
        } else if currentGroupIndex > 0 {
            currentGroupIndex -= 1
            let prevGroup = storyGroups[currentGroupIndex]
            currentStoryIndex = max(prevGroup.stories.count - 1, 0)
        }
    }

    func hasMoreStories() -> Bool {
        guard let group = currentGroup else { return false }
        return currentStoryIndex < group.stories.count - 1 || currentGroupIndex < storyGroups.count - 1
    }

    func markCurrentStorySeen() {
        guard let story = currentStory, let storyId = story.id else { return }
        Task {
            await repository.markStorySeen(storyId: storyId)
        }
    }

    func dismissViewer() {
        showViewer = false
        selectedGroupUserId = nil
    }

    deinit {
        repository.stopListening()
    }
}
