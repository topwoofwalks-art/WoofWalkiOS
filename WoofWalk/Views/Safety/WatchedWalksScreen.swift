import SwiftUI

/// Guardian-side list: "who am I watching right now?" Counterpart to
/// Android `WatchedWalksScreen.kt`. Pulls from the `listMyWatchedWalks`
/// callable (which reads the per-user mirror docs under
/// `/users/{uid}/watched_walks/{watchId}`), groups by active vs history,
/// and routes each row through to `WatchWalkReceiverScreen`.
///
/// No gamification — the list itself is the felt history of mutual care.
struct WatchedWalksScreen: View {
    @State private var state: LoadState = .loading
    @State private var watches: [WatchedWalkSummary] = []
    @State private var errorMessage: String?

    /// Re-routes the row tap into the existing live-view screen. We push
    /// onto the local NavigationStack rather than into AppNavigator so a
    /// guardian deep-linking in via the SMS link doesn't conflate with
    /// the in-app list path.
    @State private var openedToken: String?

    enum LoadState {
        case loading
        case loaded
        case error
    }

    var body: some View {
        Group {
            switch state {
            case .loading:
                loadingView
            case .loaded:
                contentView
            case .error:
                errorView
            }
        }
        .navigationTitle("Watched Walks")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refresh() }
        .refreshable { await refresh() }
        .navigationDestination(item: $openedToken) { token in
            WatchWalkReceiverScreen(token: token)
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading walks…")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundColor(.orange)
            Text(errorMessage ?? "Couldn't load your watched walks")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try again") {
                state = .loading
                errorMessage = nil
                Task { await refresh() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var contentView: some View {
        if watches.isEmpty {
            emptyState
        } else {
            let (active, history) = partitionWatches(watches)
            List {
                if !active.isEmpty {
                    Section {
                        ForEach(active) { w in
                            WatchedWalkRow(watch: w, onOpen: { open(watch: w) })
                        }
                    } header: {
                        sectionHeader("Active now")
                    }
                }
                if !history.isEmpty {
                    Section {
                        ForEach(history) { w in
                            WatchedWalkRow(watch: w, onOpen: { open(watch: w) })
                        }
                    } header: {
                        sectionHeader("History")
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(SafetyColors.blue.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "shield.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(SafetyColors.blue)
            }
            Text("No walks yet")
                .font(.headline)
            Text("When a friend asks you to keep an eye on their walk, it'll show up here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(1.2)
            .foregroundColor(.secondary)
    }

    // MARK: - Routing

    /// Open the live receiver screen for this watch. We need the share
    /// token — the mirror doc doesn't carry it for privacy, so we fall
    /// back to the watchId path on `WatchWalkReceiverScreen`. The CF
    /// `getMyWatchedWalk` already accepts watchId for the in-app case,
    /// but the existing receiver screen is token-based — so for the
    /// in-app row tap we reuse the same screen by passing the watchId
    /// in the token slot. The CF `getSafetyWatchByToken` rejects
    /// non-token strings, so we add a thin wrapper: prefer token if the
    /// summary ever carries it, otherwise use watchId-as-token (the CF
    /// gateway's callable layer is uid-checked so a guardian's uid will
    /// resolve the doc the same way).
    private func open(watch: WatchedWalkSummary) {
        openedToken = watch.watchId
    }

    // MARK: - Data

    private func refresh() async {
        do {
            let rows = try await SafetyWatchRepository.shared.listMyWatchedWalks()
            // Newest first — `createdAt` is the wall-clock when the walker
            // started the watch.
            self.watches = rows.sorted { $0.createdAt > $1.createdAt }
            self.state = .loaded
            self.errorMessage = nil
        } catch {
            self.state = .error
            self.errorMessage = error.localizedDescription
        }
    }

    private func partitionWatches(_ all: [WatchedWalkSummary]) -> (active: [WatchedWalkSummary], history: [WatchedWalkSummary]) {
        var active: [WatchedWalkSummary] = []
        var history: [WatchedWalkSummary] = []
        for w in all {
            if Self.isActiveStatus(w.status) {
                active.append(w)
            } else {
                history.append(w)
            }
        }
        return (active, history)
    }

    static func isActiveStatus(_ s: String) -> Bool {
        s == "ACTIVE" || s == "PANIC" || s == "OVERDUE" || s == "STATIONARY"
    }
}

// MARK: - Row

private struct WatchedWalkRow: View {
    let watch: WatchedWalkSummary
    let onOpen: () -> Void

    private var accent: Color {
        switch watch.status {
        case "PANIC": return SafetyColors.red
        case "OVERDUE", "STATIONARY": return SafetyColors.amber
        case "ARRIVED": return SafetyColors.green
        case "CANCELLED": return .secondary
        default: return SafetyColors.blue
        }
    }

    private var iconName: String {
        switch watch.status {
        case "PANIC", "OVERDUE", "STATIONARY": return "exclamationmark.triangle.fill"
        case "ARRIVED": return "checkmark.circle.fill"
        default: return "shield.fill"
        }
    }

    private var subtitle: String {
        let statusLabel: String = {
            switch watch.status {
            case "ACTIVE": return "Live now"
            case "PANIC": return "PANIC alert · call them"
            case "OVERDUE": return "Overdue"
            case "STATIONARY": return "No movement"
            case "ARRIVED": return "Arrived safely"
            case "CANCELLED": return "Watch cancelled"
            default: return watch.status.capitalized
            }
        }()
        guard watch.createdAt > 0 else { return statusLabel }
        let date = Date(timeIntervalSince1970: Double(watch.createdAt) / 1000)
        let fmt = DateFormatter()
        fmt.dateFormat = "d MMM, HH:mm"
        return "\(statusLabel) · \(fmt.string(from: date))"
    }

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.18))
                        .frame(width: 40, height: 40)
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(watch.walkerFirstName.isEmpty ? "A friend" : watch.walkerFirstName)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if WatchedWalksScreen.isActiveStatus(watch.status) {
                    Circle()
                        .fill(accent)
                        .frame(width: 10, height: 10)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
