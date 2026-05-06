import SwiftUI

/// Question detail screen — shows the question card, an answers list with
/// vote arrows + accept-answer (asker only), and a composer at the bottom
/// to add an answer. Mirrors Android's `QuestionDetailScreen`.
///
/// Reuses the parent's `QAViewModel` so the listener fleet stays coherent
/// (cancel detail listeners on disappear, the parent list keeps its own
/// listener running).
struct QADetailScreen: View {
    let questionId: String
    @ObservedObject var viewModel: QAViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showAnswerComposer = false
    @State private var showDeleteConfirm = false

    private static let brandColor = Color(red: 0/255, green: 160/255, blue: 176/255)

    private var isQuestionAuthor: Bool {
        guard let uid = viewModel.currentUserId,
              let authorId = viewModel.selectedQuestion?.authorId,
              !authorId.isEmpty else { return false }
        return uid == authorId
    }

    var body: some View {
        ZStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if let question = viewModel.selectedQuestion {
                        QuestionDetailCard(question: question)

                        Divider()

                        HStack {
                            Text("\(viewModel.answers.count) Answer\(viewModel.answers.count == 1 ? "" : "s")")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.horizontal, 16)

                        if viewModel.answers.isEmpty {
                            emptyAnswers
                        } else {
                            ForEach(viewModel.answers) { answer in
                                AnswerCard(
                                    answer: answer,
                                    questionId: questionId,
                                    isQuestionAuthor: isQuestionAuthor,
                                    currentUserId: viewModel.currentUserId,
                                    viewModel: viewModel
                                )
                            }
                        }

                        if let message = viewModel.error {
                            Text(message)
                                .font(.subheadline)
                                .foregroundColor(.red)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                        }
                    } else {
                        ProgressView()
                            .padding(.vertical, 60)
                    }

                    Spacer().frame(height: 80)
                }
                .padding(.top, 12)
            }

            answerFAB
        }
        .navigationTitle("Question")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isQuestionAuthor {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Delete question")
                }
            }
        }
        .onAppear {
            viewModel.loadQuestionDetail(questionId: questionId)
        }
        .onDisappear {
            viewModel.clearDetail()
        }
        .sheet(isPresented: $showAnswerComposer) {
            AnswerComposerSheet(viewModel: viewModel, questionId: questionId)
        }
        .alert("Delete Question?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                viewModel.deleteQuestion(questionId: questionId) {
                    dismiss()
                }
            }
        } message: {
            Text("This will permanently delete the question and all its answers.")
        }
    }

    private var emptyAnswers: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.4))
            Text("No Answers Yet")
                .font(.headline)
            Text("Be the first to answer this question!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var answerFAB: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    showAnswerComposer = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Self.brandColor)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 3)
                }
                .accessibilityLabel("Add answer")
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - Question detail card

private struct QuestionDetailCard: View {
    let question: DogQuestion

    private static let brandColor = Color(red: 0/255, green: 160/255, blue: 176/255)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category pill
            Text(question.category.displayName)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(Self.brandColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Self.brandColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Text(question.title)
                .font(.title3)
                .fontWeight(.bold)

            Text(question.question)
                .font(.body)

            if !question.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(question.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Self.brandColor.opacity(0.12))
                                .foregroundColor(Self.brandColor)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
            }

            HStack {
                HStack(spacing: 6) {
                    UserAvatarView(
                        photoUrl: question.authorPhotoUrl,
                        displayName: question.authorName,
                        size: 24
                    )
                    Text("Asked by \(question.authorName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(formatDate(question.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "eye")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("\(question.viewCount) views")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 4) {
                    Image(systemName: "hand.thumbsup")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("\(question.upvotes) upvotes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy 'at' hh:mm a"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }
}

// MARK: - Answer card

private struct AnswerCard: View {
    let answer: DogAnswer
    let questionId: String
    let isQuestionAuthor: Bool
    let currentUserId: String?
    @ObservedObject var viewModel: QAViewModel

    private static let brandColor = Color(red: 0/255, green: 160/255, blue: 176/255)

    private var userVote: Int {
        guard let uid = currentUserId else { return 0 }
        return answer.userVotes[uid] ?? 0
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            voteColumn

            VStack(alignment: .leading, spacing: 12) {
                if answer.isAccepted {
                    Text("Accepted Answer")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Self.brandColor)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                Text(answer.answer)
                    .font(.body)

                HStack {
                    HStack(spacing: 6) {
                        UserAvatarView(
                            photoUrl: answer.authorPhotoUrl,
                            displayName: answer.authorName,
                            size: 24
                        )
                        Text("Answered by \(answer.authorName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(formatDate(answer.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(answer.isAccepted ? Self.brandColor.opacity(0.08) : Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }

    private var voteColumn: some View {
        VStack(spacing: 4) {
            Button {
                guard let answerId = answer.id else { return }
                viewModel.upvoteAnswer(questionId: questionId, answerId: answerId)
            } label: {
                Image(systemName: userVote == 1 ? "arrow.up.circle.fill" : "arrow.up.circle")
                    .font(.title3)
                    .foregroundColor(userVote == 1 ? Self.brandColor : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Upvote")

            Text("\(answer.score)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Button {
                guard let answerId = answer.id else { return }
                viewModel.downvoteAnswer(questionId: questionId, answerId: answerId)
            } label: {
                Image(systemName: userVote == -1 ? "arrow.down.circle.fill" : "arrow.down.circle")
                    .font(.title3)
                    .foregroundColor(userVote == -1 ? .red : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Downvote")

            // Accept button (asker only, only if not yet accepted)
            if isQuestionAuthor && !answer.isAccepted {
                Button {
                    guard let answerId = answer.id else { return }
                    viewModel.acceptAnswer(questionId: questionId, answerId: answerId)
                } label: {
                    Image(systemName: "checkmark.circle")
                        .font(.title3)
                        .foregroundColor(Self.brandColor)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Accept answer")
            } else if answer.isAccepted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(Self.brandColor)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 40)
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy 'at' hh:mm a"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }
}

// MARK: - Answer composer sheet

private struct AnswerComposerSheet: View {
    @ObservedObject var viewModel: QAViewModel
    let questionId: String
    @Environment(\.dismiss) private var dismiss
    @State private var answer: String = ""

    private static let brandColor = Color(red: 0/255, green: 160/255, blue: 176/255)

    private var isValid: Bool {
        !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Share what you know to help another dog owner.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextEditor(text: $answer)
                    .frame(minHeight: 200)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                    )

                Spacer()
            }
            .padding(16)
            .navigationTitle("Add Your Answer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Post") {
                        viewModel.postAnswer(questionId: questionId, answer: answer)
                        dismiss()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
