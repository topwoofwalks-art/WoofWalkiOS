import Foundation
import FirebaseAuth
import Combine

/// Mirrors `ui.qa.QAViewModel` on Android. Drives both the Q&A list screen
/// and the detail screen — keeping them in one VM matches the Android shape
/// where `CommunityQAScreen` and `QuestionDetailScreen` share state via the
/// same `hiltViewModel()` instance.
///
/// Two listeners run in parallel for the detail screen: one for the
/// question doc, one for the answers subcollection. Switching to a different
/// question via `loadQuestionDetail(_:)` cancels the previous detail
/// listeners — safe even when the user backgrounds and re-enters detail
/// quickly (no leaked snapshot listeners).
@MainActor
final class QAViewModel: ObservableObject {
    @Published var questions: [DogQuestion] = []
    @Published var selectedQuestion: DogQuestion?
    @Published var answers: [DogAnswer] = []
    @Published var selectedCategory: QuestionCategory?
    @Published var isLoading: Bool = false
    @Published var error: String?

    private let repository: QARepository
    private var listCancellable: AnyCancellable?
    private var detailCancellables = Set<AnyCancellable>()

    var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    init(repository: QARepository = .shared) {
        self.repository = repository
        loadQuestions(category: nil)
    }

    // MARK: - List

    /// Subscribe to the questions list, optionally filtered by category.
    /// Cancels any previous list listener so the publisher chain doesn't
    /// emit stale data into the UI.
    func loadQuestions(category: QuestionCategory?) {
        isLoading = true
        selectedCategory = category
        listCancellable?.cancel()
        listCancellable = repository.listenQuestions(category: category)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in
                self?.questions = list
                self?.isLoading = false
            }
    }

    // MARK: - Detail

    /// Load detail for a question. Wires up two listeners — question doc +
    /// answers subcollection — and bumps `viewCount` once. The view-count
    /// bump is a one-shot fire-and-forget; if it fails (rules deny / offline)
    /// the rest of the detail screen still works.
    func loadQuestionDetail(questionId: String) {
        detailCancellables.removeAll()
        selectedQuestion = nil
        answers = []

        repository.listenQuestion(questionId: questionId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] question in
                self?.selectedQuestion = question
            }
            .store(in: &detailCancellables)

        repository.listenAnswers(questionId: questionId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in
                self?.answers = list
            }
            .store(in: &detailCancellables)

        Task { await repository.incrementViewCount(questionId: questionId) }
    }

    /// Tear down detail listeners when the user navigates away. Called from
    /// the detail screen's `onDisappear`.
    func clearDetail() {
        detailCancellables.removeAll()
        selectedQuestion = nil
        answers = []
    }

    // MARK: - Mutations

    /// Post a new question. On success, calls `onSuccess` with the new
    /// document id so the caller can navigate into the detail screen
    /// (matches Android's `onSuccess: (String) -> Unit` callback).
    func postQuestion(
        title: String,
        question: String,
        category: QuestionCategory,
        tags: [String],
        imageUrls: [String],
        onSuccess: @escaping (String) -> Void
    ) {
        Task {
            do {
                let id = try await repository.postQuestion(
                    title: title,
                    question: question,
                    category: category,
                    tags: tags,
                    imageUrls: imageUrls
                )
                onSuccess(id)
            } catch {
                self.error = error.localizedDescription
                print("[QAViewModel] postQuestion failed: \(error.localizedDescription)")
            }
        }
    }

    func postAnswer(questionId: String, answer: String) {
        Task {
            do {
                _ = try await repository.postAnswer(questionId: questionId, answer: answer)
            } catch {
                self.error = error.localizedDescription
                print("[QAViewModel] postAnswer failed: \(error.localizedDescription)")
            }
        }
    }

    func upvoteAnswer(questionId: String, answerId: String) {
        Task {
            do {
                try await repository.upvoteAnswer(questionId: questionId, answerId: answerId)
            } catch {
                self.error = error.localizedDescription
                print("[QAViewModel] upvoteAnswer failed: \(error.localizedDescription)")
            }
        }
    }

    func downvoteAnswer(questionId: String, answerId: String) {
        Task {
            do {
                try await repository.downvoteAnswer(questionId: questionId, answerId: answerId)
            } catch {
                self.error = error.localizedDescription
                print("[QAViewModel] downvoteAnswer failed: \(error.localizedDescription)")
            }
        }
    }

    func acceptAnswer(questionId: String, answerId: String) {
        Task {
            do {
                try await repository.acceptAnswer(questionId: questionId, answerId: answerId)
            } catch {
                self.error = error.localizedDescription
                print("[QAViewModel] acceptAnswer failed: \(error.localizedDescription)")
            }
        }
    }

    func deleteQuestion(questionId: String, onSuccess: @escaping () -> Void) {
        Task {
            do {
                try await repository.deleteQuestion(questionId: questionId)
                onSuccess()
            } catch {
                self.error = error.localizedDescription
                print("[QAViewModel] deleteQuestion failed: \(error.localizedDescription)")
            }
        }
    }

    func clearError() { error = nil }
}
