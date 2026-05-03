import SwiftUI
import AudioToolbox
import UIKit

/// Full-screen overlay that fires when the walker has been stationary for
/// 5+ minutes during an active SafetyWatch. Asks "Are you OK?" with two
/// big actions and an unmistakable audio + haptic cue so the walker
/// notices even with the phone in their pocket.
///
/// Intentionally NOT a small banner — the whole point is that this is
/// the *only* time the walker has to interact with the watch UI mid-walk,
/// so it gets the full surface.
///
/// Mirrors Android `CheckInPromptOverlay.kt`.
struct CheckInPromptOverlay: View {

    let onCheckIn: () -> Void
    let onPanic: () -> Void
    let onDismiss: () -> Void
    let actionInFlight: Bool

    @State private var hapticTimer: Timer?

    var body: some View {
        ZStack {
            Color.black.opacity(0.65)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { /* swallow taps behind the overlay */ }

            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(SafetyColors.amber.opacity(0.15))
                        .frame(width: 72, height: 72)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(SafetyColors.amber)
                }

                Spacer().frame(height: 16)

                Text("Are you OK?")
                    .font(.system(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 8)

                Text("You haven't moved for a few minutes. Your guardians are watching — let them know everything's fine, or raise an alert.")
                    .font(.system(size: 14))
                    .lineSpacing(4)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 24)

                // actionInFlight disables both buttons during the CF
                // round-trip so a frantic walker rapid-tapping I'M OK
                // doesn't stack 5 recordCheckIn calls (and a frantic
                // walker rapid-tapping ALERT doesn't get the panic CF
                // rate-limited and fail silently). The optimistic state
                // update gives immediate visual feedback; this just
                // guards the network leg.
                Button(action: onCheckIn) {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                        Text("YES — I'M OK")
                            .font(.system(size: 17, weight: .bold))
                            .kerning(1.0)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background(actionInFlight ? SafetyColors.green.opacity(0.4) : SafetyColors.green)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(actionInFlight)

                Spacer().frame(height: 10)

                // Long-press to confirm — prevents an accidental tap from
                // alarming a guardian's phone with a loud full-screen
                // klaxon. 1.5 s hold is short enough to feel snappy in a
                // real emergency. Visible progress fill + haptic on
                // start so the walker knows the gesture is being
                // recognised.
                PanicHoldButton(enabled: !actionInFlight, onPanic: onPanic)

                Spacer().frame(height: 12)

                Button("Dismiss for now", action: onDismiss)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(24)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(24)
        }
        .onAppear {
            playAlertOnce()
            startHapticLoop()
        }
        .onDisappear {
            hapticTimer?.invalidate()
            hapticTimer = nil
        }
    }

    private func startHapticLoop() {
        var fires = 0
        triggerHaptic()
        hapticTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
            fires += 1
            triggerHaptic()
            if fires >= 4 { timer.invalidate() }
        }
    }

    private func playAlertOnce() {
        // System sound 1007 = "tritone" notification. Volume-aware (does
        // NOT respect ringer mute on iOS — perfect for a safety alert).
        AudioServicesPlaySystemSound(1007)
    }

    private func triggerHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
}

// MARK: - Panic Hold Button

/// Press-and-hold confirmation button for the PANIC action.
///
/// Why long-press: PANIC fires a loud alarm-tier full-screen takeover on
/// the guardian's phone. Accidentally tapping it because the walker
/// fumbled the I'M OK button is a real risk — and one false alarm could
/// be enough to kill trust in the feature.
///
/// Mechanics:
/// - Press to start a 1.5 s hold timer + visible left-to-right fill
/// - Light haptic on press start so the walker knows the gesture
///   registered
/// - Release before completion → silent cancel (no alert)
/// - Hold to completion → onPanic fires + heavier haptic confirmation
struct PanicHoldButton: View {
    let enabled: Bool
    let onPanic: () -> Void

    @State private var isPressed = false
    @State private var progress: Double = 0
    @State private var holdTimer: Timer?

    private let holdDuration: Double = 1.5

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 28)
                .fill(SafetyColors.red.opacity(enabled ? 1.0 : 0.4))
                .frame(maxWidth: .infinity, minHeight: 60)

            // Left-anchored fill that grows with progress — gives the
            // walker a visible "you're holding it, don't release yet"
            // signal.
            GeometryReader { geo in
                Color.white.opacity(0.22)
                    .frame(width: geo.size.width * progress)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
            }
            .frame(maxWidth: .infinity, minHeight: 60)

            HStack {
                Spacer()
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 22))
                    Text(isPressed ? "Hold to alert…" : "Hold to RAISE ALERT")
                        .font(.system(size: 17, weight: .bold))
                        .kerning(1.0)
                }
                .foregroundColor(.white)
                Spacer()
            }
            .frame(minHeight: 60)
        }
        .frame(maxWidth: .infinity, minHeight: 60)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !enabled { return }
                    if !isPressed { startHold() }
                }
                .onEnded { _ in
                    cancelHold()
                }
        )
    }

    private func startHold() {
        isPressed = true
        progress = 0

        // Light haptic on press start.
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        let tickInterval: Double = 0.05
        holdTimer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { timer in
            progress += tickInterval / holdDuration
            if progress >= 1.0 {
                timer.invalidate()
                completeHold()
            }
        }
    }

    private func completeHold() {
        // Heavy confirmation haptic + fire panic.
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)

        onPanic()
        progress = 0
        isPressed = false
        holdTimer?.invalidate()
        holdTimer = nil
    }

    private func cancelHold() {
        holdTimer?.invalidate()
        holdTimer = nil
        if progress < 1.0 {
            progress = 0
            isPressed = false
        }
    }
}
