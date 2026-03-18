import SwiftUI

struct WalkPhotoGalleryScreen: View {
    let walkId: String
    @State private var photos: [WalkPhoto] = []
    @State private var selectedPhoto: WalkPhoto?
    @State private var isLoading = true

    private let columns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4)
    ]

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if photos.isEmpty {
                emptyState
            } else {
                photoGrid
            }
        }
        .navigationTitle("Walk Photos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !photos.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: "Check out my walk on WoofWalk!") {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(item: $selectedPhoto) { photo in
            fullScreenPhoto(photo)
        }
        .onAppear { loadPhotos() }
    }

    // MARK: - Photo Grid

    private var photoGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(photos) { photo in
                    Button { selectedPhoto = photo } label: {
                        AsyncImage(url: URL(string: photo.url)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color(.systemGray5)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.secondary)
                                )
                        }
                        .frame(minHeight: 120)
                        .clipped()
                    }
                }
            }
            .padding(4)
        }
    }

    // MARK: - Full Screen Photo

    private func fullScreenPhoto(_ photo: WalkPhoto) -> some View {
        NavigationStack {
            VStack(spacing: 0) {
                AsyncImage(url: URL(string: photo.url)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    ProgressView()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)

                VStack(alignment: .leading, spacing: 8) {
                    if let date = photo.date {
                        Label(date, systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let location = photo.locationName {
                        Label(location, systemImage: "mappin.and.ellipse")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemBackground))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { selectedPhoto = nil }
                }
                ToolbarItem(placement: .topBarLeading) {
                    ShareLink(item: photo.url) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("No Photos")
                .font(.title2.bold())
            Text("No photos from this walk yet.\nTap the camera button during a walk to capture moments.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    // MARK: - Load

    private func loadPhotos() {
        // Simulate loading delay then show empty state
        // Real implementation would fetch from Firestore walk/{walkId}/photos
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLoading = false
        }
    }
}

// MARK: - Walk Photo Model

struct WalkPhoto: Identifiable {
    let id: String
    let url: String
    let date: String?
    let locationName: String?
}

struct WalkPhotoGalleryScreen_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            WalkPhotoGalleryScreen(walkId: "preview-walk")
        }
    }
}
