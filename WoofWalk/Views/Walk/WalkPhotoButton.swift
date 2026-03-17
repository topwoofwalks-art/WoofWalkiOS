import SwiftUI
import UIKit
import CoreLocation

/// Floating camera button shown during active walks.
/// Presents the device camera for photo capture and displays a badge
/// with the number of photos taken during the current walk.
struct WalkPhotoButton: View {
    /// Current user location to tag photos with coordinates.
    let currentLocation: CLLocation?
    /// Callback invoked with the captured image and its location.
    let onPhotoTaken: (UIImage, CLLocation?) -> Void

    @State private var photoCount: Int = 0
    @State private var showCamera: Bool = false

    var body: some View {
        Button {
            showCamera = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color(red: 0, green: 0.627, blue: 0.690))) // #00A0B0
                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)

                if photoCount > 0 {
                    Text("\(photoCount)")
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Circle().fill(.red))
                        .offset(x: 4, y: -4)
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraPickerView { image in
                photoCount += 1
                onPhotoTaken(image, currentLocation)
            }
            .ignoresSafeArea()
        }
    }

    /// Reset the photo count (e.g. when a new walk starts).
    mutating func resetCount() {
        photoCount = 0
    }
}

// MARK: - Camera Picker

/// Thin UIKit wrapper around `UIImagePickerController` configured for camera capture.
private struct CameraPickerView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageCaptured: onImageCaptured, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImageCaptured: (UIImage) -> Void
        let dismiss: DismissAction

        init(onImageCaptured: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImageCaptured = onImageCaptured
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImageCaptured(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
