import SwiftUI

struct ReportPostSheet: View {
    let postId: String

    @State private var selectedReason: ReportReason?
    @State private var additionalDetails: String = ""
    @State private var isSubmitting: Bool = false
    @State private var isSubmitted: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            if isSubmitted {
                reportSubmittedView
            } else {
                reportFormView
            }
        }
    }

    // MARK: - Report Form

    private var reportFormView: some View {
        Form {
            Section {
                Text("Why are you reporting this post?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }

            Section("Select a reason") {
                ForEach(ReportReason.allCases) { reason in
                    Button {
                        selectedReason = reason
                    } label: {
                        HStack {
                            Image(systemName: reason.icon)
                                .foregroundColor(reason.color)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(reason.title)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Text(reason.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selectedReason == reason {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }

            Section("Additional details (optional)") {
                TextEditor(text: $additionalDetails)
                    .frame(minHeight: 80)
                    .overlay(alignment: .topLeading) {
                        if additionalDetails.isEmpty {
                            Text("Provide any additional context...")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }
            }

            Section {
                Text("Post ID: \(postId)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospaced()
            }
        }
        .navigationTitle("Report Post")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Submit") {
                    submitReport()
                }
                .disabled(selectedReason == nil || isSubmitting)
                .bold()
            }
        }
    }

    // MARK: - Submitted View

    private var reportSubmittedView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            Text("Report Submitted")
                .font(.title2.bold())
            Text("Thank you for helping keep the WoofWalk community safe. Our moderation team will review this report.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 8) {
                Label("We'll review within 24 hours", systemImage: "clock")
                Label("The post author won't know who reported", systemImage: "eye.slash")
                Label("We may contact you if we need more info", systemImage: "envelope")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 8)

            Spacer()

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity)
        .navigationTitle("Report Post")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Submit

    private func submitReport() {
        isSubmitting = true
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isSubmitting = false
            isSubmitted = true
        }
    }
}

// MARK: - Report Reason

private enum ReportReason: String, CaseIterable, Identifiable {
    case spam
    case harassment
    case inappropriate
    case misinformation
    case animal_cruelty
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spam: return "Spam"
        case .harassment: return "Harassment or Bullying"
        case .inappropriate: return "Inappropriate Content"
        case .misinformation: return "False Information"
        case .animal_cruelty: return "Animal Cruelty"
        case .other: return "Other"
        }
    }

    var description: String {
        switch self {
        case .spam: return "Unsolicited advertising or repetitive posts"
        case .harassment: return "Targeting or intimidating another user"
        case .inappropriate: return "Offensive language, images, or themes"
        case .misinformation: return "Deliberately misleading content"
        case .animal_cruelty: return "Content showing or promoting harm to animals"
        case .other: return "Something else not listed above"
        }
    }

    var icon: String {
        switch self {
        case .spam: return "envelope.badge.fill"
        case .harassment: return "person.fill.xmark"
        case .inappropriate: return "eye.slash.fill"
        case .misinformation: return "exclamationmark.bubble.fill"
        case .animal_cruelty: return "pawprint.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .spam: return .orange
        case .harassment: return .red
        case .inappropriate: return .purple
        case .misinformation: return .yellow
        case .animal_cruelty: return .red
        case .other: return .gray
        }
    }
}
