import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: ProfileViewModel

    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var showDogSheet = false
    @State private var editingDog: DogProfile?
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    profilePhotoSection()

                    basicInformationSection()

                    myDogsSection()
                }
                .padding()
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                    }
                }
            }
            .sheet(isPresented: $showDogSheet) {
                UnifiedDogFormView(dog: editingDog) { dog in
                    if editingDog != nil {
                        viewModel.updateDogProfile(dogId: dog.id, dog: dog)
                    } else {
                        viewModel.addDogProfile(dog: dog)
                    }
                }
            }
            .onAppear {
                if let user = viewModel.userProfile {
                    username = user.username
                }
            }
        }
    }

    private func profilePhotoSection() -> some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                if let user = viewModel.userProfile,
                   let photoUrl = user.photoUrl,
                   let url = URL(string: photoUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundColor(.gray)
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(.gray)
                        .frame(width: 100, height: 100)
                }

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Image(systemName: "camera.circle.fill")
                        .font(.title)
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

    private func basicInformationSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Basic Information")
                .font(.headline)

            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "person")
                        .foregroundColor(.gray)
                        .frame(width: 24)
                    TextField("Username", text: $username)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                HStack(alignment: .top) {
                    Image(systemName: "text.alignleft")
                        .foregroundColor(.gray)
                        .frame(width: 24)
                        .padding(.top, 8)
                    TextEditor(text: $bio)
                        .frame(height: 80)
                        .scrollContentBackground(.hidden)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    private func myDogsSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("My Dogs")
                    .font(.headline)

                Spacer()

                Button(action: {
                    editingDog = nil
                    showDogSheet = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }

            if let dogs = viewModel.userProfile?.dogs, !dogs.isEmpty {
                ForEach(dogs) { dog in
                    DogListItem(
                        dog: dog,
                        onEdit: {
                            editingDog = dog
                            showDogSheet = true
                        },
                        onDelete: {
                            viewModel.removeDogProfile(dogId: dog.id)
                        }
                    )
                }
            } else {
                Text("No dogs added yet")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    private func saveProfile() {
        viewModel.updateProfile(
            username: username.isEmpty ? nil : username,
            bio: bio.isEmpty ? nil : bio
        )
        dismiss()
    }
}

struct DogListItem: View {
    let dog: DogProfile
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        HStack(spacing: 12) {
            if let photoUrl = dog.photoUrl, let url = URL(string: photoUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Text("🐕")
                        .font(.title)
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
            } else {
                Text("🐕")
                    .font(.title)
                    .frame(width: 48, height: 48)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(dog.name)
                    .font(.body)
                    .fontWeight(.semibold)

                Text("\(dog.breed) • \(dog.age) years")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.borderless)

                Button(action: { showDeleteConfirm = true }) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .alert("Delete \(dog.name)?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }
}

struct EditProfileView_Previews: PreviewProvider {
    static var previews: some View {
        EditProfileView(viewModel: ProfileViewModel())
    }
}
