import SwiftUI
import MapKit
import AVFoundation
import AudioToolbox
import UIKit
import CoreLocation

/// Full-screen takeover shown when an FCM `type: "panicAlert"` payload
/// lands while the app is running (or is brought up by the notification
/// tap when backgrounded). Counterpart to Android
/// `PanicAlarmActivity.kt` — same forced-choice UI: see on map / call
/// the walker / call 999 / acknowledge.
///
/// Why a full-screen cover rather than a plain alert?
/// ----------------------------------------------------
/// A guardian receiving this push needs to *act* — not flick a
/// notification away. The sheet:
///   * blocks the whole screen in red,
///   * plays a looping siren via AVAudioPlayer (system alarm if a
///     bundled `panic_siren` asset is missing — the alert tone via
///     AudioServicesPlaySystemSound 1336 is the fallback),
///   * surfaces the walker's last-known GPS pin so the guardian can
///     orient + drive to them.
///
/// The siren stops on dismiss. There is intentionally NO swipe-to-dismiss
/// gesture — the only ways out are the four buttons.
///
/// Payload keys (mirrors Android FCM data block sent by
/// `functions/src/safety/watchMe.ts:triggerSafetyWatchPanic`):
///   * `watchId`              — the SafetyWatch doc id (for deep linking)
///   * `walkerFirstName`      — e.g. "Sam"
///   * `walkerPhone`          — optional; if present, "Call walker" dials it
///   * `lat`, `lng`           — last-known GPS fix
///   * `lastUpdatedAt`        — ms epoch, for "X mins ago" labelling
struct PanicAlarmSheet: View {
    let payload: [AnyHashable: Any]
    let onDismiss: () -> Void

    @State private var audioPlayer: AVAudioPlayer?
    @State private var systemSoundTimer: Timer?
    @State private var region: MKCoordinateRegion

    init(payload: [AnyHashable: Any], onDismiss: @escaping () -> Void) {
        self.payload = payload
        self.onDismiss = onDismiss
        // Pre-seed the camera to the walker's last-known fix if present.
        let lat = PanicAlarmSheet.doubleFromPayload(payload, keys: ["lat", "lastLat"])
        let lng = PanicAlarmSheet.doubleFromPayload(payload, keys: ["lng", "lon", "lastLng"])
        let center: CLLocationCoordinate2D
        let span: MKCoordinateSpan
        if let lat, let lng, lat != 0 || lng != 0 {
            center = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            span = MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        } else {
            center = CLLocationCoordinate2D(latitude: 54.5, longitude: -2.5)
            span = MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)
        }
        _region = State(initialValue: MKCoordinateRegion(center: center, span: span))
    }

    private var walkerFirstName: String {
        let raw = (payload["walkerFirstName"] as? String) ?? (payload["walkerName"] as? String) ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Your friend" : trimmed
    }

    private var walkerPhone: String? {
        let raw = (payload["walkerPhone"] as? String) ?? (payload["phone"] as? String)
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty ?? true) ? nil : trimmed
    }

    private var lastFix: CLLocationCoordinate2D? {
        let lat = PanicAlarmSheet.doubleFromPayload(payload, keys: ["lat", "lastLat"])
        let lng = PanicAlarmSheet.doubleFromPayload(payload, keys: ["lng", "lon", "lastLng"])
        guard let lat, let lng, lat != 0 || lng != 0 else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    private var lastUpdatedLabel: String? {
        let ms = PanicAlarmSheet.int64FromPayload(payload, keys: ["lastUpdatedAt", "panicTriggeredAt"])
        guard ms > 0 else { return nil }
        let sec = max(0, Int64(Date().timeIntervalSince1970 * 1000) - ms) / 1000
        switch sec {
        case ..<30: return "just now"
        case ..<60: return "\(sec)s ago"
        case ..<3600: return "\(sec / 60)m ago"
        default: return "\(sec / 3600)h \((sec % 3600) / 60)m ago"
        }
    }

    var body: some View {
        ZStack {
            Color.panicRed
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 96, height: 96)
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 56, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 32)

                    Text("PANIC")
                        .font(.system(size: 18, weight: .bold))
                        .tracking(6)
                        .foregroundColor(.white)

                    Text("\(walkerFirstName) triggered an alert")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    if let label = lastUpdatedLabel {
                        Text("Last GPS · \(label)")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }

                // Map preview of last-known fix (or fallback message).
                Group {
                    if let fix = lastFix {
                        Map(
                            coordinateRegion: $region,
                            annotationItems: [PanicPin(coordinate: fix)]
                        ) { pin in
                            MapAnnotation(coordinate: pin.coordinate) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 38, height: 38)
                                    Image(systemName: "figure.walk")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.panicRed)
                                }
                            }
                        }
                        .frame(height: 220)
                        .cornerRadius(14)
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                    } else {
                        VStack(spacing: 6) {
                            Image(systemName: "location.slash.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                            Text("No GPS fix yet")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Text("Open the live map to see when their phone reports in.")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(14)
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                    }
                }

                Spacer(minLength: 16)

                // Actions
                VStack(spacing: 12) {
                    Button(action: dial999) {
                        Label("Call 999", systemImage: "phone.connection.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .foregroundColor(.panicRed)
                            .cornerRadius(14)
                    }

                    if walkerPhone != nil {
                        Button(action: callWalker) {
                            Label("Call \(walkerFirstName)", systemImage: "phone.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.panicRedAmber)
                                .foregroundColor(.white)
                                .cornerRadius(14)
                        }
                    }

                    Button(action: dismiss) {
                        Label("I've got it — dismiss", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.white.opacity(0.18))
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .interactiveDismissDisabled(true)
        .onAppear {
            startSiren()
        }
        .onDisappear {
            stopSiren()
        }
    }

    // MARK: - Actions

    private func dial999() {
        if let url = URL(string: "tel://999") {
            UIApplication.shared.open(url)
        }
        // Don't auto-dismiss after the dial — the user comes back to the
        // alarm context after the call finishes and can hit Dismiss.
    }

    private func callWalker() {
        guard let phone = walkerPhone else { return }
        let sanitized = phone.filter { "+0123456789".contains($0) }
        guard !sanitized.isEmpty, let url = URL(string: "tel://\(sanitized)") else { return }
        UIApplication.shared.open(url)
    }

    private func dismiss() {
        stopSiren()
        onDismiss()
    }

    // MARK: - Siren

    /// Starts the alarm audio loop. Prefers the bundled `panic_siren`
    /// asset (mp3/caf/wav) if present — falls back to a periodic system
    /// alert tone so the alarm still fires on a vanilla build.
    private func startSiren() {
        // Try to set up an audio session that breaks through silent mode.
        // `.playback` is the right category for an alarm-style sound that
        // should be heard even with the ringer switch flipped to silent.
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.duckOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true, options: [])
        } catch {
            print("[PanicAlarm] AVAudioSession setup failed: \(error.localizedDescription)")
        }

        if let url = Self.findBundledSiren() {
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.numberOfLoops = -1 // loop forever until dismiss
                player.volume = 1.0
                player.prepareToPlay()
                player.play()
                self.audioPlayer = player
                return
            } catch {
                print("[PanicAlarm] AVAudioPlayer failed for \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }

        // Fallback: looping system alert tone. 1336 is the
        // SystemSoundID for a sharp emergency-style alert; we re-fire
        // every 1.4s for a continuous siren feel.
        AudioServicesPlaySystemSound(1336)
        systemSoundTimer = Timer.scheduledTimer(withTimeInterval: 1.4, repeats: true) { _ in
            AudioServicesPlaySystemSound(1336)
        }
    }

    private func stopSiren() {
        audioPlayer?.stop()
        audioPlayer = nil
        systemSoundTimer?.invalidate()
        systemSoundTimer = nil
        // Don't tear down AVAudioSession — leaving it active is harmless
        // and avoids racing other audio components mid-dismiss.
    }

    /// Looks for a bundled siren asset by common names + extensions.
    /// Returns nil if none is present, in which case the caller falls
    /// back to AudioServicesPlaySystemSound.
    private static func findBundledSiren() -> URL? {
        let names = ["panic_siren", "panic_alarm", "siren"]
        let exts = ["mp3", "caf", "wav", "m4a"]
        for name in names {
            for ext in exts {
                if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                    return url
                }
            }
        }
        return nil
    }

    // MARK: - Payload helpers

    private static func doubleFromPayload(_ p: [AnyHashable: Any], keys: [String]) -> Double? {
        for k in keys {
            if let v = p[k] {
                if let d = v as? Double { return d }
                if let n = v as? NSNumber { return n.doubleValue }
                if let s = v as? String, let d = Double(s) { return d }
            }
        }
        return nil
    }

    private static func int64FromPayload(_ p: [AnyHashable: Any], keys: [String]) -> Int64 {
        for k in keys {
            if let v = p[k] {
                if let n = v as? Int64 { return n }
                if let n = v as? Int { return Int64(n) }
                if let n = v as? Double { return Int64(n) }
                if let n = v as? NSNumber { return n.int64Value }
                if let s = v as? String, let n = Int64(s) { return n }
            }
        }
        return 0
    }
}

// MARK: - Map annotation

/// Identifiable wrapper for the single "walker last fix" pin on the
/// iOS-16-compatible `Map(coordinateRegion:annotationItems:)` API.
private struct PanicPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Colours

private extension Color {
    /// Same red as Android's `SafetyRed` (0xFFDC2626) — kept locally so
    /// PanicAlarmSheet has no hard dependency on `SafetyColors` being in
    /// the same compilation unit on every build.
    static let panicRed = Color(red: 0.863, green: 0.149, blue: 0.149)
    /// Secondary action background — matches the Android amber-on-red
    /// "Call 999" treatment in `PanicAlarmActivity`.
    static let panicRedAmber = Color(red: 0.851, green: 0.463, blue: 0.024)
}
