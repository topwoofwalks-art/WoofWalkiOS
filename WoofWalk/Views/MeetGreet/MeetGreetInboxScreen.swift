import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine

/// Whose inbox are we showing? Drives both the listener selection
/// and the row "other-party" projection (clients see the provider
/// org name; providers see the client first name).
enum MeetGreetPerspective {
    case client
    case provider
}

/// Inbox of Meet & Greet threads. One screen, two perspectives:
///
/// - `.client` — threads where the current uid is the requester.
///   The list comes straight from `observeMyClientThreads()` (which
///   already scopes to `clientUid == auth.uid`).
/// - `.provider` — threads addressed to the org whose owner uid is
///   the current uid. Resolves the org id from the user doc
///   (`organizationId`) with a fallback to the user's own uid, which
///   is the convention used elsewhere on iOS (see
///   `BusinessHomeScreen.loadCashRequests`).
///
/// Without this screen, anyone who submits a request and then
/// navigates away has no way back to the conversation. Tapping a
/// row pushes `MeetGreetThreadScreen` via the standard `AppRoute`
/// destination wiring.
struct MeetGreetInboxScreen: View {
    let perspective: MeetGreetPerspective

    @StateObject private var viewModel: MeetGreetInboxViewModel

    init(perspective: MeetGreetPerspective) {
        self.perspective = perspective
        _viewModel = StateObject(wrappedValue: MeetGreetInboxViewModel(perspective: perspective))
    }

    var body: some View {
        ZStack {
            Color(hex: 0x1C1C1C).ignoresSafeArea()

            if viewModel.isLoading && viewModel.threads.isEmpty {
                ProgressView()
                    .tint(.turquoise60)
            } else if viewModel.threads.isEmpty {
                emptyState
            } else {
                threadList
            }
        }
        .navigationTitle("Meet & Greet")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(hex: 0x1C1C1C), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert("Couldn't load", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { _ in viewModel.errorMessage = nil }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .task {
            await viewModel.start()
        }
    }

    // MARK: - List

    private var threadList: some View {
        List {
            ForEach(viewModel.threads) { thread in
                NavigationLink(value: AppRoute.meetGreetThread(threadId: thread.id)) {
                    threadRow(thread)
                }
                .listRowBackground(Color(hex: 0x2F3033))
                .listRowSeparatorTint(Color.white.opacity(0.06))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(hex: 0x1C1C1C))
        .listStyle(.plain)
    }

    private func threadRow(_ thread: MeetGreetThread) -> some View {
        HStack(alignment: .top, spacing: 12) {
            avatar(for: thread)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(otherPartyName(for: thread))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Text(relativeTimestamp(thread.lastMessageAt))
                        .font(.caption2)
                        .foregroundColor(.neutral60)
                }

                Text(previewLine(for: thread))
                    .font(.caption)
                    .foregroundColor(.neutral80)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                statusPill(thread.status)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Avatar

    @ViewBuilder
    private func avatar(for thread: MeetGreetThread) -> some View {
        let logoUrl = perspective == .client ? thread.providerLogoUrl : nil
        if let logoUrl, let url = URL(string: logoUrl) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                avatarPlaceholder(for: thread)
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
        } else {
            avatarPlaceholder(for: thread)
        }
    }

    private func avatarPlaceholder(for thread: MeetGreetThread) -> some View {
        ZStack {
            Circle()
                .fill(Color.turquoise60.opacity(0.20))
                .frame(width: 44, height: 44)
            Text(initials(for: otherPartyName(for: thread)))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.turquoise60)
        }
    }

    private func initials(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "?" }
        let parts = trimmed.split(separator: " ")
        if parts.count >= 2,
           let a = parts.first?.first,
           let b = parts.dropFirst().first?.first {
            return "\(a)\(b)".uppercased()
        }
        return String(trimmed.prefix(1)).uppercased()
    }

    // MARK: - Row projections

    private func otherPartyName(for thread: MeetGreetThread) -> String {
        switch perspective {
        case .client:
            // Provider org name takes priority (full brand); fallback
            // to the short display projection if the org name field
            // is empty for any reason.
            if !thread.providerOrgName.isEmpty { return thread.providerOrgName }
            return thread.providerDisplayName
        case .provider:
            // Client display is already a first-name-only projection.
            return thread.clientDisplayName.isEmpty ? "WoofWalk client" : thread.clientDisplayName
        }
    }

    private func previewLine(for thread: MeetGreetThread) -> String {
        // Surface the most-decision-relevant snippet first: dog name +
        // intro for fresh threads; the confirmed/proposed time once a
        // suggestion exists.
        if let confirmed = thread.confirmedTime {
            return "\(thread.clientDogName) · \(formatTimeShort(confirmed.startDate)) at \(confirmed.locationLabel)"
        }
        if let proposed = thread.proposedTime {
            return "\(thread.clientDogName) · suggested \(formatTimeShort(proposed.startDate))"
        }
        let dog = thread.clientDogName
        let intro = thread.introMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        if !intro.isEmpty {
            return "\(dog) · \(intro)"
        }
        return dog
    }

    private func formatTimeShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM HH:mm"
        return formatter.string(from: date)
    }

    private func relativeTimestamp(_ ms: Int64) -> String {
        guard ms > 0 else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(ms) / 1000.0)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Status pill

    /// Status pill colours match `MeetGreetThreadScreen.statusPill`
    /// 1:1 (turquoise / amber / success / error / neutral). Keep
    /// these in sync — the inbox row and the thread header both
    /// use them as the at-a-glance state indicator.
    private func statusPill(_ status: MGStatus) -> some View {
        let (bg, fg): (Color, Color) = {
            switch status {
            case .pendingProviderResponse: return (Color.orange60.opacity(0.20), .orange60)
            case .inConversation: return (Color.turquoise60.opacity(0.20), .turquoise60)
            case .timeProposed: return (Color.orange60.opacity(0.20), .orange60)
            case .confirmed: return (Color.success60.opacity(0.20), .success60)
            case .completed: return (Color.neutral60.opacity(0.25), .neutral80)
            case .cancelled: return (Color.error60.opacity(0.20), .error60)
            }
        }()
        return Text(status.displayLabel)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Capsule().fill(bg))
            .foregroundColor(fg)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "hand.wave.fill")
                .font(.system(size: 44))
                .foregroundColor(.turquoise60.opacity(0.7))
            Text("No Meet & Greets yet")
                .font(.headline)
                .foregroundColor(.white)
            Text(emptyCopy)
                .font(.subheadline)
                .foregroundColor(.neutral80)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }

    private var emptyCopy: String {
        switch perspective {
        case .client:
            return "A Meet & Greet is a short, no-commitment intro with a provider before you book. Find a provider in Discover and tap \"Meet & Greet\" to start one."
        case .provider:
            return "When clients reach out for a quick intro before booking, their conversations land here. Make sure your profile is published so they can find you."
        }
    }
}

// MARK: - View model

@MainActor
final class MeetGreetInboxViewModel: ObservableObject {
    @Published var threads: [MeetGreetThread] = []
    @Published var isLoading: Bool = true
    @Published var errorMessage: String?

    private let perspective: MeetGreetPerspective
    private let repository = MeetGreetRepository.shared
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    private var cancellable: AnyCancellable?
    private var didStart = false

    init(perspective: MeetGreetPerspective) {
        self.perspective = perspective
    }

    /// Begin observing threads. `task` calls this on appear; idempotent
    /// so re-entries (e.g. a tab switch) don't spawn duplicate listeners.
    func start() async {
        guard !didStart else { return }
        didStart = true

        switch perspective {
        case .client:
            subscribe(to: repository.observeMyClientThreads())
        case .provider:
            do {
                let orgId = try await resolveOrgId()
                subscribe(to: repository.observeProviderThreads(providerOrgId: orgId))
            } catch {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func subscribe(to publisher: AnyPublisher<[MeetGreetThread], Error>) {
        cancellable = publisher
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self else { return }
                    self.isLoading = false
                    if case .failure(let err) = completion {
                        // Permission-denied here means the user isn't
                        // claimed to the org yet (fresh business signup).
                        // Surface as an empty inbox rather than an alert.
                        let nsErr = err as NSError
                        if nsErr.code == 7 /* permission-denied */ {
                            print("[MeetGreetInbox] permission-denied — likely org claim missing")
                        } else {
                            self.errorMessage = err.localizedDescription
                        }
                    }
                },
                receiveValue: { [weak self] threads in
                    guard let self else { return }
                    self.isLoading = false
                    self.threads = threads
                }
            )
    }

    /// Resolve the current user's organization id. Convention across
    /// the iOS codebase (see BusinessHomeScreen, BusinessInboxScreen):
    /// the org doc id is stored on the user doc as `organizationId`,
    /// with a fallback to the user's own uid for solo-trader signups
    /// where the org doc id == the owner uid.
    private func resolveOrgId() async throws -> String {
        guard let uid = auth.currentUser?.uid else {
            throw NSError(
                domain: "MeetGreetInboxViewModel",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Sign-in required"]
            )
        }
        let snapshot = try await db.collection("users").document(uid).getDocument()
        if let orgId = snapshot.data()?["organizationId"] as? String, !orgId.isEmpty {
            return orgId
        }
        return uid
    }

    deinit {
        cancellable?.cancel()
    }
}

// MARK: - Preview

#Preview("Client") {
    NavigationStack {
        MeetGreetInboxScreen(perspective: .client)
    }
    .preferredColorScheme(.dark)
}

#Preview("Provider") {
    NavigationStack {
        MeetGreetInboxScreen(perspective: .provider)
    }
    .preferredColorScheme(.dark)
}
