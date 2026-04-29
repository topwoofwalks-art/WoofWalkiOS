import CoreLocation
import SwiftUI
import WatchKit

/// Watch SOS — hold-to-fire panic button. The wearer holds for 2 seconds
/// to dispatch. Sends current GPS to the iPhone over WatchConnectivity;
/// the phone-side WatchSessionManager (in WoofWalk app) writes
/// `/sos_alerts/{auto}` and the `onSosAlertCreate` Cloud Function fans
/// out an FCM push to every emergency contact on the user's profile.
///
/// We don't write to Firestore directly from the Watch — Watch network
/// path is unreliable, and the phone has the auth context anyway.
struct SosView: View {
    @EnvironmentObject var sessionManager: WatchSessionManager
    @StateObject private var locator = SosLocator()
    @State private var holdProgress: Double = 0  // 0...1
    @State private var holding = false
    @State private var fired = false
    @State private var fireTimestamp = Date.distantPast

    private let holdSeconds: Double = 2.0

    var body: some View {
        VStack(spacing: 6) {
            Text("Emergency")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color.red.opacity(0.9))

            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.red.opacity(0.25), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: holdProgress)
                    .stroke(Color.red, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.05), value: holdProgress)

                VStack(spacing: 2) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.red)
                    if fired {
                        Text("Sent")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.green)
                    } else {
                        Text(holding ? "Hold…" : "Hold to send")
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                    }
                }
            }
            .frame(width: 100, height: 100)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in startHold() }
                    .onEnded { _ in cancelHold() }
            )

            Spacer()

            Text(fired
                ? "Help is being notified."
                : "Press and hold to alert your contacts.")
                .font(.system(size: 10))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
        }
        .padding(8)
        .onAppear {
            locator.start()
            // If user lingers on this tab > 5s after firing, reset so
            // they can retry without backing out (e.g. they need to
            // resend after moving).
            if fired, Date().timeIntervalSince(fireTimestamp) > 30 {
                fired = false
            }
        }
        .onDisappear {
            locator.stop()
            cancelHold()
        }
    }

    private func startHold() {
        guard !fired else { return }
        if !holding {
            holding = true
            holdProgress = 0
            WKInterfaceDevice.current().play(.start)
            tickHold()
        }
    }

    private func tickHold() {
        guard holding else { return }
        let increment = 0.05 / holdSeconds
        holdProgress = min(1.0, holdProgress + increment)
        if holdProgress >= 1.0 {
            fire()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            tickHold()
        }
    }

    private func cancelHold() {
        if holding && !fired {
            holding = false
            holdProgress = 0
        }
    }

    private func fire() {
        holding = false
        fired = true
        fireTimestamp = Date()
        WKInterfaceDevice.current().play(.notification)
        WKInterfaceDevice.current().play(.failure)

        let coord = locator.lastCoordinate
        sessionManager.sendSOS(
            lat: coord?.latitude ?? 0,
            lng: coord?.longitude ?? 0
        )
    }
}

// MARK: - Lightweight on-Watch GPS

private final class SosLocator: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var lastCoordinate: CLLocationCoordinate2D?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func start() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastCoordinate = locations.last?.coordinate
    }
}
