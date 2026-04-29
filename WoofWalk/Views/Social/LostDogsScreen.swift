import SwiftUI
import FirebaseFirestore

struct LostDogsScreen: View {
    @State private var lostDogs: [LostDogItem] = []
    @State private var isLoading = true
    @State private var showReportSheet = false
    @State private var listener: ListenerRegistration?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
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

            // Floating "Report" button — primary CTA matching the
            // Android equivalent. Always reachable, even on the empty
            // state so users can report a stray they've found without
            // having to wait for a list to populate.
            Button {
                showReportSheet = true
            } label: {
                Label("Report", systemImage: "exclamationmark.bubble.fill")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(red: 0/255, green: 160/255, blue: 176/255))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .shadow(radius: 4, y: 2)
            }
            .padding(20)
        }
        .sheet(isPresented: $showReportSheet) {
            LostDogReportScreen()
        }
        .onAppear {
            if listener == nil { startListener() }
        }
        .onDisappear {
            listener?.remove()
            listener = nil
        }
    }

    private func startListener() {
        let db = Firestore.firestore()
        // Canonical collection name is `lost_dog_alerts` (matches
        // Android's LostDogRepository + firestore.rules:3908). The
        // earlier `lostDogs` collection name on iOS was a bug that
        // meant cross-platform alerts never showed.
        listener = db.collection("lost_dog_alerts")
            .whereField("status", isEqualTo: "LOST")
            .order(by: "reportedAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { snapshot, error in
                isLoading = false
                guard let docs = snapshot?.documents else {
                    print("[LostDogs] Failed to load: \(error?.localizedDescription ?? "unknown")")
                    return
                }
                lostDogs = docs.compactMap { doc -> LostDogItem? in
                    let data = doc.data()
                    guard let name = data["dogName"] as? String else { return nil }
                    return LostDogItem(
                        id: doc.documentID,
                        name: name,
                        breed: data["dogBreed"] as? String ?? "Unknown",
                        // Android writes locationDescription; legacy
                        // docs may carry lastSeenLocation. Fall back
                        // through both.
                        lastSeenLocation: (data["locationDescription"] as? String)
                            ?? (data["lastSeenLocation"] as? String) ?? "",
                        reportedAt: (data["reportedAt"] as? Timestamp)?.dateValue() ?? Date(),
                        photoUrl: data["dogPhotoUrl"] as? String,
                        distance: nil
                    )
                }
                print("[LostDogs] Loaded \(lostDogs.count) lost dogs")
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

            Text("Thankfully, no dogs have been reported lost in your area. If you spot a lost dog, tap Report below.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

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
