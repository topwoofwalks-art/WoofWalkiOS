import SwiftUI
import PhotosUI

struct PhotoMessagePicker: View {
    @Binding var selectedImage: UIImage?
    @State private var photoItem: PhotosPickerItem?
    @State private var showPreview = false
    let onSend: (UIImage) -> Void

    var body: some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                Image(systemName: "photo.on.rectangle")
                    .font(.title3)
                    .foregroundColor(.turquoise60)
            }
            .onChange(of: photoItem) { newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                        showPreview = true
                    }
                    photoItem = nil
                }
            }

            Button(action: {
                // Camera - future implementation
            }) {
                Image(systemName: "camera.fill")
                    .font(.title3)
                    .foregroundColor(.turquoise60)
            }
        }
        .sheet(isPresented: $showPreview) {
            if let image = selectedImage {
                PhotoPreviewSheet(image: image) {
                    onSend(image)
                    selectedImage = nil
                    showPreview = false
                } onCancel: {
                    selectedImage = nil
                    showPreview = false
                }
            }
        }
    }
}

// MARK: - Photo Preview Sheet

struct PhotoPreviewSheet: View {
    let image: UIImage
    let onSend: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Spacer()
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()
                Spacer()

                Button(action: onSend) {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                        Text("Send Photo")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.turquoise60)
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
}
