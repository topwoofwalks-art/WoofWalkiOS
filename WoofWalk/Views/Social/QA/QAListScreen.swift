import SwiftUI

/// Top-level Community Q&A browse screen. Mirrors Android's
/// `CommunityQAScreen`:
///   - category filter chip row (All / General / Health / ...)
///   - vertical list of question cards
///   - FAB → AskQuestionScreen (full-screen route, not a dialog —
///     matches the Community lessons-learned: hosting forms inside an
///     overlay sheet on iOS clips the keyboard mid-typing on small
///     phones, full-screen route is the gold-standard answer)
///   - tap a card → push QADetailScreen
///   - swipe-down-to-refresh on the list
///
/// The screen owns one `QAViewModel`; the detail screen reuses it via
/// `@StateObject` injection so the same listener fleet keeps the list and
/// detail state coherent (same shape as Android's `hiltViewModel()`-shared
/// instance pattern).
struct QAListScreen: View {
    @StateObject private var viewModel = QAViewModel()
    @State private var showAsk = false
    @State private var pendingNewQuestionId: String?
    @State private var selectedQuestionId: String?

    private static let brandColor = Color(red: 0/255, green: 160/255, blue: 176/255)

    var body: some View {
        ZStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    categoryChipsRow

                    if viewModel.questions.isEmpty && viewModel.isLoading {
                        ProgressView()
                            .padding(.vertical, 40)
                    } else if viewModel.questions.isEmpty {
                        emptyState
                    } else {
                        ForEach(viewModel.questions) { question in
                            QuestionListCard(question: question) {
                                if let id = question.id {
                                    selectedQuestionId = id
                                }
                            }
                        }
                    }

                    Spacer().frame(height: 80)
                }
                .padding(.top, 8)
            }
            .refreshable {
                viewModel.loadQuestions(category: viewModel.selectedCategory)
            }

            askFAB

            errorBanner
        }
        .navigationTitle("Community Q&A")
        .navigationBarTitleDisplayMode(.inline)
        // Detail navigation — iOS 16 compatible (item: requires iOS 17).
        .navigationDestination(isPresented: Binding(
            get: { selectedQuestionId != nil },
            set: { if !$0 { selectedQuestionId = nil } }
        )) {
            if let id = selectedQuestionId {
                QADetailScreen(questionId: id, viewModel: viewModel)
            }
        }
        // Ask flow uses a full-screen sheet so the form has the entire
        // viewport for the rich question body — keeps parity with the other
        // create flows on iOS (CreateCommunityScreen, MeetGreetRequestScreen).
        .sheet(isPresented: $showAsk) {
            AskQuestionScreen(viewModel: viewModel) { newId in
                showAsk = false
                if let newId {
                    pendingNewQuestionId = newId
                }
            }
        }
        .onChange(of: pendingNewQuestionId) { newValue in
            // Defer the navigation push by one runloop so the sheet can
            // dismiss cleanly first — pushing simultaneously with a sheet
            // dismiss can leave the nav stack in an inconsistent state on
            // iOS 16.
            guard let id = newValue else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                selectedQuestionId = id
                pendingNewQuestionId = nil
            }
        }
    }

    // MARK: - Sub views

    private var categoryChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(
                    label: "All",
                    isSelected: viewModel.selectedCategory == nil
                ) {
                    viewModel.loadQuestions(category: nil)
                }
                ForEach(QuestionCategory.allCases) { category in
                    CategoryChip(
                        label: category.displayName,
                        isSelected: viewModel.selectedCategory == category
                    ) {
                        viewModel.loadQuestions(category: category)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.bubble")
                .font(.system(size: 44))
                .foregroundColor(.secondary.opacity(0.4))
            Text("No Questions Yet")
                .font(.headline)
            Text("Be the first to ask a question about your dog!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private var askFAB: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    showAsk = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Self.brandColor)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 3)
                }
                .accessibilityLabel("Ask a question")
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }
        }
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let message = viewModel.error {
            VStack {
                Spacer()
                HStack {
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    Spacer()
                    Button("Dismiss") { viewModel.clearError() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                }
                .padding(12)
                .background(Color.red.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
                .padding(.bottom, 96)
            }
        }
    }
}

// MARK: - Filter chip

private struct CategoryChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    private static let brandColor = Color(red: 0/255, green: 160/255, blue: 176/255)

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(label)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Self.brandColor.opacity(0.15) : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? Self.brandColor : Color.clear, lineWidth: 1)
            )
            .foregroundColor(isSelected ? Self.brandColor : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Question card

/// One row in the questions list. Two-line title, two-line preview,
/// metadata row (answers / views / upvotes), tag chips, footer with
/// asker avatar + posted date. Mirrors Android's `QuestionListItem`.
private struct QuestionListCard: View {
    let question: DogQuestion
    let action: () -> Void

    private static let brandColor = Color(red: 0/255, green: 160/255, blue: 176/255)

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                titleRow

                Text(question.question)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                metadataRow

                if !question.tags.isEmpty {
                    tagsRow
                }

                authorRow
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }

    private var titleRow: some View {
        HStack(alignment: .top) {
            Text(question.title)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            if question.hasAcceptedAnswer {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Self.brandColor)
            }
        }
    }

    private var metadataRow: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Image(systemName: "bubble.left")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text("\(question.answerCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            HStack(spacing: 4) {
                Image(systemName: "eye")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text("\(question.viewCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            HStack(spacing: 4) {
                Image(systemName: "hand.thumbsup")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text("\(question.upvotes)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(formatDate(question.createdAt))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var tagsRow: some View {
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

    private var authorRow: some View {
        HStack(spacing: 6) {
            UserAvatarView(
                photoUrl: question.authorPhotoUrl,
                displayName: question.authorName,
                size: 20
            )
            Text("Asked by \(question.authorName)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }
}
