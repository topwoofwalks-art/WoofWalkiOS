import SwiftUI
import PhotosUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

// MARK: - View Model

@MainActor
class CreateCommunityPostViewModel: ObservableObject {
    @Published var postType: CommunityPostType = .TEXT
    @Published var title: String = ""
    @Published var content: String = ""
    @Published var selectedPhotos: [PhotosPickerItem] = []
    @Published var loadedImages: [UIImage] = []
    @Published var tags: [String] = []
    @Published var tagInput: String = ""

    // Poll fields
    @Published var pollOptions: [String] = ["", ""]
    @Published var pollDurationHours: Int = 24

    // Adoption fields
    @Published var adoptionDogName: String = ""
    @Published var adoptionBreed: String = ""
    @Published var adoptionAge: String = ""
    @Published var adoptionSex: String = "Male"
    @Published var adoptionStatus: String = "AVAILABLE"

    // Walk schedule fields
    @Published var walkDate: Date = Date()
    @Published var walkMeetingPoint: String = ""
    @Published var walkDifficulty: String = "EASY"

    // Milestone fields
    @Published var milestoneDogName: String = ""
    @Published var milestoneType: String = ""
    @Published var milestoneAgeWeeks: String = ""

    // Training fields
    @Published var trainingSkillName: String = ""
    @Published var trainingCategory: String = ""
    @Published var trainingProgress: Double = 0

    // Breed alert fields
    @Published var alertSeverity: String = "INFO"
    @Published var alertBreed: String = ""

    // Destination review fields
    @Published var destinationName: String = ""
    @Published var destinationType: String = ""
    @Published var destinationRating: Double = 3.0

    // Diet plan fields
    @Published var dietPlanName: String = ""
    @Published var dietDogBreed: String = ""
    @Published var dietDogWeight: String = ""

    // Competition fields
    @Published var competitionName: String = ""
    @Published var competitionType: String = ""
    @Published var competitionDate: Date = Date()

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isPosted = false

    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private let storage = Storage.storage()

    let communityId: String

    init(communityId: String) {
        self.communityId = communityId
    }

    var canPost: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !content.trimmingCharacters(in: .whitespaces).isEmpty &&
        !isLoading
    }

    func loadImages() {
        Task {
            var images: [UIImage] = []
            for item in selectedPhotos {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    images.append(image)
                }
            }
            loadedImages = images
        }
    }

    func addTag() {
        let tag = tagInput.trimmingCharacters(in: .whitespaces)
        if !tag.isEmpty && !tags.contains(tag) {
            tags.append(tag)
        }
        tagInput = ""
    }

    func addPollOption() {
        if pollOptions.count < 6 {
            pollOptions.append("")
        }
    }

    func removePollOption(at index: Int) {
        if pollOptions.count > 2 {
            pollOptions.remove(at: index)
        }
    }

    func submitPost() {
        guard let uid = auth.currentUser?.uid else {
            errorMessage = "You must be signed in to post"
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let userDoc = try await db.collection("users").document(uid).getDocument()
                let authorName = userDoc.data()?["username"] as? String ?? "User"
                let authorPhoto = userDoc.data()?["photoUrl"] as? String

                // Upload images
                var mediaUrls: [String] = []
                var mediaTypes: [String] = []
                for (index, image) in loadedImages.enumerated() {
                    if let data = image.jpegData(compressionQuality: 0.8) {
                        let fileName = "\(UUID().uuidString)_\(index).jpg"
                        let ref = storage.reference().child("community_posts/\(communityId)/\(fileName)")
                        let metadata = StorageMetadata()
                        metadata.contentType = "image/jpeg"
                        _ = try await ref.putDataAsync(data, metadata: metadata)
                        let url = try await ref.downloadURL().absoluteString
                        mediaUrls.append(url)
                        mediaTypes.append("IMAGE")
                    }
                }

                // Build poll options if applicable
                var pollOpts: [PollOption] = []
                var pollEndTime: Double?
                if postType == .POLL {
                    pollOpts = pollOptions
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                        .map { PollOption(text: $0) }
                    pollEndTime = (Date().timeIntervalSince1970 + Double(pollDurationHours) * 3600) * 1000
                }

                let now = Date().timeIntervalSince1970 * 1000
                var metadata: [String: String] = [:]

                // Set type-specific metadata
                switch postType {
                case .ADOPTION_LISTING:
                    metadata["dogName"] = adoptionDogName
                    metadata["breed"] = adoptionBreed
                    metadata["age"] = adoptionAge
                    metadata["sex"] = adoptionSex
                    metadata["status"] = adoptionStatus
                case .WALK_SCHEDULE:
                    metadata["meetingPoint"] = walkMeetingPoint
                    metadata["difficulty"] = walkDifficulty
                    metadata["startTime"] = "\(walkDate.timeIntervalSince1970 * 1000)"
                case .PUPPY_MILESTONE:
                    metadata["dogName"] = milestoneDogName
                    metadata["milestoneType"] = milestoneType
                    metadata["ageWeeks"] = milestoneAgeWeeks
                case .TRAINING_TIP:
                    metadata["skillName"] = trainingSkillName
                    metadata["category"] = trainingCategory
                    metadata["progress"] = "\(Int(trainingProgress))"
                case .BREED_ALERT:
                    metadata["severity"] = alertSeverity
                    metadata["breed"] = alertBreed
                case .DESTINATION_REVIEW:
                    metadata["destinationName"] = destinationName
                    metadata["destinationType"] = destinationType
                    metadata["rating"] = "\(destinationRating)"
                case .DIET_PLAN:
                    metadata["planName"] = dietPlanName
                    metadata["breed"] = dietDogBreed
                    metadata["weightKg"] = dietDogWeight
                case .COMPETITION_ENTRY:
                    metadata["competitionName"] = competitionName
                    metadata["competitionType"] = competitionType
                    metadata["eventDate"] = "\(competitionDate.timeIntervalSince1970 * 1000)"
                default:
                    break
                }

                let post = CommunityPost(
                    communityId: communityId,
                    authorId: uid,
                    authorName: authorName,
                    authorPhotoUrl: authorPhoto,
                    type: postType.rawValue,
                    title: title.trimmingCharacters(in: .whitespaces),
                    content: content.trimmingCharacters(in: .whitespaces),
                    mediaUrls: mediaUrls,
                    mediaTypes: mediaTypes,
                    tags: tags,
                    pollOptions: pollOpts,
                    pollEndTime: pollEndTime,
                    metadata: metadata.isEmpty ? nil : metadata,
                    createdAt: now,
                    updatedAt: now
                )

                try db.collection("communities").document(communityId)
                    .collection("posts").addDocument(from: post)

                // Increment post count
                try await db.collection("communities").document(communityId).updateData([
                    "postCount": FieldValue.increment(Int64(1)),
                    "updatedAt": now
                ])

                isLoading = false
                isPosted = true
            } catch {
                isLoading = false
                errorMessage = "Failed to create post: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - View

struct CreateCommunityPostSheet: View {
    let communityId: String
    var onDismiss: () -> Void = {}

    @StateObject private var viewModel: CreateCommunityPostViewModel
    @Environment(\.dismiss) private var dismiss

    init(communityId: String, onDismiss: @escaping () -> Void = {}) {
        self.communityId = communityId
        self.onDismiss = onDismiss
        _viewModel = StateObject(wrappedValue: CreateCommunityPostViewModel(communityId: communityId))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    postTypePicker
                    titleField
                    contentField
                    mediaPicker
                    typeSpecificFields
                    tagsSection

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                }
                .padding()
            }
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        viewModel.submitPost()
                    }
                    .fontWeight(.bold)
                    .foregroundColor(.turquoise60)
                    .disabled(!viewModel.canPost)
                }
            }
            .overlay {
                if viewModel.isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay(ProgressView().tint(.white))
                }
            }
            .onChange(of: viewModel.isPosted) { posted in
                if posted {
                    onDismiss()
                    dismiss()
                }
            }
        }
    }

    // MARK: - Post Type Picker

    private var postTypePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Post Type")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(availablePostTypes, id: \.self) { type in
                        Button {
                            viewModel.postType = type
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: iconForPostType(type))
                                    .font(.caption2)
                                Text(displayNameForPostType(type))
                                    .font(.caption)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(viewModel.postType == type ? Color.turquoise60 : Color(.systemGray6))
                            )
                            .foregroundColor(viewModel.postType == type ? .white : .primary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Title & Content

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Title")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            TextField("Give your post a title...", text: $viewModel.title)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var contentField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Content")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            TextEditor(text: $viewModel.content)
                .frame(minHeight: 100)
                .padding(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if viewModel.content.isEmpty {
                        Text("Write your post...")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    // MARK: - Media Picker

    private var mediaPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Photos")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            PhotosPicker(selection: $viewModel.selectedPhotos, maxSelectionCount: 5, matching: .images) {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text("Add Photos (\(viewModel.loadedImages.count)/5)")
                }
                .font(.subheadline)
                .foregroundColor(.turquoise60)
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 10).stroke(Color.turquoise60, style: StrokeStyle(lineWidth: 1, dash: [6])))
            }
            .onChange(of: viewModel.selectedPhotos) { _ in
                viewModel.loadImages()
            }

            if !viewModel.loadedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.loadedImages.indices, id: \.self) { index in
                            Image(uiImage: viewModel.loadedImages[index])
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Type-Specific Fields

    @ViewBuilder
    private var typeSpecificFields: some View {
        switch viewModel.postType {
        case .POLL:
            pollFields
        case .ADOPTION_LISTING:
            adoptionFields
        case .WALK_SCHEDULE:
            walkScheduleFields
        case .PUPPY_MILESTONE:
            milestoneFields
        case .TRAINING_TIP:
            trainingFields
        case .BREED_ALERT:
            breedAlertFields
        case .DESTINATION_REVIEW:
            destinationReviewFields
        case .DIET_PLAN:
            dietPlanFields
        case .COMPETITION_ENTRY:
            competitionFields
        default:
            EmptyView()
        }
    }

    private var pollFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Poll Options")
                .font(.subheadline).fontWeight(.medium).foregroundColor(.secondary)

            ForEach(viewModel.pollOptions.indices, id: \.self) { index in
                HStack {
                    TextField("Option \(index + 1)", text: $viewModel.pollOptions[index])
                        .textFieldStyle(.roundedBorder)
                    if viewModel.pollOptions.count > 2 {
                        Button { viewModel.removePollOption(at: index) } label: {
                            Image(systemName: "minus.circle.fill").foregroundColor(.red)
                        }
                    }
                }
            }

            if viewModel.pollOptions.count < 6 {
                Button { viewModel.addPollOption() } label: {
                    Label("Add Option", systemImage: "plus.circle")
                        .font(.subheadline).foregroundColor(.turquoise60)
                }
            }

            Picker("Duration", selection: $viewModel.pollDurationHours) {
                Text("1 hour").tag(1)
                Text("6 hours").tag(6)
                Text("24 hours").tag(24)
                Text("3 days").tag(72)
                Text("7 days").tag(168)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }

    private var adoptionFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Adoption Details")
                .font(.subheadline).fontWeight(.medium).foregroundColor(.secondary)
            TextField("Dog Name", text: $viewModel.adoptionDogName).textFieldStyle(.roundedBorder)
            TextField("Breed", text: $viewModel.adoptionBreed).textFieldStyle(.roundedBorder)
            TextField("Age (years)", text: $viewModel.adoptionAge).textFieldStyle(.roundedBorder).keyboardType(.numberPad)
            Picker("Sex", selection: $viewModel.adoptionSex) {
                Text("Male").tag("Male")
                Text("Female").tag("Female")
            }.pickerStyle(.segmented)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }

    private var walkScheduleFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Walk Details")
                .font(.subheadline).fontWeight(.medium).foregroundColor(.secondary)
            DatePicker("Date & Time", selection: $viewModel.walkDate, in: Date()...).datePickerStyle(.compact)
            TextField("Meeting Point", text: $viewModel.walkMeetingPoint).textFieldStyle(.roundedBorder)
            Picker("Difficulty", selection: $viewModel.walkDifficulty) {
                Text("Easy").tag("EASY")
                Text("Moderate").tag("MODERATE")
                Text("Challenging").tag("CHALLENGING")
            }.pickerStyle(.segmented)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }

    private var milestoneFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Milestone Details")
                .font(.subheadline).fontWeight(.medium).foregroundColor(.secondary)
            TextField("Dog Name", text: $viewModel.milestoneDogName).textFieldStyle(.roundedBorder)
            TextField("Milestone Type (e.g. First Walk)", text: $viewModel.milestoneType).textFieldStyle(.roundedBorder)
            TextField("Age in Weeks", text: $viewModel.milestoneAgeWeeks).textFieldStyle(.roundedBorder).keyboardType(.numberPad)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }

    private var trainingFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Training Details")
                .font(.subheadline).fontWeight(.medium).foregroundColor(.secondary)
            TextField("Skill Name", text: $viewModel.trainingSkillName).textFieldStyle(.roundedBorder)
            TextField("Category (e.g. Obedience)", text: $viewModel.trainingCategory).textFieldStyle(.roundedBorder)
            VStack(alignment: .leading, spacing: 4) {
                Text("Progress: \(Int(viewModel.trainingProgress))%")
                    .font(.caption).foregroundColor(.secondary)
                Slider(value: $viewModel.trainingProgress, in: 0...100, step: 5)
                    .tint(.turquoise60)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }

    private var breedAlertFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Alert Details")
                .font(.subheadline).fontWeight(.medium).foregroundColor(.secondary)
            TextField("Breed", text: $viewModel.alertBreed).textFieldStyle(.roundedBorder)
            Picker("Severity", selection: $viewModel.alertSeverity) {
                Text("Info").tag("INFO")
                Text("Warning").tag("WARNING")
                Text("Urgent").tag("URGENT")
            }.pickerStyle(.segmented)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }

    private var destinationReviewFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Review Details")
                .font(.subheadline).fontWeight(.medium).foregroundColor(.secondary)
            TextField("Destination Name", text: $viewModel.destinationName).textFieldStyle(.roundedBorder)
            TextField("Type (Park, Cafe, Beach...)", text: $viewModel.destinationType).textFieldStyle(.roundedBorder)
            HStack {
                Text("Rating")
                    .font(.subheadline)
                Spacer()
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: Double(star) <= viewModel.destinationRating ? "star.fill" : "star")
                        .foregroundColor(.yellow)
                        .onTapGesture { viewModel.destinationRating = Double(star) }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }

    private var dietPlanFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Diet Plan Details")
                .font(.subheadline).fontWeight(.medium).foregroundColor(.secondary)
            TextField("Plan Name", text: $viewModel.dietPlanName).textFieldStyle(.roundedBorder)
            TextField("Breed", text: $viewModel.dietDogBreed).textFieldStyle(.roundedBorder)
            TextField("Dog Weight (kg)", text: $viewModel.dietDogWeight).textFieldStyle(.roundedBorder).keyboardType(.decimalPad)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }

    private var competitionFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Competition Details")
                .font(.subheadline).fontWeight(.medium).foregroundColor(.secondary)
            TextField("Competition Name", text: $viewModel.competitionName).textFieldStyle(.roundedBorder)
            TextField("Type (Agility, Show, Flyball...)", text: $viewModel.competitionType).textFieldStyle(.roundedBorder)
            DatePicker("Event Date", selection: $viewModel.competitionDate, displayedComponents: .date).datePickerStyle(.compact)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }

    // MARK: - Tags

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            HStack {
                TextField("Add a tag...", text: $viewModel.tagInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { viewModel.addTag() }
                Button { viewModel.addTag() } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.turquoise60)
                }
                .disabled(viewModel.tagInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if !viewModel.tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(viewModel.tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text("#\(tag)")
                                .font(.caption)
                            Button {
                                viewModel.tags.removeAll { $0 == tag }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption2)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.turquoise90))
                        .foregroundColor(.turquoise30)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var availablePostTypes: [CommunityPostType] {
        [.TEXT, .PHOTO, .POLL, .ADOPTION_LISTING, .WALK_SCHEDULE, .PUPPY_MILESTONE,
         .TRAINING_TIP, .BREED_ALERT, .DESTINATION_REVIEW, .DIET_PLAN, .COMPETITION_ENTRY]
    }

    private func iconForPostType(_ type: CommunityPostType) -> String {
        switch type {
        case .TEXT: return "text.alignleft"
        case .PHOTO: return "photo"
        case .VIDEO: return "video"
        case .WALK_SHARE: return "figure.walk"
        case .POLL: return "chart.bar"
        case .EVENT_ANNOUNCEMENT: return "megaphone"
        case .ADOPTION_LISTING: return "heart.circle"
        case .WALK_SCHEDULE: return "calendar.badge.clock"
        case .PUPPY_MILESTONE: return "star.circle"
        case .TRAINING_TIP: return "graduationcap"
        case .BREED_ALERT: return "exclamationmark.triangle"
        case .DESTINATION_REVIEW: return "mappin.and.ellipse"
        case .DIET_PLAN: return "fork.knife"
        case .COMPETITION_ENTRY: return "trophy"
        case .PINNED: return "pin"
        }
    }

    private func displayNameForPostType(_ type: CommunityPostType) -> String {
        switch type {
        case .TEXT: return "Text"
        case .PHOTO: return "Photo"
        case .VIDEO: return "Video"
        case .WALK_SHARE: return "Walk"
        case .POLL: return "Poll"
        case .EVENT_ANNOUNCEMENT: return "Event"
        case .ADOPTION_LISTING: return "Adoption"
        case .WALK_SCHEDULE: return "Walk Schedule"
        case .PUPPY_MILESTONE: return "Milestone"
        case .TRAINING_TIP: return "Training"
        case .BREED_ALERT: return "Alert"
        case .DESTINATION_REVIEW: return "Review"
        case .DIET_PLAN: return "Diet Plan"
        case .COMPETITION_ENTRY: return "Competition"
        case .PINNED: return "Pinned"
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }

        return (CGSize(width: maxX, height: currentY + lineHeight), positions)
    }
}
