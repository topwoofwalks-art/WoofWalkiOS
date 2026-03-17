import SwiftUI
import PhotosUI

struct DogFormView: View {
    @Environment(\.dismiss) var dismiss
    let dog: DogProfile?
    let onSave: (DogProfile) -> Void

    @State private var name: String = ""
    @State private var breed: String = ""
    @State private var age: String = ""
    @State private var temperament: String = "Friendly"
    @State private var nervousDog: Bool = false
    @State private var warningNote: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var nameError: String?

    let temperamentOptions = ["Friendly", "Shy", "Energetic", "Calm", "Playful", "Protective"]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    dogPhotoSection()

                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "pawprint.fill")
                                    .foregroundColor(.gray)
                                    .frame(width: 24)
                                TextField("Name", text: $name)
                                    .onChange(of: name) { _ in
                                        nameError = nil
                                    }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(nameError != nil ? Color.red : Color.clear, lineWidth: 1)
                            )

                            if let error = nameError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }

                        HStack {
                            Image(systemName: "list.bullet")
                                .foregroundColor(.gray)
                                .frame(width: 24)
                            TextField("Breed (e.g., Golden Retriever)", text: $breed)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                        HStack {
                            Image(systemName: "birthday.cake")
                                .foregroundColor(.gray)
                                .frame(width: 24)
                            TextField("Age (years)", text: $age)
                                .keyboardType(.numberPad)
                                .onChange(of: age) { newValue in
                                    age = newValue.filter { $0.isNumber }
                                }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Temperament")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Menu {
                                ForEach(temperamentOptions, id: \.self) { option in
                                    Button(option) {
                                        temperament = option
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "heart.fill")
                                        .foregroundColor(.gray)
                                        .frame(width: 24)
                                    Text(temperament)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                        }

                        Toggle(isOn: $nervousDog) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .frame(width: 24)
                                Text("Nervous Dog")
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                        if nervousDog {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Warning Note (Optional)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                HStack(alignment: .top) {
                                    Image(systemName: "note.text")
                                        .foregroundColor(.gray)
                                        .frame(width: 24)
                                        .padding(.top, 8)
                                    TextEditor(text: $warningNote)
                                        .frame(height: 80)
                                        .scrollContentBackground(.hidden)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(dog == nil ? "Add Dog Profile" : "Edit Dog Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveDog()
                    }
                }
            }
            .onAppear {
                if let dog = dog {
                    name = dog.name
                    breed = dog.breed
                    age = "\(dog.age)"
                    temperament = dog.temperament
                    nervousDog = dog.nervousDog
                    warningNote = dog.warningNote ?? ""
                }
            }
        }
    }

    private func dogPhotoSection() -> some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                if let photoUrl = dog?.photoUrl, let url = URL(string: photoUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Text("\u{1F415}")
                            .font(.system(size: 50))
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .background(Circle().fill(Color(.systemGray5)))
                } else {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Text("\u{1F415}")
                                .font(.system(size: 50))
                        )
                }

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Image(systemName: "camera.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .background(Circle().fill(Color.white))
                }
            }

            HStack(spacing: 12) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Camera", systemImage: "camera")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Gallery", systemImage: "photo")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    private func saveDog() {
        guard !name.isEmpty else {
            nameError = "Name is required"
            return
        }

        let dogProfile = DogProfile(
            id: dog?.id ?? UUID().uuidString,
            name: name,
            breed: breed.isEmpty ? "Mixed" : breed,
            age: Int(age) ?? 0,
            photoUrl: dog?.photoUrl,
            temperament: temperament,
            nervousDog: nervousDog,
            warningNote: warningNote.isEmpty ? nil : warningNote
        )

        onSave(dogProfile)
        dismiss()
    }
}

// DogProfileSheet is defined in DogProfileSheet.swift

struct DogFormView_Previews: PreviewProvider {
    static var previews: some View {
        DogFormView(dog: nil) { _ in }
    }
}
