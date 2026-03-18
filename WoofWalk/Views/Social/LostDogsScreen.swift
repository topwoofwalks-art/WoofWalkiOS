import SwiftUI

struct LostDogsScreen: View {
    @State private var lostDogs: [LostDogItem] = []
    @State private var isLoading = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if lostDogs.isEmpty {
                emptyState
            } else {
                List(lostDogs) { dog in
                    LostDogRow(dog: dog)
                }
                .listStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "pawprint.fill")
                .font(.system(size: 56))
                .foregroundColor(Color(red: 0/255, green: 160/255, blue: 176/255).opacity(0.3))

            Text("No Lost Dogs Reported Nearby")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            Text("Thankfully, no dogs have been reported lost in your area. If you spot a lost dog, you can report it here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: {}) {
                Label("Report a Lost Dog", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(Color(red: 0/255, green: 160/255, blue: 176/255))
                    )
            }
            .padding(.top, 8)

            Spacer()
        }
    }
}

struct LostDogItem: Identifiable {
    let id: String
    let name: String
    let breed: String
    let lastSeenLocation: String
    let reportedAt: Date
    let photoUrl: String?
    let distance: Double?
}

struct LostDogRow: View {
    let dog: LostDogItem

    var body: some View {
        HStack(spacing: 12) {
            // Dog photo placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0/255, green: 160/255, blue: 176/255).opacity(0.1))
                .frame(width: 64, height: 64)
                .overlay {
                    if let photoUrl = dog.photoUrl, let url = URL(string: photoUrl) {
                        AsyncImage(url: url) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Image(systemName: "dog.fill")
                                .font(.title2)
                                .foregroundColor(Color(red: 0/255, green: 160/255, blue: 176/255))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Image(systemName: "dog.fill")
                            .font(.title2)
                            .foregroundColor(Color(red: 0/255, green: 160/255, blue: 176/255))
                    }
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(dog.name)
                    .font(.subheadline.bold())

                Text(dog.breed)
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.caption2)
                    Text(dog.lastSeenLocation)
                        .font(.caption2)
                    if let distance = dog.distance {
                        Text("(\(String(format: "%.1f", distance)) km)")
                            .font(.caption2)
                            .foregroundColor(Color(red: 0/255, green: 160/255, blue: 176/255))
                    }
                }
                .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
