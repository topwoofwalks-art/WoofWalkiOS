import SwiftUI

struct DogProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showAddDogSheet = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    if let userProfile = viewModel.userProfile {
                        if userProfile.dogs.isEmpty {
                            emptyState
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(userProfile.dogs.map(DogProfile.init(from:))) { dog in
                                    NavigationLink(destination: DogDetailView(dog: dog)) {
                                        DogProfileCard(dog: dog)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    } else {
                        ProgressView()
                            .padding(.top, 100)
                    }
                }
                .padding()
            }
            .navigationTitle("My Dogs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddDogSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddDogSheet) {
                DogFormView(dog: nil) { dog in
                    viewModel.addDogProfile(dog: dog)
                    showAddDogSheet = false
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "pawprint.circle")
                .font(.system(size: 80))
                .foregroundColor(.gray)

            Text("No Dogs Yet")
                .font(.title2)
                .fontWeight(.bold)

            Text("Add your first dog to start tracking their walks and activities")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: { showAddDogSheet = true }) {
                Label("Add Dog", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct DogProfileCard: View {
    let dog: DogProfile

    var body: some View {
        HStack(spacing: 16) {
            if let photoUrl = dog.photoUrl, let url = URL(string: photoUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Text("\u{1F415}")
                        .font(.system(size: 40))
                }
                .frame(width: 70, height: 70)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 70, height: 70)
                    .overlay(
                        Text("\u{1F415}")
                            .font(.system(size: 40))
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(dog.name)
                    .font(.headline)
                    .fontWeight(.bold)

                if !dog.breed.isEmpty {
                    Text(dog.breed)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 12) {
                    Label("\(dog.age) years", systemImage: "birthday.cake")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(dog.temperament)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }

                if dog.nervousDog {
                    Label("Nervous Dog", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }
}

struct DogProfileView_Previews: PreviewProvider {
    static var previews: some View {
        DogProfileView()
    }
}
