import SwiftUI
import CoreLocation
import PhotosUI

struct AddPoiSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: PoiViewModel

    let location: CLLocationCoordinate2D

    init(location: CLLocationCoordinate2D) {
        self.location = location
        _viewModel = StateObject(wrappedValue: PoiViewModel(location: location))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Type")
                        .font(.headline)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(PoiType.allCases, id: \.self) { type in
                                PoiTypeChip(
                                    type: type,
                                    isSelected: viewModel.selectedType == type
                                ) {
                                    viewModel.selectedType = type
                                }
                            }
                        }
                    }

                    TextField("Title", text: $viewModel.title)
                        .textFieldStyle(.roundedBorder)

                    VStack(alignment: .leading) {
                        Text("Description")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        TextEditor(text: $viewModel.description)
                            .frame(height: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Photo (Optional)")
                            .font(.headline)

                        if let selectedImage = viewModel.selectedImage {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 200)
                                    .clipped()
                                    .cornerRadius(8)

                                Button {
                                    viewModel.selectedImage = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                                .padding(8)
                            }
                        } else {
                            HStack(spacing: 8) {
                                Button {
                                    viewModel.showingCamera = true
                                } label: {
                                    Label("Camera", systemImage: "camera")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)

                                PhotosPicker(
                                    selection: $viewModel.selectedPhotoItem,
                                    matching: .images
                                ) {
                                    Label("Gallery", systemImage: "photo")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Location")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(String(format: "%.6f, %.6f", location.latitude, location.longitude))
                            .font(.body)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    if let uploadProgress = viewModel.uploadProgress {
                        VStack(alignment: .leading) {
                            Text("Uploading photo... \(Int(uploadProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.blue)

                            ProgressView(value: uploadProgress)
                        }
                    }

                    if let error = viewModel.error {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    Button {
                        Task {
                            await viewModel.createPoi()
                            if viewModel.success {
                                dismiss()
                            }
                        }
                    } label: {
                        Text(viewModel.isLoading ? "Submitting..." : "Submit")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isLoading)
                }
                .padding()
            }
            .navigationTitle("Add Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingCamera) {
                CameraPicker(image: $viewModel.selectedImage)
            }
        }
    }
}

struct PoiTypeChip: View {
    let type: PoiType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: type.iconName)
                    .font(.system(size: 14))
                Text(type.displayName)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
