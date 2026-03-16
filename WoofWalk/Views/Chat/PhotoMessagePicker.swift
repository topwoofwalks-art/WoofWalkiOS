import SwiftUI
import PhotosUI

struct PhotoMessagePicker: View {
    @Binding var selectedImage: UIImage?
    @State private var photoItem: PhotosPickerItem?
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
                    }
                }
            }

            Button(action: {
                // Camera
            }) {
                Image(systemName: "camera.fill")
                    .font(.title3)
                    .foregroundColor(.turquoise60)
            }
        }
    }
}
