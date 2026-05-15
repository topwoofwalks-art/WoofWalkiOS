import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - DogMatch Model
//
// Parity counterpart of Android `PublicDogInfo` in
// app/src/main/java/com/woofwalk/ui/map/DogMatchCard.kt. Surfaces a
// nearby compatible dog (both dogs marked compatible / shared
// community / friend's dog) on the live map so the user can "Wave"
// (send a quick chat message) without leaving the map screen.
//
// Owner identity is required so the wave action can resolve / create
// the DM thread with deterministic id (`sortedUids.joined("_")`),
// matching the chat-list / chat-detail thread-id convention used
// elsewhere in this app.
struct DogMatch: Identifiable, Equatable {
    let id: String                  // matchDocId from nearby_dogs/{uid}/active
    let dogName: String
    let breed: String
    let ownerUid: String
    let ownerName: String
    let distanceMeters: Int
    let photoURL: URL?

    var distanceLabel: String {
        if distanceMeters < 1000 {
            return "\(distanceMeters)m away"
        }
        let km = Double(distanceMeters) / 1000.0
        return String(format: "%.1fkm away", km)
    }
}

// MARK: - DogMatchCard

/// Floating overlay card shown at top of the map when a nearby
/// compatible dog is detected. Mirrors Android `DogMatchCard`
/// (Waze-style driver-nearby notification). Auto-dismisses after
/// 8 s; the user can swipe horizontally past 200 pt to dismiss
/// early or tap the X.
struct DogMatchCard: View {
    let match: DogMatch
    let onWave: () -> Void
    let onDismiss: () -> Void

    @State private var offsetX: CGFloat = 0
    @State private var visible: Bool = true

    private let autoDismissAfter: TimeInterval = 8.0

    var body: some View {
        cardContent
            .offset(x: offsetX)
            .opacity(visible ? 1 : 0)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        offsetX = value.translation.width
                    }
                    .onEnded { value in
                        if abs(value.translation.width) > 200 {
                            dismissWithAnimation()
                        } else {
                            withAnimation(.spring()) { offsetX = 0 }
                        }
                    }
            )
            .animation(.easeInOut(duration: 0.25), value: visible)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + autoDismissAfter) {
                    // Guard against late-fire if the user already
                    // tapped Wave or dismissed manually.
                    if visible {
                        dismissWithAnimation()
                    }
                }
            }
    }

    private var cardContent: some View {
        HStack(spacing: 12) {
            avatar
                .frame(width: 48, height: 48)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(match.dogName)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                if !match.breed.isEmpty {
                    Text("\(match.breed) · \(match.ownerName)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text(match.ownerName)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Text(match.distanceLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.accentColor)
            }

            Spacer(minLength: 4)

            Button {
                onWave()
                dismissWithAnimation()
            } label: {
                Text("Wave")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.accentColor))
            }
            .buttonStyle(.plain)

            Button(action: dismissWithAnimation) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(6)
                    .background(Circle().fill(Color(.systemGray5)))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        )
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var avatar: some View {
        if let url = match.photoURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                default:
                    placeholderAvatar
                }
            }
        } else {
            placeholderAvatar
        }
    }

    private var placeholderAvatar: some View {
        ZStack {
            Circle().fill(Color.accentColor.opacity(0.15))
            Image(systemName: "pawprint.fill")
                .foregroundColor(.accentColor)
                .font(.system(size: 22))
        }
    }

    private func dismissWithAnimation() {
        withAnimation(.easeInOut(duration: 0.25)) {
            visible = false
            offsetX = offsetX < 0 ? -400 : 400
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

// MARK: - Wave Action Helper
//
// Resolves (or creates) the 1-to-1 DM thread between the current user
// and `ownerUid`, then writes a "👋 Wave!" message into it. Uses the
// sorted-uids thread-id convention already used by ChatListScreen /
// ChatDetailScreen so the existing chat surface picks it up
// automatically.
enum DogMatchWaveAction {
    static func sendWave(toOwnerUid ownerUid: String,
                         senderName: String = Auth.auth().currentUser?.displayName ?? "Someone") {
        guard let me = Auth.auth().currentUser?.uid, me != ownerUid else { return }
        let threadId = [me, ownerUid].sorted().joined(separator: "_")
        let db = Firestore.firestore()
        let waveText = "👋"

        // Upsert the thread doc (creates it if this is the first
        // message between these two users). Mirrors the
        // sendMessage/lastMessage convention in ChatDetailScreen.
        Task {
            do {
                try await db.collection("messageThreads").document(threadId).setData([
                    "participants": [me, ownerUid].sorted(),
                    "lastMessage": waveText,
                    "lastMessageSenderId": me,
                    "lastMessageAt": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp()
                ], merge: true)

                try await db.collection("messageThreads").document(threadId)
                    .collection("messages").addDocument(data: [
                        "chatId": threadId,
                        "senderId": me,
                        "senderName": senderName,
                        "text": waveText,
                        "readBy": [me],
                        "createdAt": FieldValue.serverTimestamp()
                    ])
                print("[DogMatchWaveAction] Wave sent to \(ownerUid) on thread \(threadId)")
            } catch {
                print("[DogMatchWaveAction] Failed to send wave: \(error.localizedDescription)")
            }
        }
    }
}
