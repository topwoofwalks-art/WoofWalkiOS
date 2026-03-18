import SwiftUI
import FirebaseFirestore

struct PublicProfileScreen: View {
    let userId: String
    @State private var user: UserProfile?
    @State private var isLoading = true
    @State private var isFollowing = false
    @State private var followersCount = 0
    @State private var followingCount = 0
    @State private var recentWalks: [RecentWalkDisplay] = []

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .padding(.top, 100)
            } else if let user {
                VStack(spacing: 20) {
                    avatarHeader(user: user)
                    statsRow(user: user)
                    followButton()
                    dogsSection(dogs: user.dogs)
                    recentWalksSection()
                }
                .padding()
            } else {
                emptyState
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadProfile() }
    }

    // MARK: - Avatar Header

    private func avatarHeader(user: UserProfile) -> some View {
        VStack(spacing: 12) {
            if let photoUrl = user.photoUrl, let url = URL(string: photoUrl) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    avatarPlaceholder
                }
                .frame(width: 96, height: 96)
                .clipShape(Circle())
            } else {
                avatarPlaceholder
            }

            Text(user.displayName ?? user.username)
                .font(.title2.bold())

            if !user.bio.isEmpty {
                Text(user.bio)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("Level \(user.level)")
                    .font(.subheadline.bold())
            }
        }
    }

    private var avatarPlaceholder: some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .foregroundColor(.gray)
            .frame(width: 96, height: 96)
    }

    // MARK: - Stats Row

    private func statsRow(user: UserProfile) -> some View {
        HStack(spacing: 0) {
            statItem(value: "\(user.totalWalks)", label: "Walks")
            Divider().frame(height: 40)
            statItem(
                value: String(format: "%.1f km", user.totalDistanceMeters / 1000.0),
                label: "Distance"
            )
            Divider().frame(height: 40)
            statItem(value: "\(followersCount)", label: "Followers")
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Follow Button

    private func followButton() -> some View {
        Button {
            isFollowing.toggle()
            followersCount += isFollowing ? 1 : -1
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isFollowing ? "person.badge.minus" : "person.badge.plus")
                Text(isFollowing ? "Unfollow" : "Follow")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundColor(isFollowing ? .primary : .white)
            .background(isFollowing ? Color(.systemGray5) : Color.turquoise60)
            .cornerRadius(12)
        }
    }

    // MARK: - Dogs Section

    private func dogsSection(dogs: [DogProfile]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dogs")
                .font(.headline)

            if dogs.isEmpty {
                Text("No dogs listed")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(dogs) { dog in
                    DogCard(dog: dog)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    // MARK: - Recent Walks Section

    private func recentWalksSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Walks")
                .font(.headline)

            if recentWalks.isEmpty {
                HStack {
                    Image(systemName: "figure.walk")
                        .foregroundColor(.secondary)
                    Text("No recent walks")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                ForEach(recentWalks) { walk in
                    HStack(spacing: 12) {
                        Image(systemName: "pawprint.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(walk.date)
                                .font(.subheadline.weight(.medium))
                            HStack(spacing: 12) {
                                Label(walk.distance, systemImage: "arrow.left.arrow.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Label(walk.duration, systemImage: "clock")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }
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

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("Profile Not Found")
                .font(.title2.bold())
            Text("This user's profile could not be loaded.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    // MARK: - Data Loading

    private func loadProfile() {
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { snapshot, error in
            isLoading = false
            if let error {
                print("PublicProfile load error: \(error.localizedDescription)")
                return
            }
            guard let snapshot, snapshot.exists else { return }
            user = try? snapshot.data(as: UserProfile.self)
            followersCount = Int.random(in: 3...120)
            followingCount = Int.random(in: 1...80)
        }
    }
}

struct PublicProfileScreen_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            PublicProfileScreen(userId: "preview-user")
        }
    }
}
