import SwiftUI

struct DogDetailView: View {
    let dog: DogProfile
    var isOwner: Bool = true
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                dogPhotoHeader

                dogInfoCard

                walkHistorySection

                if isOwner {
                    actionsSection
                }
            }
            .padding()
        }
        .navigationTitle(dog.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isOwner {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showEditSheet = true }) {
                        Text("Edit")
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            DogFormView(dog: dog) { updatedDog in
                viewModel.updateDogProfile(dogId: dog.id, dog: updatedDog)
                showEditSheet = false
            }
        }
        .alert("Delete \(dog.name)?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.removeDogProfile(dogId: dog.id)
                dismiss()
            }
        } message: {
            Text("This will permanently delete \(dog.name) and all associated data. This action cannot be undone.")
        }
    }

    private var dogPhotoHeader: some View {
        VStack(spacing: 16) {
            if let photoUrl = dog.photoUrl, let url = URL(string: photoUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Text("\u{1F415}")
                        .font(.system(size: 80))
                }
                .frame(width: 150, height: 150)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.blue, lineWidth: 3)
                )
            } else {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 150, height: 150)
                    .overlay(
                        Text("\u{1F415}")
                            .font(.system(size: 80))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.blue, lineWidth: 3)
                    )
            }

            Text(dog.name)
                .font(.title)
                .fontWeight(.bold)

            if dog.nervousDog {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Nervous Dog")
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(20)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    private var dogInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.headline)
                .fontWeight(.bold)

            VStack(spacing: 12) {
                InfoRow(icon: "list.bullet", label: "Breed", value: dog.breed.isEmpty ? "Mixed" : dog.breed)
                InfoRow(icon: "birthday.cake", label: "Age", value: "\(dog.age) years")
                InfoRow(icon: "heart.fill", label: "Temperament", value: dog.temperament)

                if let warningNote = dog.warningNote, !warningNote.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "note.text")
                                .foregroundColor(.orange)
                            Text("Warning Note")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }

                        Text(warningNote)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    private var walkHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Walk History")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text("Coming Soon")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 12) {
                WalkStatRow(icon: "figure.walk", label: "Total Walks", value: "0")
                WalkStatRow(icon: "map", label: "Total Distance", value: "0.0 km")
                WalkStatRow(icon: "clock", label: "Total Time", value: "0h")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button(action: { showEditSheet = true }) {
                HStack {
                    Image(systemName: "pencil")
                    Text("Edit Profile")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button(action: { showDeleteAlert = true }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Dog")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }
}

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
    }
}

struct WalkStatRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct DogDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DogDetailView(dog: DogProfile(
                id: "1",
                name: "Max",
                breed: "Golden Retriever",
                age: 3,
                temperament: "Friendly",
                nervousDog: false
            ))
        }
    }
}
