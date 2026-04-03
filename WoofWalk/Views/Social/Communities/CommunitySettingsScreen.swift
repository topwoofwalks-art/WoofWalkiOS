import SwiftUI
import PhotosUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

// MARK: - View Model

@MainActor
class CommunitySettingsViewModel: ObservableObject {
    @Published var community: Community?
    @Published var name: String = ""
    @Published var description: String = ""
    @Published var rules: String = ""
    @Published var selectedType: CommunityType = .GENERAL
    @Published var privacy: CommunityPrivacy = .PUBLIC
    @Published var tags: [String] = []
    @Published var tagInput: String = ""
    @Published var coverPhotoItem: PhotosPickerItem?
    @Published var coverImage: UIImage?
    @Published var breedFilter: String = ""

    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var showArchiveAlert = false
    @Published var showDeleteAlert = false
    @Published var isArchived = false
    @Published var isDeleted = false

    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private let storage = Storage.storage()

    let communityId: String

    init(communityId: String) {
        self.communityId = communityId
    }

    var hasChanges: Bool {
        guard let c = community else { return false }
        return name != c.name ||
            description != c.description ||
            rules != c.rules ||
            selectedType.rawValue != c.type ||
            privacy.rawValue != c.privacy ||
            tags != c.tags ||
            breedFilter != (c.breedFilter ?? "") ||
            coverImage != nil
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        do {
            let doc = try await db.collection("communities").document(communityId).getDocument()
            guard let community = try? doc.data(as: Community.self) else {
                errorMessage = "Community not found"
                isLoading = false
                return
            }
            self.community = community
            self.name = community.name
            self.description = community.description
            self.rules = community.rules
            self.selectedType = community.getCommunityType()
            self.privacy = community.getCommunityPrivacy()
            self.tags = community.tags
            self.breedFilter = community.breedFilter ?? ""
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func loadCoverImage() {
        guard let item = coverPhotoItem else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                coverImage = image
            }
        }
    }

    // MARK: - Save

    func save() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Community name is required"
            return
        }

        isSaving = true
        errorMessage = nil
        successMessage = nil

        Task {
            do {
                var updates: [String: Any] = [
                    "name": name.trimmingCharacters(in: .whitespaces),
                    "description": description.trimmingCharacters(in: .whitespaces),
                    "rules": rules.trimmingCharacters(in: .whitespaces),
                    "type": selectedType.rawValue,
                    "privacy": privacy.rawValue,
                    "tags": tags,
                    "updatedAt": Date().timeIntervalSince1970 * 1000
                ]

                if selectedType == .BREED_SPECIFIC {
                    updates["breedFilter"] = breedFilter.trimmingCharacters(in: .whitespaces)
                }

                if let image = coverImage, let data = image.jpegData(compressionQuality: 0.8) {
                    let fileName = "\(UUID().uuidString).jpg"
                    let ref = storage.reference().child("community_covers/\(communityId)/\(fileName)")
                    let metadata = StorageMetadata()
                    metadata.contentType = "image/jpeg"
                    _ = try await ref.putDataAsync(data, metadata: metadata)
                    let url = try await ref.downloadURL().absoluteString
                    updates["coverPhotoUrl"] = url
                }

                try await db.collection("communities").document(communityId).updateData(updates)

                isSaving = false
                successMessage = "Settings saved successfully"
                coverImage = nil

                // Refresh community data
                await load()
            } catch {
                isSaving = false
                errorMessage = "Failed to save: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Danger Zone

    func archiveCommunity() {
        isSaving = true
        Task {
            do {
                try await db.collection("communities").document(communityId).updateData([
                    "isArchived": true,
                    "updatedAt": Date().timeIntervalSince1970 * 1000
                ])
                isSaving = false
                isArchived = true
            } catch {
                isSaving = false
                errorMessage = "Failed to archive community"
            }
        }
    }

    func deleteCommunity() {
        isSaving = true
        Task {
            do {
                try await db.collection("communities").document(communityId).delete()
                isSaving = false
                isDeleted = true
            } catch {
                isSaving = false
                errorMessage = "Failed to delete community"
            }
        }
    }

    func addTag() {
        let tag = tagInput.trimmingCharacters(in: .whitespaces)
        if !tag.isEmpty && !tags.contains(tag) {
            tags.append(tag)
        }
        tagInput = ""
    }
}

// MARK: - View

struct CommunitySettingsScreen: View {
    let communityId: String

    @StateObject private var viewModel: CommunitySettingsViewModel
    @Environment(\.dismiss) private var dismiss

    init(communityId: String) {
        self.communityId = communityId
        _viewModel = StateObject(wrappedValue: CommunitySettingsViewModel(communityId: communityId))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.community == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    settingsForm
                }
            }
            .navigationTitle("Community Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { viewModel.save() }
                        .fontWeight(.bold)
                        .foregroundColor(.turquoise60)
                        .disabled(!viewModel.hasChanges || viewModel.isSaving)
                }
            }
            .overlay {
                if viewModel.isSaving {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay(ProgressView().tint(.white))
                }
            }
            .alert("Archive Community", isPresented: $viewModel.showArchiveAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Archive", role: .destructive) { viewModel.archiveCommunity() }
            } message: {
                Text("Archived communities are hidden from search and become read-only. Members can still view existing content. This can be reversed.")
            }
            .alert("Delete Community", isPresented: $viewModel.showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete Permanently", role: .destructive) { viewModel.deleteCommunity() }
            } message: {
                Text("This will permanently delete the community, all posts, comments, and member data. This action cannot be undone.")
            }
            .onChange(of: viewModel.isArchived) { archived in
                if archived { dismiss() }
            }
            .onChange(of: viewModel.isDeleted) { deleted in
                if deleted { dismiss() }
            }
            .task { await viewModel.load() }
        }
    }

    // MARK: - Settings Form

    private var settingsForm: some View {
        List {
            editSection
            rulesSection
            privacySection
            coverPhotoSection
            tagsSection

            if viewModel.selectedType == .BREED_SPECIFIC {
                breedSection
            }

            dangerZone

            if let success = viewModel.successMessage {
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(success)
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                }
            }

            if let error = viewModel.errorMessage {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }

    // MARK: - Edit Section

    private var editSection: some View {
        Section("Community Details") {
            VStack(alignment: .leading, spacing: 4) {
                Text("Name").font(.caption).foregroundColor(.secondary)
                TextField("Community Name", text: $viewModel.name)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Description").font(.caption).foregroundColor(.secondary)
                TextEditor(text: $viewModel.description)
                    .frame(minHeight: 80)
            }

            Picker("Type", selection: $viewModel.selectedType) {
                ForEach(CommunityType.allCases, id: \.self) { type in
                    Label(type.displayName, systemImage: type.iconName)
                        .tag(type)
                }
            }
        }
    }

    // MARK: - Rules Section

    private var rulesSection: some View {
        Section("Rules") {
            VStack(alignment: .leading, spacing: 4) {
                Text("Define rules for your community members")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $viewModel.rules)
                    .frame(minHeight: 100)
            }
        }
    }

    // MARK: - Privacy Section

    private var privacySection: some View {
        Section("Privacy") {
            Picker("Visibility", selection: $viewModel.privacy) {
                HStack {
                    Image(systemName: "globe")
                    Text("Public")
                }
                .tag(CommunityPrivacy.PUBLIC)

                HStack {
                    Image(systemName: "lock")
                    Text("Private")
                }
                .tag(CommunityPrivacy.PRIVATE)

                HStack {
                    Image(systemName: "envelope")
                    Text("Invite Only")
                }
                .tag(CommunityPrivacy.INVITE_ONLY)
            }
            .pickerStyle(.inline)

            switch viewModel.privacy {
            case .PUBLIC:
                Text("Anyone can find and join this community")
                    .font(.caption)
                    .foregroundColor(.secondary)
            case .PRIVATE:
                Text("Visible in search but requires approval to join")
                    .font(.caption)
                    .foregroundColor(.secondary)
            case .INVITE_ONLY:
                Text("Hidden from search, members must be invited")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Cover Photo

    private var coverPhotoSection: some View {
        Section("Cover Photo") {
            VStack(spacing: 12) {
                if let image = viewModel.coverImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else if let url = viewModel.community?.coverPhotoUrl, let imgUrl = URL(string: url) {
                    AsyncImage(url: imgUrl) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle().fill(Color.neutral90)
                    }
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray6))
                        .frame(height: 140)
                        .overlay {
                            VStack(spacing: 6) {
                                Image(systemName: "photo")
                                    .font(.title2)
                                Text("No cover photo")
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }
                }

                PhotosPicker(selection: $viewModel.coverPhotoItem, matching: .images) {
                    Label("Change Cover Photo", systemImage: "camera")
                        .font(.subheadline)
                        .foregroundColor(.turquoise60)
                }
                .onChange(of: viewModel.coverPhotoItem) { _ in
                    viewModel.loadCoverImage()
                }
            }
        }
    }

    // MARK: - Tags

    private var tagsSection: some View {
        Section("Tags") {
            HStack {
                TextField("Add a tag...", text: $viewModel.tagInput)
                    .onSubmit { viewModel.addTag() }
                Button { viewModel.addTag() } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.turquoise60)
                }
                .disabled(viewModel.tagInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if !viewModel.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
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
    }

    // MARK: - Breed Section

    private var breedSection: some View {
        Section("Breed Filter") {
            TextField("Breed name (e.g. Labrador Retriever)", text: $viewModel.breedFilter)
        }
    }

    // MARK: - Danger Zone

    private var dangerZone: some View {
        Section {
            Button {
                viewModel.showArchiveAlert = true
            } label: {
                Label("Archive Community", systemImage: "archivebox")
                    .foregroundColor(.orange)
            }

            Button(role: .destructive) {
                viewModel.showDeleteAlert = true
            } label: {
                Label("Delete Community", systemImage: "trash")
            }
        } header: {
            Text("Danger Zone")
        } footer: {
            Text("Archiving hides the community but preserves data. Deletion is permanent and cannot be undone.")
        }
    }
}
