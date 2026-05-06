import SwiftUI
import PhotosUI

/// Owner/admin-only settings: name, description, rules, privacy, tags,
/// type-specific (breed filter / radius), cover photo change, moderation
/// entry button, and the destructive Archive / Delete actions (owner-only).
struct CommunitySettingsScreen: View {
    let community: Community
    @ObservedObject var viewModel: CommunityDetailViewModel

    @State private var name: String
    @State private var description: String
    @State private var rules: String
    @State private var privacy: CommunityPrivacy
    @State private var tags: [String]
    @State private var breedFilter: String
    @State private var radiusKm: Double

    @State private var photosItem: PhotosPickerItem?
    @State private var newCoverPreview: UIImage?

    @State private var showArchiveConfirm: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var isSaving: Bool = false
    @State private var saveError: String?
    @State private var showModeration: Bool = false

    @Environment(\.dismiss) private var dismiss

    init(community: Community, viewModel: CommunityDetailViewModel) {
        self.community = community
        self.viewModel = viewModel
        _name = State(initialValue: community.name)
        _description = State(initialValue: community.description)
        _rules = State(initialValue: community.rules)
        _privacy = State(initialValue: community.privacy)
        _tags = State(initialValue: community.tags)
        _breedFilter = State(initialValue: community.breedFilter ?? "")
        _radiusKm = State(initialValue: community.radiusKm ?? 5)
    }

    var body: some View {
        Form {
            Section(header: Text("Basics")) {
                TextField("Name", text: $name)
                TextField("Description", text: $description, axis: .vertical)
                    .lineLimit(2...6)
                TextField("Rules", text: $rules, axis: .vertical)
                    .lineLimit(2...8)
            }

            Section(header: Text("Privacy")) {
                Picker("Visibility", selection: $privacy) {
                    ForEach(CommunityPrivacy.allCases) { p in
                        Text(p.displayName).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                Text(privacy.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("Tags")) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text(tag)
                                Button { tags.removeAll { $0 == tag } } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.15))
                            .clipShape(Capsule())
                        }
                    }
                }
                AddTagField { newTag in
                    if !tags.contains(newTag) { tags.append(newTag) }
                }
            }

            // Type-specific fields are conditional: Local needs radius, Breed
            // needs breedFilter.
            if community.type == .breedSpecific {
                Section(header: Text("Breed filter")) {
                    TextField("Primary breed", text: $breedFilter)
                }
            }
            if community.type == .localNeighbourhood {
                Section(header: Text("Radius")) {
                    HStack {
                        Slider(value: $radiusKm, in: 1...50, step: 1)
                        Text("\(Int(radiusKm)) km").foregroundColor(.secondary)
                    }
                }
            }

            Section(header: Text("Cover photo")) {
                if let preview = newCoverPreview {
                    Image(uiImage: preview)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else if let urlStr = community.coverPhotoUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            Color.secondary.opacity(0.15)
                        }
                    }
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                PhotosPicker(selection: $photosItem, matching: .images) {
                    Label("Change cover photo", systemImage: "photo")
                }
                .onChange(of: photosItem) { newItem in
                    guard let newItem else { return }
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                           let img = UIImage(data: data) {
                            newCoverPreview = img
                            await viewModel.uploadCoverPhoto(imageData: data)
                        }
                    }
                }
            }

            if let myRole = viewModel.myRole, myRole.canModerate {
                Section {
                    Button {
                        showModeration = true
                    } label: {
                        Label("Moderation", systemImage: "shield")
                    }
                }
            }

            if let myRole = viewModel.myRole, myRole.isOwner {
                Section(header: Text("Danger zone")) {
                    Button {
                        showArchiveConfirm = true
                    } label: {
                        Label("Archive community", systemImage: "archivebox")
                            .foregroundColor(.orange)
                    }
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete community", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Save").fontWeight(.semibold)
                    }
                }
                .disabled(isSaving)
            }
        }
        .navigationDestination(isPresented: $showModeration) {
            CommunityModerationScreen(communityId: community.id ?? "")
        }
        .alert("Archive community?", isPresented: $showArchiveConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Archive", role: .destructive) {
                Task {
                    await viewModel.archiveCommunity()
                    dismiss()
                }
            }
        } message: {
            Text("It'll be hidden from search and discovery. Members can still read existing content.")
        }
        .alert("Delete community?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteCommunity()
                    dismiss()
                }
            }
        } message: {
            Text("This permanently removes posts, members, events, and chat. Cannot be undone.")
        }
        .alert("Error", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK") { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        var updates: [String: Any] = [
            "name": name,
            "description": description,
            "rules": rules,
            "privacy": privacy.rawValue,
            "tags": tags
        ]
        if community.type == .breedSpecific {
            updates["breedFilter"] = breedFilter
        }
        if community.type == .localNeighbourhood {
            updates["radiusKm"] = radiusKm
        }
        do {
            try await CommunityRepository.shared.updateCommunity(communityId: community.id ?? "", updates: updates)
        } catch {
            saveError = error.localizedDescription
        }
    }
}

// MARK: - Tag add field

private struct AddTagField: View {
    @State private var entry: String = ""
    let onAdd: (String) -> Void

    var body: some View {
        HStack {
            TextField("Add a tag", text: $entry)
            Button {
                let t = entry.trimmingCharacters(in: .whitespaces)
                if !t.isEmpty { onAdd(t); entry = "" }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
    }
}
