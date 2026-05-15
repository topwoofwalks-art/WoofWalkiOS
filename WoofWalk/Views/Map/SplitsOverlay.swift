import SwiftUI
import Combine
import CoreLocation

/// Live km-splits overlay shown during an active walk.
///
/// Listens to `WalkTrackingService.shared.trackingState` and, on every km
/// crossing (kilometre bucket increment, with a >50 m hysteresis so we
/// don't double-fire on GPS jitter right around the boundary), flashes a
/// card showing the time + pace for the just-completed kilometre. The
/// card auto-dismisses after 5 s with a smooth fade.
///
/// Mirrors Android `app/src/main/java/com/woofwalk/ui/map/SplitsOverlay.kt`
/// in behaviour — same trigger rule, same 5 s auto-hide, same surface
/// (latest split summary; tap to expand in a follow-up if needed). Kept
/// dependency-free so MapScreen can drop it in as a top-of-stack overlay.
struct SplitsOverlay: View {
    @ObservedObject var walkTracking: WalkTrackingService = .shared

    @State private var splits: [KmSplit] = []
    @State private var lastBucketKm: Int = 0
    @State private var hasArmed: Bool = false
    @State private var startTime: Date?

    /// Currently-flashing split. `nil` when no split is being shown.
    @State private var visibleSplit: KmSplit?
    /// One-shot hide task — cancelled if a new split fires before the
    /// 5 s timer elapses, so the new card replaces the old one cleanly.
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        VStack {
            if let split = visibleSplit {
                splitCard(split)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.85).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .padding(.top, 100)
                    .padding(.horizontal, 16)
            }
            Spacer()
        }
        .allowsHitTesting(false)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: visibleSplit?.kmNumber)
        .onAppear { resetFor(state: walkTracking.trackingState) }
        .onChange(of: walkTracking.trackingState.isTracking) { _, isActive in
            if isActive {
                resetFor(state: walkTracking.trackingState)
            } else {
                splits.removeAll()
                visibleSplit = nil
                hideTask?.cancel()
                hideTask = nil
                hasArmed = false
            }
        }
        .onChange(of: walkTracking.trackingState.distanceMeters) { _, newDistance in
            evaluate(distanceMeters: newDistance,
                     durationSec: walkTracking.trackingState.durationSeconds)
        }
    }

    // MARK: - Trigger logic

    /// Reset bookkeeping when a fresh walk begins. We arm the trigger
    /// only after the walker has moved at least 50 m so the very first
    /// "km 0" boundary doesn't immediately fire at distance ≈ 0.
    private func resetFor(state: WalkTrackingState) {
        splits.removeAll()
        visibleSplit = nil
        hideTask?.cancel()
        hideTask = nil
        lastBucketKm = Int(state.distanceMeters / 1000.0)
        startTime = state.isTracking
            ? Date().addingTimeInterval(-Double(state.durationSeconds))
            : nil
        hasArmed = state.distanceMeters >= 50
    }

    /// Per-distance-tick: if we've crossed into a new km bucket AND the
    /// trigger is armed (>50 m past the boundary, matching the spec's
    /// `% 1000 < 50` hysteresis read in the other direction), append a
    /// new split and flash the card.
    private func evaluate(distanceMeters: Double, durationSec: Int) {
        guard walkTracking.trackingState.isTracking else { return }

        // Arm once we're clear of the boundary by 50 m. Without this the
        // overlay would fire at distance ≈ 0 every time a fresh walk
        // begins, before any real kilometre has been completed.
        if !hasArmed {
            if distanceMeters >= 50 {
                hasArmed = true
                lastBucketKm = Int(distanceMeters / 1000.0)
            }
            return
        }

        let bucket = Int(distanceMeters / 1000.0)
        guard bucket > lastBucketKm else { return }

        let kmNumber = bucket  // the km we just *completed*
        let previousSplitsDurationSec = splits.reduce(0) { $0 + $1.durationSec }
        let splitDurationSec = max(0, durationSec - previousSplitsDurationSec)
        let paceMinPerKm: Double = splitDurationSec > 0
            ? Double(splitDurationSec) / 60.0
            : 0.0

        let newSplit = KmSplit(
            kmNumber: kmNumber,
            durationSec: splitDurationSec,
            paceMinPerKm: paceMinPerKm
        )
        splits.append(newSplit)
        lastBucketKm = bucket

        // Flash the new split. Cancel any in-flight hide so the new
        // card displaces the old one cleanly rather than disappearing
        // mid-fade.
        hideTask?.cancel()
        visibleSplit = newSplit
        hideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.4)) {
                visibleSplit = nil
            }
        }
    }

    // MARK: - Card

    private func splitCard(_ split: KmSplit) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.turquoise60.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: "speedometer")
                    .font(.title3)
                    .foregroundColor(.turquoise60)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "Km %d: %@", split.kmNumber, formatHMS(split.durationSec)))
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(String(format: "%@/km", formatPace(split.paceMinPerKm)))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.turquoise60.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
    }

    // MARK: - Format helpers

    private func formatHMS(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, sec)
        }
        return String(format: "%d:%02d", m, sec)
    }

    private func formatPace(_ paceMinPerKm: Double) -> String {
        guard paceMinPerKm.isFinite, paceMinPerKm > 0 else { return "--:--" }
        let m = Int(paceMinPerKm)
        let s = Int((paceMinPerKm - Double(m)) * 60.0)
        return String(format: "%d:%02d", m, s)
    }
}

/// One completed km within an active walk. Mirrors Android `KmSplit`
/// (`app/src/main/java/com/woofwalk/data/model/KmSplit.kt` equivalent).
struct KmSplit: Equatable, Identifiable {
    /// 1-based kilometre number that just completed.
    let kmNumber: Int
    /// Wall-clock seconds spent inside this km bucket.
    let durationSec: Int
    /// Pace for this km in min/km (fractional).
    let paceMinPerKm: Double

    var id: Int { kmNumber }
}
