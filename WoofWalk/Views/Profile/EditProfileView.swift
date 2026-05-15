import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: ProfileViewModel

    @State private var displayName: String = ""
    @State private var bio: String = ""
    @State private var phone: String = ""
    @State private var addressLine1: String = ""
    @State private var addressLine2: String = ""
    @State private var addressCity: String = ""
    @State private var addressPostcode: String = ""
    @State private var addressCountry: String = "GB"
    @State private var showDogSheet = false
    @State private var editingDog: DogProfile?
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    profilePhotoSection()

                    basicInformationSection()

                    addressSection()

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
                    // Prefer displayName; fall back to legacy username so
                    // legacy users still see a populated field.
                    displayName = user.displayName?.isEmpty == false
                        ? (user.displayName ?? "")
                        : user.username
                    bio = user.bio
                    phone = user.phone ?? ""
                    if let a = user.address {
                        addressLine1 = a.line1
                        addressLine2 = a.line2
                        addressCity = a.city
                        addressPostcode = a.postcode
                        addressCountry = a.country.isEmpty ? "GB" : a.country
                    }
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
                    TextField("Display name", text: $displayName)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                HStack {
                    Image(systemName: "phone")
                        .foregroundColor(.gray)
                        .frame(width: 24)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
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

    private func addressSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Address")
                .font(.headline)
            Text("Helps providers find you and us match you with services nearby. Visible only to providers you book with.")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                TextField("Address line 1", text: $addressLine1)
                    .textContentType(.streetAddressLine1)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                TextField("Address line 2 (optional)", text: $addressLine2)
                    .textContentType(.streetAddressLine2)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                HStack(spacing: 12) {
                    TextField("City", text: $addressCity)
                        .textContentType(.addressCity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                    TextField("Postcode", text: $addressPostcode)
                        .textContentType(.postalCode)
                        .autocapitalization(.allCharacters)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
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

            if let publicDogs = viewModel.userProfile?.dogs, !publicDogs.isEmpty {
                ForEach(publicDogs.map(DogProfile.init(from:))) { dog in
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
        // Send the address as a structured value iff at least one core
        // line is non-empty. nil means "no change" — preserves existing
        // value when the user only edited name/bio/phone.
        let addressDirty = !addressLine1.isEmpty || !addressCity.isEmpty || !addressPostcode.isEmpty
        let addressArg: PostalAddress? = addressDirty
            ? PostalAddress(
                line1: addressLine1.trimmingCharacters(in: .whitespaces),
                line2: addressLine2.trimmingCharacters(in: .whitespaces),
                city: addressCity.trimmingCharacters(in: .whitespaces),
                postcode: addressPostcode.trimmingCharacters(in: .whitespaces),
                country: addressCountry.trimmingCharacters(in: .whitespaces).isEmpty
                    ? "GB" : addressCountry.trimmingCharacters(in: .whitespaces)
            )
            : nil

        viewModel.updateProfile(
            displayName: displayName.isEmpty ? nil : displayName,
            bio: bio.isEmpty ? nil : bio,
            phone: phone.trimmingCharacters(in: .whitespaces).isEmpty
                ? nil : phone.trimmingCharacters(in: .whitespaces),
            address: addressArg
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
