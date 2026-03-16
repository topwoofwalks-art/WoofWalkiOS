import SwiftUI
import PhotosUI

struct DogProfileSheet: View {
    let dog: DogProfile?
    let onDismiss: () -> Void
    let onSave: (DogProfile) -> Void

    @StateObject private var viewModel: DogProfileViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?

    init(dog: DogProfile?, onDismiss: @escaping () -> Void, onSave: @escaping (DogProfile) -> Void) {
        self.dog = dog
        self.onDismiss = onDismiss
        self.onSave = onSave
        self._viewModel = StateObject(wrappedValue: DogProfileViewModel(dog: dog))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    dogPhotoSection()

                    dogDetailsSection()

                    additionalInfoSection()

                    actionButtons()
                }
                .padding()
            }
            .navigationTitle(dog == nil ? "Add Dog" : "Edit Dog")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }

    private func dogPhotoSection() -> some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                if let photoUrl = viewModel.photoUrl, let url = URL(string: photoUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Text("🐕")
                            .font(.system(size: 40))
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 80, height: 80)
                        .overlay {
                            Text("🐕")
                                .font(.system(size: 40))
                        }
                }

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Image(systemName: "camera.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .background(Circle().fill(Color.white))
                }
            }

            HStack(spacing: 8) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    HStack {
                        Image(systemName: "camera")
                        Text("Camera")
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    HStack {
                        Image(systemName: "photo")
                        Text("Gallery")
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func dogDetailsSection() -> some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "pawprint.fill")
                        .foregroundColor(.gray)
                        .frame(width: 24)
                    TextField("Dog's name", text: $viewModel.name)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                if let error = viewModel.nameError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.leading, 32)
                }
            }

            HStack {
                Image(systemName: "list.bullet")
                    .foregroundColor(.gray)
                    .frame(width: 24)
                TextField("Breed (e.g., Golden Retriever)", text: $viewModel.breed)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.gray)
                    .frame(width: 24)
                TextField("Age (years)", text: $viewModel.age)
                    .keyboardType(.numberPad)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "heart")
                        .foregroundColor(.gray)
                        .frame(width: 24)
                    Text("Temperament")
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)

                Picker("Temperament", selection: $viewModel.temperament) {
                    ForEach(viewModel.temperaments, id: \.self) { temp in
                        Text(temp).tag(temp)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private func additionalInfoSection() -> some View {
        VStack(spacing: 12) {
            Toggle(isOn: $viewModel.nervousDog) {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(viewModel.nervousDog ? .orange : .gray)
                        .frame(width: 24)
                    Text("Nervous Dog")
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            if viewModel.nervousDog {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "note.text")
                            .foregroundColor(.gray)
                            .frame(width: 24)
                        Text("Warning Note")
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)

                    TextEditor(text: $viewModel.warningNote)
                        .frame(height: 80)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
            }
        }
    }

    private func actionButtons() -> some View {
        HStack(spacing: 12) {
            Button(action: onDismiss) {
                Text("Cancel")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button(action: saveDog) {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Save")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)
        }
        .padding(.top)
    }

    private func saveDog() {
        Task {
            do {
                try await viewModel.saveDog()

                let savedDog = DogProfile(
                    id: dog?.id ?? UUID().uuidString,
                    name: viewModel.name,
                    breed: viewModel.breed.isEmpty ? "Mixed" : viewModel.breed,
                    age: Int(viewModel.age) ?? 0,
                    photoUrl: viewModel.photoUrl,
                    temperament: viewModel.temperament,
                    nervousDog: viewModel.nervousDog,
                    warningNote: viewModel.warningNote.isEmpty ? nil : viewModel.warningNote
                )

                onSave(savedDog)
            } catch {
                print("Error saving dog: \(error)")
            }
        }
    }
}

struct DogProfileSheet_Previews: PreviewProvider {
    static var previews: some View {
        DogProfileSheet(dog: nil, onDismiss: {}, onSave: { _ in })
    }
}
