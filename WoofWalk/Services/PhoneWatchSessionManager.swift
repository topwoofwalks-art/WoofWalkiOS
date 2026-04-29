import Foundation
import WatchConnectivity
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

/// Phone-side counterpart to `WoofWalkWatch/WatchSessionManager`. The
/// Watch sends WatchConnectivity messages on events (SOS, DMS-OK,
/// car-save, quick-reply, walk-data sync) and this class is what
/// receives them on the phone side and bridges to Firestore.
///
/// Why on the phone, not in the Watch's own code: Watch network
/// connectivity is unreliable and there's no signed-in Firebase
/// session there. The phone has Auth, has Firestore, and has a stable
/// connection — so the Watch just signals what happened, and the
/// phone does the actual write.
///
/// Activate from `WoofWalkApp` at boot:
///     PhoneWatchSessionManager.shared.activate()
final class PhoneWatchSessionManager: NSObject, ObservableObject {
    static let shared = PhoneWatchSessionManager()

    private var session: WCSession?
    private let db = Firestore.firestore()

    @Published var lastSosTimestamp: Date?

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }

    // MARK: - Outbound (phone → watch)

    /// Push notification → Watch. Used when the phone has a fresh
    /// chat / booking message worth surfacing on the wrist.
    func sendNotificationToWatch(title: String, body: String) {
        let data: [String: Any] = [
            "type": "notification",
            "title": title,
            "body": body,
            "timestamp": Date().timeIntervalSince1970,
        ]
        try? session?.updateApplicationContext(data)
    }

    /// Trigger DMS prompt on the watch — if the wearer doesn't tap OK
    /// within the timeout, the WalkSafetyMonitor on the phone fires
    /// an SOS itself (so the watcher's emergency contacts still get
    /// notified even if the wearer is unconscious).
    func sendDmsCheck() {
        let data: [String: Any] = [
            "type": "dms_check",
            "timestamp": Date().timeIntervalSince1970,
        ]
        session?.sendMessage(data, replyHandler: nil) { err in
            print("[PhoneWatchSession] dms_check send failed: \(err)")
        }
    }
}

// MARK: - WCSessionDelegate

extension PhoneWatchSessionManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("[PhoneWatchSession] activation: \(activationState.rawValue) err: \(error?.localizedDescription ?? "none")")
    }

    func sessionDidBecomeInactive(_ session: WCSession) { }

    func sessionDidDeactivate(_ session: WCSession) {
        // Per Apple guidance: re-activate after deactivation so the
        // app can pair to a different Watch on the same phone.
        WCSession.default.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async { self.handle(message) }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async { self.handle(applicationContext) }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        DispatchQueue.main.async { self.handle(userInfo) }
    }

    private func handle(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { return }
        switch type {
        case "sos":
            let lat = message["lat"] as? Double ?? 0
            let lng = message["lng"] as? Double ?? 0
            Task { await self.dispatchSos(lat: lat, lng: lng) }

        case "dms_ok":
            // Wearer tapped OK on the DMS prompt — clear any pending
            // escalation. WalkSafetyMonitor watches for this Firestore
            // doc instead of holding state in memory, so a phone
            // restart mid-walk doesn't lose the ack.
            Task { await self.recordDmsOk() }

        case "car_save":
            let lat = message["lat"] as? Double ?? 0
            let lng = message["lng"] as? Double ?? 0
            Task { await self.recordCarLocation(lat: lat, lng: lng) }

        case "quick_reply":
            // Forwarded to the chat surface to send as a real message.
            // For now we just log — wiring into ChatRepository is a
            // separate handoff.
            print("[PhoneWatchSession] quick_reply → \(message["sender_id"] ?? "?"): \(message["reply"] ?? "")")

        default:
            print("[PhoneWatchSession] unknown type: \(type)")
        }
    }

    // MARK: - Firestore writes

    private func dispatchSos(lat: Double, lng: Double) async {
        guard Auth.auth().currentUser?.uid != nil else {
            print("[PhoneWatchSession] SOS but no signed-in user — dropping")
            return
        }
        // Route through the triggerSosAlert callable so the write
        // bypasses Firestore rules (we don't have a rules block for
        // /sos_alerts — see firebase rules-release ceiling note).
        let functions = Functions.functions(region: "europe-west2")
        do {
            let result = try await functions
                .httpsCallable("triggerSosAlert")
                .call([
                    "lat": lat,
                    "lng": lng,
                    "source": "watch",
                ])
            self.lastSosTimestamp = Date()
            if let data = result.data as? [String: Any],
               let id = data["alertId"] as? String {
                print("[PhoneWatchSession] SOS recorded \(id)")
            }
        } catch {
            print("[PhoneWatchSession] SOS CF call failed: \(error)")
        }
    }

    private func recordDmsOk() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        // Update the user's currently-active DMS doc, if any. We use
        // a per-user single-doc pattern keyed by uid because there's
        // only ever one in-flight DMS per wearer.
        try? await db.collection("dms_status").document(uid).setData([
            "lastAckAt": FieldValue.serverTimestamp(),
            "status": "OK",
        ], merge: true)
    }

    private func recordCarLocation(lat: Double, lng: Double) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try? await db.collection("users").document(uid).setData([
            "carLocation": [
                "lat": lat,
                "lng": lng,
                "savedAt": FieldValue.serverTimestamp(),
            ],
        ], merge: true)
    }
}
