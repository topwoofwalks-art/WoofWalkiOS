import SwiftUI
import UIKit

/// How the walker chose to send the safety link to their guardian. Mirrors
/// Android `WatchSendMethod`.
enum WatchSendMethod {
    case whatsApp
    case sms
    case none
}

/// Full-screen splash shown the moment a Watch Me share event fires.
/// Bridges the context switch to WhatsApp / SMS so the walker has clear
/// guidance ("send your safety message, then come back") and the app
/// knows when to dismiss + resume normal walk UI.
///
/// Detection strategy: observes `scenePhase`. The instant the app
/// transitions through `.inactive`/`.background` → `.active` (the user
/// left for WhatsApp / SMS and came back), we infer the share was
/// completed and auto-dismiss after a short fade. Manual "Done" button
/// is always available for users who want explicit control.
///
/// The walk is already running in the background by the time this splash
/// is shown — GPS warmup, foreground service, safety-watch CF all started
/// in parallel via the existing flow. The splash is purely a UI gate so
/// the walker doesn't lose context between tapping "WhatsApp" and seeing
/// the walk-progress card.
///
/// Mirrors Android `WatchMeSendingSplash.kt`.
struct WatchMeSendingSplash: View {

    let sendMethod: WatchSendMethod
    let shareText: String
    let shareUrl: String
    let guardianPhones: [String]
    let onDismiss: () -> Void

    @Environment(\.scenePhase) private var scenePhase

    /// Tracks whether `.inactive` or `.background` has been observed since
    /// the splash mounted. Without this, the very first `.active` could
    /// fire on initial composition and we'd dismiss instantly without
    /// ever opening WhatsApp.
    @State private var hasLeftApp = false
    @State private var hasReturned = false
    @State private var intentFired = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.039, green: 0.165, blue: 0.302),
                    Color(red: 0.063, green: 0.227, blue: 0.420),
                    Color(red: 0.039, green: 0.165, blue: 0.302)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                statusDisc
                Spacer().frame(height: 28)
                Text(headlineText)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Spacer().frame(height: 10)
                Text(detailText)
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                Spacer().frame(height: 36)

                // Manual override — explicit "I sent it" + Skip for users
                // who want control or whose `.background` didn't fire
                // (in-app multi-window mode, system pop-overs, etc).
                if !hasReturned {
                    Button(action: { hasReturned = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                            Text("I've sent it — start walk")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(Color(red: 0.039, green: 0.165, blue: 0.302))
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    Spacer().frame(height: 10)
                    Button("Skip and start walk", action: onDismiss)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 24)
        }
        .onAppear { fireShareIntent() }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .inactive, .background:
                hasLeftApp = true
            case .active:
                if hasLeftApp { hasReturned = true }
            @unknown default:
                break
            }
        }
        .onChange(of: hasReturned) { returned in
            if returned {
                // Short hold so the walker can read the "Got it!" tick before
                // we hand control back. Without it the transition feels like
                // an abrupt cut.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    onDismiss()
                }
            }
        }
    }

    // MARK: - Status disc

    @ViewBuilder
    private var statusDisc: some View {
        if hasReturned {
            ZStack {
                Circle()
                    .fill(Color(red: 0.180, green: 0.800, blue: 0.443))
                    .frame(width: 120, height: 120)
                Image(systemName: "checkmark")
                    .font(.system(size: 54, weight: .bold))
                    .foregroundColor(.white)
            }
            .transition(.opacity)
        } else {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 120, height: 120)
                if hasLeftApp {
                    // Walker is in the messaging app. Steady icon, not
                    // a spinner — they're not waiting on us.
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 54))
                        .foregroundColor(.white)
                } else {
                    // Pre-launch handoff window (typically <200 ms).
                    ProgressView()
                        .scaleEffect(2)
                        .tint(.white)
                }
            }
        }
    }

    // MARK: - Copy

    private var headlineText: String {
        if hasReturned { return "Got it — you're being watched" }
        if hasLeftApp { return "Send the message" }
        switch sendMethod {
        case .whatsApp: return "Opening WhatsApp…"
        case .sms:      return "Opening Messages…"
        case .none:     return ""
        }
    }

    private var detailText: String {
        if hasReturned { return "Starting your walk now." }
        if hasLeftApp {
            switch sendMethod {
            case .whatsApp: return "Tap Send in WhatsApp, then come back here."
            case .sms:      return "Tap Send in Messages, then come back here."
            case .none:     return ""
            }
        }
        return "We'll know when you've sent it and start the walk."
    }

    // MARK: - Share-intent launch

    private func fireShareIntent() {
        if intentFired { return }
        intentFired = true

        if sendMethod == .none {
            // No share to perform — dismiss immediately so the splash
            // never flashes for skip-flow walks.
            DispatchQueue.main.async { onDismiss() }
            return
        }

        switch sendMethod {
        case .whatsApp:
            launchWhatsApp()
        case .sms:
            launchSMS()
        case .none:
            break
        }
    }

    private func launchWhatsApp() {
        // wa.me deep-link with pre-filled text. Picks the first guardian
        // phone number if available, else opens WhatsApp's contact picker
        // for the user to choose.
        let phone = guardianPhones.first
            .map { $0.filter { $0.isNumber || $0 == "+" } }?
            .replacingOccurrences(of: "+", with: "") ?? ""
        let encoded = shareText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString: String
        if !phone.isEmpty {
            urlString = "https://wa.me/\(phone)?text=\(encoded)"
        } else {
            urlString = "https://wa.me/?text=\(encoded)"
        }
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url, options: [:]) { opened in
            if !opened {
                // WhatsApp not installed — fall back to SMS.
                print("[WatchMeSplash] WhatsApp open failed — falling back to SMS")
                self.launchSMS()
            }
        }
    }

    private func launchSMS() {
        // Multi-recipient SMS via the `sms:` URL scheme. Comma-separated
        // numbers in the URL; body parameter carries the text.
        let recipients = guardianPhones
            .map { $0.filter { $0.isNumber || $0 == "+" } }
            .filter { !$0.isEmpty }
            .joined(separator: ",")
        let encoded = shareText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString: String
        if !recipients.isEmpty {
            urlString = "sms:\(recipients)&body=\(encoded)"
        } else {
            urlString = "sms:&body=\(encoded)"
        }
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}
