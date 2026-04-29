import SwiftUI
import PhotosUI
import FirebaseAuth
import FirebaseFirestore

/// Gallery section rendered on `DogDetailView` for dogs the viewer
/// owns. Displays `UnifiedDog.photoUrls[]` as a horizontal carousel
/// with an "add photo" tile and long-press-to-delete.
///
/// Uploads go through `DogProfileViewModel.uploadGalleryPhoto` which
/// already sanitises EXIF, resizes, and sets the `uploadedBy` metadata
/// required by the tightened `/dogProfiles/{uid}/{dogId}/gallery`
/// Storage rule.
struct DogGallerySection: View {
    let dogId: String
    @Binding var photoUrls: [String]
    var isOwner: Bool = true

    @State private var selectedItem: PhotosPickerItem?
    @State private var isUploading = false
    @State private var uploadError: String?
    @State private var confirmDelete: String?

    private let viewModel: DogProfileViewModel

    @MainActor
    init(dogId: String, photoUrls: Binding<[String]>, isOwner: Bool = true) {
        self.dogId = dogId
        self._photoUrls = photoUrls
        self.isOwner = isOwner
        // Build a VM scoped to the dog being viewed so `uploadGalleryPhoto`
        // knows which dog the upload belongs to. DogProfileViewModel is
        // @MainActor-isolated, so the init has to match.
        self.viewModel = DogProfileViewModel(
            dog: UnifiedDog(id: dogId)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Gallery")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text("\(photoUrls.count) photo\(photoUrls.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if photoUrls.isEmpty && !isOwner {
                Text("No additional photos.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        if isOwner {
                            addPhotoTile
                        }
                        ForEach(photoUrls, id: \.self) { url in
                            galleryTile(url: url)
                        }
                    }
                }
            }

            if let err = uploadError {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
        .onChange(of: selectedItem) { newItem in
            guard let newItem = newItem else { return }
            Task { await handleUpload(item: newItem) }
        }
        .alert("Remove photo?", isPresented: Binding(
            get: { confirmDelete != nil },
            set: { if !$0 { confirmDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { confirmDelete = nil }
            Button("Remove", role: .destructive) {
                if let url = confirmDelete {
                    Task { await handleDelete(url: url) }
                }
                confirmDelete = nil
            }
        } message: {
            Text("This photo will be permanently deleted.")
        }
    }

    private var addPhotoTile: some View {
        PhotosPicker(
            selection: $selectedItem,
            matching: .images,
            photoLibrary: .shared()
        ) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue, style: StrokeStyle(lineWidth: 1, dash: [4]))
                    )
                if isUploading {
                    ProgressView()
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                        Text("Add photo")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .disabled(isUploading)
    }

    private func galleryTile(url: String) -> some View {
        let asUrl = URL(string: url)
        return ZStack {
            if let asUrl = asUrl {
                AsyncImage(url: asUrl) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
                .frame(width: 100, height: 100)
                .clipped()
                .cornerRadius(12)
            } else {
                Color.gray.opacity(0.2)
                    .frame(width: 100, height: 100)
                    .cornerRadius(12)
            }
        }
        .contextMenu {
            if isOwner {
                Button(role: .destructive) {
                    confirmDelete = url
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Actions

    @MainActor
    private func handleUpload(item: PhotosPickerItem) async {
        uploadError = nil
        isUploading = true
        defer {
            isUploading = false
            selectedItem = nil
        }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                uploadError = "Could not load selected photo"
                return
            }
            let result = try await viewModel.uploadGalleryPhoto(imageData: data)
            // Append the new URL to the local binding so the UI updates
            // immediately; the Firestore dog doc is updated separately by
            // the caller writing the dog record (or by a future
            // `DogRepository.addGalleryPhoto` method).
            await appendGalleryUrl(result.url)
        } catch {
            uploadError = "Upload failed: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func handleDelete(url: String) async {
        uploadError = nil
        photoUrls.removeAll { $0 == url }
        await persistGalleryUrls()
        // Fire-and-forget Storage delete — the Firestore dog doc is
        // the source of truth. Storage object orphan is a minor cost;
        // janitor could sweep later.
        if let photoId = extractPhotoId(from: url) {
            do {
                let ref = "dogProfiles/\(Auth.auth().currentUser?.uid ?? "_")/\(dogId)/gallery/\(photoId).jpg"
                try await FirebaseService.shared.deleteFile(path: ref)
            } catch {
                // Non-fatal: Firestore write succeeded, that's what matters.
            }
        }
    }

    @MainActor
    private func appendGalleryUrl(_ url: String) async {
        photoUrls.append(url)
        await persistGalleryUrls()
    }

    private func persistGalleryUrls() async {
        do {
            let db = Firestore.firestore()
            try await db.collection("dogs").document(dogId).updateData([
                "photoUrls": photoUrls,
                "updatedAt": Int64(Date().timeIntervalSince1970 * 1000)
            ])
        } catch {
            print("[DogGallerySection] persist failed: \(error.localizedDescription)")
        }
    }

    private func extractPhotoId(from url: String) -> String? {
        // URL form is typically
        // https://.../dogProfiles%2F{uid}%2F{dogId}%2Fgallery%2F{photoId}.jpg?...
        let pattern = "gallery(?:%2F|/)([^?.]+)\\.jpg"
        if let range = url.range(of: pattern, options: .regularExpression) {
            let match = String(url[range])
            let cleaned = match
                .replacingOccurrences(of: "gallery%2F", with: "")
                .replacingOccurrences(of: "gallery/", with: "")
                .replacingOccurrences(of: ".jpg", with: "")
            return cleaned.isEmpty ? nil : cleaned
        }
        return nil
    }
}

