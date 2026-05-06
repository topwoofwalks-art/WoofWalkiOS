import SwiftUI

/// Full-screen sheet for posting a new question. Mirrors Android's
/// `AskQuestionDialog` form — title, category dropdown, body, comma-
/// separated tags — but uses a full-screen NavigationStack instead of an
/// AlertDialog so the keyboard never clips the body field on small phones
/// (lessons-learned applied to the Community port).
///
/// On successful post, calls back to the parent with the new question id.
/// The parent (QAListScreen) defers the navigation push by one runloop so
/// the sheet can dismiss cleanly first — see QAListScreen.onChange.
struct AskQuestionScreen: View {
    @ObservedObject var viewModel: QAViewModel
    /// `nil` = user cancelled, non-nil = post succeeded. Caller dismisses
    /// + handles navigation.
    let onComplete: (String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var question: String = ""
    @State private var category: QuestionCategory = .general
    @State private var tagsRaw: String = ""
    @State private var isSubmitting: Bool = false
    @State private var localError: String?

    private static let brandColor = Color(red: 0/255, green: 160/255, blue: 176/255)

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var trimmedQuestion: String {
        question.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var isValid: Bool {
        !trimmedTitle.isEmpty && !trimmedQuestion.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    introCopy

                    titleField
                    categoryField
                    questionField
                    tagsField

                    if let message = localError {
                        Text(message)
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Ask a Question")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        onComplete(nil)
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button("Post") { submit() }
                            .disabled(!isValid)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    private var introCopy: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Ask the community")
                .font(.title3.weight(.bold))
            Text("Share a question about your dog — health, training, behaviour, anything goes.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Title")
                .font(.subheadline.weight(.semibold))
            TextField("e.g. How do I stop my puppy chewing shoes?", text: $title)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
    }

    private var categoryField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Category")
                .font(.subheadline.weight(.semibold))
            Menu {
                ForEach(QuestionCategory.allCases) { option in
                    Button {
                        category = option
                    } label: {
                        HStack {
                            Image(systemName: option.iconSystemName)
                            Text(option.displayName)
                            if option == category {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: category.iconSystemName)
                        .foregroundColor(Self.brandColor)
                    Text(category.displayName)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }

    private var questionField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Question Details")
                .font(.subheadline.weight(.semibold))
            TextEditor(text: $question)
                .frame(minHeight: 160)
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
    }

    private var tagsField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tags")
                .font(.subheadline.weight(.semibold))
            TextField("puppy, training, health", text: $tagsRaw)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            Text("Comma-separated. Tags help others find your question.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Submit

    private func submit() {
        guard isValid, !isSubmitting else { return }
        isSubmitting = true
        localError = nil

        let tagList = tagsRaw
            .split(separator: ",", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        viewModel.postQuestion(
            title: trimmedTitle,
            question: trimmedQuestion,
            category: category,
            tags: tagList,
            imageUrls: []
        ) { newId in
            isSubmitting = false
            onComplete(newId)
            dismiss()
        }

        // If the VM reports an error before completion, surface it inline.
        // We re-arm the submit button so the user can edit + retry.
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            if isSubmitting {
                isSubmitting = false
                localError = viewModel.error ?? "Posting timed out. Please try again."
            }
        }
    }
}
