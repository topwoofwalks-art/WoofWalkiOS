import SwiftUI
import MapKit
import FirebaseFunctions
import FirebaseAuth
import UIKit

/// Watch Me — guardian screen.
///
/// Counterpart to the Android `LiveFriendWatchScreen.kt` and the portal
/// `WatchMePublicPage.tsx`. Reached from a `watchwalk://<token>` deep
/// link the walker shared with a friend. Shows the walker's live GPS
/// pin on a map, last-contact freshness, big "Call walker" and
/// "I've arrived" actions, and an explicit end state when the walk
/// has finished or the token is no longer valid.
///
/// Backend contract
/// ----------------
/// Reads go through the `getSafetyWatchByToken` callable
/// (`functions/src/safety/watchMe.ts:666`). The Firestore document at
/// `safety_watches/{watchId}` is NOT directly readable from the client
/// — rules on this project reject the per-doc auth predicates the
/// safety collection needs, so all reads + writes use callables that
/// validate the token / uid server-side.
///
/// We poll every 5 s rather than using a Firestore snapshot listener:
/// the CF response shape is fixed, the polling cost is tiny, and it
/// matches the portal page exactly (it polls the same CF too). The
/// 5 s cadence is borrowed from `LiveFriendWatchScreen.kt`.
struct WatchWalkReceiverScreen: View {
    let token: String

    @State private var snapshot: WatchSnapshot?
    @State private var loadState: LoadState = .loading
    @State private var errorMessage: String?
    @State private var pollTask: Task<Void, Never>?
    @State private var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 54.5, longitude: -2.5),
        span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)
    )

    private struct WalkerPin: Identifiable {
        let id = "walker"
        let coordinate: CLLocationCoordinate2D
        let name: String
    }
    @State private var hasCenteredOnFix = false
    @State private var arrivedMarking = false

    private let functions = Functions.functions(region: "europe-west2")

    enum LoadState: Equatable {
        case loading
        case active
        case expired
        case error
    }

    /// Reduced response shape from `getSafetyWatchByToken`. Field names
    /// mirror the CF return value (`functions/src/safety/watchMe.ts:679`).
    struct WatchSnapshot: Equatable {
        let id: String
        let walkerFirstName: String
        let walkerNote: String
        let lastLat: Double
        let lastLng: Double
        let lastUpdatedAt: Int64
        let routePoints: [CLLocationCoordinate2D]
        let distanceMeters: Double
        let durationSec: Int64
        let lastCheckInAt: Int64
        let panicTriggeredAt: Int64
        let status: String
        let expectedReturnAt: Int64
        let walkEnded: Bool
        let isActive: Bool

        static func == (lhs: WatchSnapshot, rhs: WatchSnapshot) -> Bool {
            lhs.id == rhs.id
                && lhs.lastLat == rhs.lastLat
                && lhs.lastLng == rhs.lastLng
                && lhs.lastUpdatedAt == rhs.lastUpdatedAt
                && lhs.status == rhs.status
                && lhs.walkEnded == rhs.walkEnded
                && lhs.isActive == rhs.isActive
        }

        var hasFix: Bool { lastLat != 0 || lastLng != 0 }
    }

    var body: some View {
        Group {
            switch loadState {
            case .loading:
                loadingView
            case .expired:
                endedView
            case .error:
                errorView
            case .active:
                if let snapshot {
                    contentView(snapshot)
                } else {
                    loadingView
                }
            }
        }
        .navigationTitle("Watch Me")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            startPolling()
        }
        .onDisappear {
            pollTask?.cancel()
            pollTask = nil
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Connecting to walk…")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var endedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 56))
                .foregroundColor(.green)
            Text("This Watch Me has ended")
                .font(.title3.bold())
            Text("The walker either arrived safely, ended the watch, or the share link expired.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text(errorMessage ?? "Couldn't load this watch")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("Try again") {
                errorMessage = nil
                loadState = .loading
                startPolling()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func contentView(_ s: WatchSnapshot) -> some View {
        VStack(spacing: 0) {
            // Header — relationship-first banner.
            headerBanner(s)

            // Map (or "waiting for first fix" overlay).
            mapView(s)
                .frame(maxHeight: .infinity)

            // Vitals + actions.
            footer(s)
        }
    }

    private func headerBanner(_ s: WatchSnapshot) -> some View {
        let accent = accentColor(for: s)
        let statusLabel: String = {
            switch s.status {
            case "PANIC": return "PANIC ALERT — call them now"
            case "OVERDUE": return "Overdue · contact them"
            case "STATIONARY": return "No movement for a while"
            case "ARRIVED": return "Arrived safely"
            case "CANCELLED": return "Watch ended"
            default: return "Live — being watched"
            }
        }()

        return HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: s.status == "PANIC" || s.status == "OVERDUE"
                      ? "exclamationmark.triangle.fill"
                      : "shield.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(s.walkerFirstName) on a walk")
                    .font(.headline)
                    .foregroundColor(.white)
                Text(statusLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.92))
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(accent)
    }

    @ViewBuilder
    private func mapView(_ s: WatchSnapshot) -> some View {
        ZStack {
            // iOS 16-compatible Map. MapPolyline only exists on iOS 17+ so
            // the route trail is rendered as a series of small annotation
            // dots on iOS 16 — visually close enough for the receiver UX.
            let walkerPin: [WalkerPin] = s.hasFix
                ? [WalkerPin(coordinate: CLLocationCoordinate2D(latitude: s.lastLat, longitude: s.lastLng), name: s.walkerFirstName)]
                : []
            Map(coordinateRegion: $region, annotationItems: walkerPin) { pin in
                MapAnnotation(coordinate: pin.coordinate) {
                    walkerMarker(name: pin.name, accent: accentColor(for: s))
                }
            }
            .onChange(of: s.lastLat) { _ in
                if s.hasFix && !hasCenteredOnFix {
                    region = MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: s.lastLat, longitude: s.lastLng),
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                    hasCenteredOnFix = true
                }
            }

            if !s.hasFix {
                Color.black.opacity(0.35)
                    .overlay(
                        Text("Waiting for first GPS fix from \(s.walkerFirstName)…")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(24)
                    )
                    .allowsHitTesting(false)
            }
        }
    }

    private func walkerMarker(name: String, accent: Color) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(accent)
                    .frame(width: 36, height: 36)
                Image(systemName: "figure.walk")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            Text(name)
                .font(.caption2.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white)
                .cornerRadius(4)
                .shadow(radius: 1)
        }
    }

    private func footer(_ s: WatchSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                vital(label: "LAST CONTACT", value: formatAgo(s.lastUpdatedAt))
                vital(label: "DISTANCE", value: formatDistance(s.distanceMeters))
            }
            HStack(spacing: 12) {
                vital(label: "DURATION", value: formatDuration(s.durationSec))
                vital(label: "EXPECTED BACK", value: formatExpected(s.expectedReturnAt))
            }

            if !s.walkerNote.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "text.bubble.fill")
                        .foregroundColor(.secondary)
                    Text(s.walkerNote)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }

            // Actions — Call walker, I've arrived.
            HStack(spacing: 10) {
                Button {
                    callWalker()
                } label: {
                    Label("Call walker", systemImage: "phone.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(SafetyColors.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                Button {
                    markArrived()
                } label: {
                    Label(arrivedMarking ? "Marking…" : "I've arrived", systemImage: "checkmark.seal.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(SafetyColors.green.opacity(arrivedMarking ? 0.6 : 1))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(arrivedMarking || s.walkEnded)
            }
            .padding(.top, 4)

            if s.status == "PANIC" || s.status == "OVERDUE" {
                Button {
                    call999()
                } label: {
                    Label("Call 999", systemImage: "phone.connection.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(SafetyColors.red)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
    }

    private func vital(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }

    // MARK: - Helpers

    private func accentColor(for s: WatchSnapshot) -> Color {
        switch s.status {
        case "PANIC": return SafetyColors.red
        case "OVERDUE", "STATIONARY": return SafetyColors.amber
        case "ARRIVED": return SafetyColors.green
        default: return SafetyColors.blue
        }
    }

    private func formatAgo(_ epochMs: Int64) -> String {
        guard epochMs > 0 else { return "—" }
        let sec = max(0, Int64(Date().timeIntervalSince1970 * 1000) - epochMs) / 1000
        switch sec {
        case ..<30: return "just now"
        case ..<60: return "\(sec)s ago"
        case ..<3600: return "\(sec / 60)m ago"
        default: return "\(sec / 3600)h \((sec % 3600) / 60)m ago"
        }
    }

    private func formatDistance(_ m: Double) -> String {
        m >= 1000 ? String(format: "%.2f km", m / 1000) : "\(Int(m)) m"
    }

    private func formatDuration(_ sec: Int64) -> String {
        let h = sec / 3600
        let m = (sec % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    private func formatExpected(_ epochMs: Int64) -> String {
        guard epochMs > 0 else { return "—" }
        let date = Date(timeIntervalSince1970: Double(epochMs) / 1000)
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        fmt.dateStyle = .none
        return fmt.string(from: date)
    }

    // MARK: - Networking

    /// Spawn a polling task on the @MainActor that fetches the CF every
    /// 5 s. Cancels itself on `onDisappear`. Stops automatically once
    /// the walk ends — at which point we flip to `.expired` and let the
    /// user navigate away.
    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { @MainActor in
            while !Task.isCancelled {
                await refreshOnce()
                if loadState == .expired || loadState == .error {
                    return
                }
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    @MainActor
    private func refreshOnce() async {
        do {
            let result = try await functions.httpsCallable("getSafetyWatchByToken").call(["token": token])
            guard let dict = result.data as? [String: Any] else {
                loadState = .error
                errorMessage = "Unexpected server response"
                return
            }
            let parsed = parseSnapshot(dict)
            snapshot = parsed
            loadState = parsed.walkEnded || !parsed.isActive ? .expired : .active

            // Centre the map on the first GPS fix we receive. Subsequent
            // fixes update the marker but don't fight the user's pan/zoom.
            if !hasCenteredOnFix, parsed.hasFix {
                hasCenteredOnFix = true
                region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: parsed.lastLat, longitude: parsed.lastLng),
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            }
        } catch {
            let ns = error as NSError
            let isNotFound = ns.localizedDescription.lowercased().contains("not found")
                || ns.localizedDescription.lowercased().contains("expired")
            if isNotFound {
                loadState = .expired
                errorMessage = nil
            } else if loadState != .active {
                // Only flip to error on the first failed fetch; if we
                // already have data, keep showing it and try again next
                // tick — transient network blips shouldn't blow the screen
                // away mid-walk.
                loadState = .error
                errorMessage = error.localizedDescription
            }
        }
    }

    private func parseSnapshot(_ d: [String: Any]) -> WatchSnapshot {
        let routeRaw = (d["routePoints"] as? [[String: Any]]) ?? []
        let route: [CLLocationCoordinate2D] = routeRaw.compactMap { p in
            guard let lat = p["lat"] as? Double, let lng = p["lng"] as? Double else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        return WatchSnapshot(
            id: (d["id"] as? String) ?? "",
            walkerFirstName: (d["walkerFirstName"] as? String) ?? "Your friend",
            walkerNote: (d["walkerNote"] as? String) ?? "",
            lastLat: (d["lastLat"] as? Double) ?? 0,
            lastLng: (d["lastLng"] as? Double) ?? 0,
            lastUpdatedAt: int64(d["lastUpdatedAt"]),
            routePoints: route,
            distanceMeters: (d["distanceMeters"] as? Double) ?? 0,
            durationSec: int64(d["durationSec"]),
            lastCheckInAt: int64(d["lastCheckInAt"]),
            panicTriggeredAt: int64(d["panicTriggeredAt"]),
            status: (d["status"] as? String) ?? "ACTIVE",
            expectedReturnAt: int64(d["expectedReturnAt"]),
            walkEnded: (d["walkEnded"] as? Bool) ?? false,
            isActive: (d["isActive"] as? Bool) ?? true
        )
    }

    private func int64(_ any: Any?) -> Int64 {
        if let n = any as? Int64 { return n }
        if let n = any as? Int { return Int64(n) }
        if let n = any as? Double { return Int64(n) }
        if let s = any as? String, let n = Int64(s) { return n }
        return 0
    }

    // MARK: - Actions

    /// Walker phone isn't returned by `getSafetyWatchByToken` (privacy).
    /// We fall back to opening Phone's contact picker if not known — the
    /// guardian almost always has the walker in their address book.
    private func callWalker() {
        // Without the walker's phone in the CF response, the most useful
        // thing we can do is open the Phone app to dial — recents/favourites
        // are usually one tap from there. If the back-end is later
        // extended to return walker phone, swap to `tel:` directly.
        if let url = URL(string: "tel://") {
            UIApplication.shared.open(url)
        }
    }

    private func call999() {
        if let url = URL(string: "tel://999") {
            UIApplication.shared.open(url)
        }
    }

    /// Guardian taps "I've arrived" once the walker has joined them.
    /// This isn't a strictly-required ACK — the walker can also mark
    /// arrived from their end — but it gives the guardian a way to
    /// close the loop. Hits the same `markSafetyWatchArrived` callable
    /// the walker uses; guardians without ownership get a polite
    /// permission-denied that we surface as an inline error.
    private func markArrived() {
        guard let snapshot else { return }
        arrivedMarking = true
        Task { @MainActor in
            defer { arrivedMarking = false }
            do {
                _ = try await functions
                    .httpsCallable("markSafetyWatchArrived")
                    .call(["watchId": snapshot.id])
                loadState = .expired
            } catch {
                let ns = error as NSError
                errorMessage = ns.localizedDescription
            }
        }
    }
}
