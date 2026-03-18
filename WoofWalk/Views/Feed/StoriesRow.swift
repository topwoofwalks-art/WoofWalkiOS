import SwiftUI
import PhotosUI

struct StoriesRow: View {
    @ObservedObject var viewModel: StoryViewModel
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var showCaptionSheet = false

    private let brandColor = Color(red: 0/255, green: 160/255, blue: 176/255)
    private let storyGradient = LinearGradient(
        colors: [Color(red: 222/255, green: 0/255, blue: 70/255), Color(red: 247/255, green: 163/255, blue: 75/255)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    private let seenGradient = LinearGradient(
        colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.4)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // "Your Story" button
                yourStoryButton

                // Other users' stories
                ForEach(viewModel.storyGroups) { group in
                    storyCircle(group: group)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showImagePicker) {
            StoryImagePicker(image: $selectedImage)
        }
        .sheet(isPresented: $showCaptionSheet) {
            if let image = selectedImage {
                StoryCaptionSheet(
                    image: image,
                    isCreating: viewModel.isCreating,
                    onPost: { caption in
                        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
                        viewModel.createStory(imageData: data, caption: caption)
                        showCaptionSheet = false
                        selectedImage = nil
                    },
                    onCancel: {
                        showCaptionSheet = false
                        selectedImage = nil
                    }
                )
            }
        }
        .onChange(of: selectedImage) { newImage in
            if newImage != nil {
                showCaptionSheet = true
            }
        }
        .fullScreenCover(isPresented: $viewModel.showViewer) {
            StoryViewerSheet(viewModel: viewModel)
        }
    }

    // MARK: - Your Story Button

    private var yourStoryButton: some View {
        Button {
            showImagePicker = true
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .bottomTrailing) {
                    if viewModel.currentUserHasStory {
                        // Has active story - show with gradient ring
                        Circle()
                            .stroke(storyGradient, lineWidth: 2)
                            .frame(width: 64, height: 64)
                            .overlay(
                                Circle()
                                    .fill(brandColor.opacity(0.15))
                                    .padding(3)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.title2)
                                            .foregroundColor(brandColor)
                                    )
                            )
                    } else {
                        Circle()
                            .fill(brandColor.opacity(0.15))
                            .frame(width: 64, height: 64)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.title2)
                                    .foregroundColor(brandColor)
                            )
                    }

                    Circle()
                        .fill(brandColor)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.caption2.bold())
                                .foregroundColor(.white)
                        )
                        .offset(x: 2, y: 2)
                }

                Text("Your Story")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 68)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Story Circle

    private func storyCircle(group: StoryGroup) -> some View {
        Button {
            viewModel.openStoryGroup(userId: group.userId)
        } label: {
            VStack(spacing: 4) {
                Circle()
                    .stroke(group.hasUnviewed ? storyGradient : seenGradient, lineWidth: 2)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Group {
                            if let avatarUrl = group.userAvatar, let url = URL(string: avatarUrl) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    default:
                                        Image(systemName: "person.fill")
                                            .font(.title2)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .clipShape(Circle())
                                .padding(3)
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .padding(3)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.title2)
                                            .foregroundColor(.gray.opacity(0.6))
                                    )
                            }
                        }
                    )

                Text(group.userName.components(separatedBy: " ").first ?? group.userName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 68)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Image Picker (PHPicker)

struct StoryImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: StoryImagePicker

        init(_ parent: StoryImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()

            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }

            provider.loadObject(ofClass: UIImage.self) { image, _ in
                DispatchQueue.main.async {
                    self.parent.image = image as? UIImage
                }
            }
        }
    }
}

// MARK: - Caption Sheet

struct StoryCaptionSheet: View {
    let image: UIImage
    let isCreating: Bool
    let onPost: (String) -> Void
    let onCancel: () -> Void

    @State private var caption = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()

                TextField("Add a caption...", text: $caption)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("New Story")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onPost(caption)
                    } label: {
                        if isCreating {
                            ProgressView()
                        } else {
                            Text("Share")
                                .bold()
                        }
                    }
                    .disabled(isCreating)
                }
            }
        }
        .interactiveDismissDisabled(isCreating)
    }
}
