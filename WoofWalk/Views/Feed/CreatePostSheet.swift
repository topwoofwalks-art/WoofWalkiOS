import SwiftUI
import PhotosUI
import CoreLocation

struct CreatePostSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var feedViewModel: FeedViewModel
    @State private var text = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var selectedImagePreview: UIImage?
    @State private var locationTag: String?
    @State private var isLoadingLocation = false
    @State private var isPosting = false
    @State private var errorMessage: String?
    let onPost: (String, String?) -> Void

    private let charLimit = 500

    private var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var canPost: Bool {
        !trimmedText.isEmpty && trimmedText.count <= charLimit && !isPosting
    }

    private var hasLinkError: Bool {
        feedViewModel.containsLink(trimmedText)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // Text editor
                        TextEditor(text: $text)
                            .frame(minHeight: 120)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .onChange(of: text) { newValue in
                                // Clear link error when text changes
                                if errorMessage != nil && !feedViewModel.containsLink(newValue) {
                                    errorMessage = nil
                                }
                            }

                        // Character counter
                        HStack {
                            if hasLinkError {
                                Label("Links aren't allowed -- keep it genuine!", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }

                            Spacer()

                            Text("\(trimmedText.count)/\(charLimit)")
                                .font(.caption)
                                .foregroundColor(trimmedText.count > charLimit ? .red : .secondary)
                        }

                        // Photo preview
                        if let preview = selectedImagePreview {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: preview)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxHeight: 200)
                                    .clipped()
                                    .cornerRadius(12)

                                Button {
                                    selectedPhotoItem = nil
                                    selectedImageData = nil
                                    selectedImagePreview = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .shadow(radius: 2)
                                }
                                .padding(8)
                            }
                        }

                        // Location tag
                        if let tag = locationTag {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.turquoise60)
                                Text(tag)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Spacer()

                                Button {
                                    locationTag = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.turquoise60.opacity(0.08))
                            )
                        }

                        // Error message
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding()
                }

                Divider()

                // Bottom toolbar: photo picker + location
                HStack(spacing: 20) {
                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.title3)
                            .foregroundColor(.turquoise60)
                    }
                    .onChange(of: selectedPhotoItem) { newItem in
                        loadPhoto(from: newItem)
                    }

                    Button {
                        fetchLocationTag()
                    } label: {
                        if isLoadingLocation {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: locationTag != nil ? "mappin.circle.fill" : "mappin.circle")
                                .font(.title3)
                                .foregroundColor(.turquoise60)
                        }
                    }
                    .disabled(isLoadingLocation)

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isPosting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isPosting {
                        ProgressView()
                    } else {
                        Button("Post") {
                            submitPost()
                        }
                        .disabled(!canPost || hasLinkError)
                        .fontWeight(.bold)
                        .foregroundColor(.turquoise60)
                    }
                }
            }
            .interactiveDismissDisabled(isPosting)
        }
    }

    // MARK: - Actions

    private func submitPost() {
        let content = trimmedText

        // Anti-spam: reject posts containing URLs
        if feedViewModel.containsLink(content) {
            errorMessage = "Links aren't allowed in posts -- keep it genuine!"
            return
        }

        if content.count > charLimit {
            errorMessage = "Post exceeds the \(charLimit) character limit."
            return
        }

        isPosting = true
        errorMessage = nil

        if let imageData = selectedImageData {
            // Post with image upload
            Task {
                do {
                    try await feedViewModel.createPostWithImage(
                        text: content,
                        imageData: imageData,
                        locationTag: locationTag
                    )
                    dismiss()
                } catch {
                    errorMessage = "Failed to create post: \(error.localizedDescription)"
                    isPosting = false
                }
            }
        } else {
            // Text-only post
            onPost(content, nil)
            dismiss()
        }
    }

    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                selectedImageData = data
                selectedImagePreview = UIImage(data: data)
            }
        }
    }

    private func fetchLocationTag() {
        guard locationTag == nil else {
            // Toggle off
            locationTag = nil
            return
        }

        guard let coord = LocationService.shared.currentLocation else {
            errorMessage = "Location not available. Enable location services to tag your post."
            return
        }

        isLoadingLocation = true
        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                isLoadingLocation = false
                if let placemark = placemarks?.first {
                    let parts = [placemark.locality, placemark.administrativeArea].compactMap { $0 }
                    locationTag = parts.isEmpty ? "Unknown location" : parts.joined(separator: ", ")
                } else {
                    errorMessage = "Could not determine location name."
                }
            }
        }
    }
}
