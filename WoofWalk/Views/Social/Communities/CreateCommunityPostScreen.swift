import SwiftUI
import PhotosUI

/// Full-screen create-post route. NOT a sheet — Android's audit found the
/// keyboard collision in the bottom-sheet variant was a real issue
/// (commit `ec9cbc2` rewrite). Type chips at top, then title + content,
/// optional media via PhotosPicker, optional poll options when type=POLL.
struct CreateCommunityPostScreen: View {
    let communityId: String
    @ObservedObject var viewModel: CommunityDetailViewModel
    let onClose: () -> Void

    @State private var type: CommunityPostType = .text
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var pollOptions: [String] = ["", ""]
    @State private var pollEndOption: PollEnd = .oneDay

    @State private var photosItems: [PhotosPickerItem] = []
    @State private var mediaPreview: [UIImage] = []
    @State private var isUploading: Bool = false
    @State private var error: String?

    @Environment(\.dismiss) private var dismiss

    private enum PollEnd: String, CaseIterable, Identifiable {
        case oneHour = "1 hour"
        case oneDay = "1 day"
        case threeDays = "3 days"
        case oneWeek = "1 week"
        case never = "Never"
        var id: String { rawValue }

        var milliseconds: Double? {
            switch self {
            case .oneHour: return 60 * 60 * 1000
            case .oneDay: return 24 * 60 * 60 * 1000
            case .threeDays: return 3 * 24 * 60 * 60 * 1000
            case .oneWeek: return 7 * 24 * 60 * 60 * 1000
            case .never: return nil
            }
        }
    }

    /// The post types surfaced in the type-chip row. We curate the most
    /// useful ones up-front so the picker doesn't dump all 15 enum values.
    private var availableTypes: [CommunityPostType] {
        var base: [CommunityPostType] = [.text, .photo, .poll]
        if let community = viewModel.community {
            switch community.type {
            case .rescueRehoming: base.append(.adoptionListing)
            case .puppyParents: base.append(.puppyMilestone)
            case .trainingBehaviour: base.append(.trainingTip)
            case .dogSports: base.append(.competitionEntry)
            case .healthNutrition: base.append(.dietPlan)
            case .dogFriendlyTravel: base.append(.destinationReview)
            case .breedSpecific: base.append(.breedAlert)
            case .localNeighbourhood: base.append(.walkSchedule)
            case .seniorDogs: break
            case .general: break
            }
        }
        return base
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                typeChips
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if type == .text || type == .photo || type == .poll {
                            TextField("Title (optional)", text: $title)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            TextField("Title", text: $title)
                                .textFieldStyle(.roundedBorder)
                        }
                        contentField

                        if type == .photo {
                            mediaSection
                        }
                        if type == .poll {
                            pollSection
                        }
                        if needsTypeSpecificFields {
                            typeSpecificFields
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                        onClose()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isUploading {
                            ProgressView()
                        } else {
                            Text("Post")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!canSubmit || isUploading)
                }
            }
            .alert("Error", isPresented: Binding(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )) {
                Button("OK") { error = nil }
            } message: {
                Text(error ?? "")
            }
        }
    }

    // MARK: - Type chips

    private var typeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableTypes) { t in
                    let isSelected = type == t
                    Button {
                        type = t
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: t.iconSystemName)
                                .font(.system(size: 14))
                            Text(t.displayName)
                                .font(.subheadline)
                                .fontWeight(isSelected ? .semibold : .regular)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isSelected ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground))
                        .foregroundColor(isSelected ? .accentColor : .primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Content field

    private var contentField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Content").font(.caption).foregroundColor(.secondary)
            ZStack(alignment: .topLeading) {
                if content.isEmpty {
                    Text(placeholder)
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.top, 10)
                }
                TextEditor(text: $content)
                    .frame(minHeight: 120)
                    .padding(4)
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var placeholder: String {
        switch type {
        case .poll: return "Ask a question..."
        case .adoptionListing: return "Tell us about this dog (age, temperament, requirements)..."
        case .puppyMilestone: return "Describe the milestone — what your puppy did, when..."
        case .trainingTip: return "Share a tip — method, dog's age, what worked..."
        case .competitionEntry: return "Competition name, level, placement..."
        case .dietPlan: return "Daily meals, ingredients, vet approval..."
        case .destinationReview: return "Where, what was great, what to know..."
        case .breedAlert: return "Describe the alert — symptoms, severity, sources..."
        case .walkSchedule: return "Meeting point, time, route, difficulty..."
        default: return "What's on your mind?"
        }
    }

    // MARK: - Media

    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Photos").font(.caption).foregroundColor(.secondary)
            if !mediaPreview.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(mediaPreview.enumerated()), id: \.offset) { idx, img in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 120, height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                Button {
                                    mediaPreview.remove(at: idx)
                                    if idx < photosItems.count {
                                        photosItems.remove(at: idx)
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white)
                                        .background(Color.black.opacity(0.5).clipShape(Circle()))
                                }
                                .padding(4)
                            }
                        }
                    }
                }
            }
            PhotosPicker(selection: $photosItems, maxSelectionCount: 6, matching: .images) {
                Label(mediaPreview.isEmpty ? "Add photos" : "Add more", systemImage: "photo.on.rectangle")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .onChange(of: photosItems) { newItems in
                Task {
                    var loaded: [UIImage] = []
                    for item in newItems {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let img = UIImage(data: data) {
                            loaded.append(img)
                        }
                    }
                    mediaPreview = loaded
                }
            }
        }
    }

    // MARK: - Poll

    private var pollSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Poll options").font(.caption).foregroundColor(.secondary)
            ForEach(pollOptions.indices, id: \.self) { idx in
                HStack {
                    TextField("Option \(idx + 1)", text: Binding(
                        get: { pollOptions[idx] },
                        set: { pollOptions[idx] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    if pollOptions.count > 2 {
                        Button {
                            pollOptions.remove(at: idx)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            Button {
                if pollOptions.count < 6 {
                    pollOptions.append("")
                }
            } label: {
                Label("Add option", systemImage: "plus.circle")
                    .font(.subheadline)
            }
            .disabled(pollOptions.count >= 6)
            .padding(.top, 4)

            HStack {
                Text("Closes after:").font(.caption).foregroundColor(.secondary)
                Picker("", selection: $pollEndOption) {
                    ForEach(PollEnd.allCases) { e in
                        Text(e.rawValue).tag(e)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    // MARK: - Type-specific (light-touch text-only metadata for now)

    private var needsTypeSpecificFields: Bool {
        switch type {
        case .adoptionListing, .puppyMilestone, .competitionEntry, .breedAlert, .walkSchedule:
            return true
        default: return false
        }
    }

    @ViewBuilder
    private var typeSpecificFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Additional details")
                .font(.caption)
                .foregroundColor(.secondary)
            switch type {
            case .adoptionListing:
                Text("Add the dog's name, age, breed, and any rehoming requirements directly into the content above. Photos help — attach as many as you can.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            case .puppyMilestone:
                Text("Mention your puppy's age in weeks and the milestone category (first walk, vaccination, etc.) in the content above.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            case .competitionEntry:
                Text("Include the sport, level, placement, and date in the content above.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            case .breedAlert:
                Text("Mark severity in the content (Info / Warning / Urgent) and link a vet-approved source if you have one.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            case .walkSchedule:
                Text("Spell out the meeting point, time, and difficulty in the content above. Use the Events tab if you want RSVPs.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            default:
                EmptyView()
            }
        }
        .padding(10)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Submit

    private var canSubmit: Bool {
        let hasText = !title.trimmingCharacters(in: .whitespaces).isEmpty
            || !content.trimmingCharacters(in: .whitespaces).isEmpty
        if type == .poll {
            return hasText && pollOptions.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count >= 2
        }
        return hasText
    }

    private func submit() async {
        isUploading = true
        defer { isUploading = false }

        // Convert PhotosPickerItems to JPEG data — done on demand here so
        // the picker doesn't preload the full data until the user submits.
        var mediaData: [Data] = []
        if type == .photo {
            for item in photosItems {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    if let img = UIImage(data: data),
                       let jpeg = img.jpegData(compressionQuality: 0.85) {
                        mediaData.append(jpeg)
                    } else {
                        mediaData.append(data)
                    }
                }
            }
        }

        var pollOptionsParsed: [PollOption] = []
        var pollEndTime: Double?
        if type == .poll {
            pollOptionsParsed = pollOptions
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .map { PollOption(text: $0) }
            if let durationMs = pollEndOption.milliseconds {
                pollEndTime = Date().timeIntervalSince1970 * 1000 + durationMs
            }
        }

        await viewModel.createPost(
            type: type,
            title: title.trimmingCharacters(in: .whitespaces),
            content: content.trimmingCharacters(in: .whitespaces),
            mediaData: mediaData,
            pollOptions: pollOptionsParsed,
            pollEndTime: pollEndTime
        )
        if viewModel.error == nil {
            dismiss()
            onClose()
        } else {
            error = viewModel.error
            viewModel.clearError()
        }
    }
}
