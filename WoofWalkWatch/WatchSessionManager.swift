import Foundation
import WatchConnectivity

class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    @Published var dmsActive = false
    @Published var messages: [WatchMessage] = []
    @Published var activeRoute: WatchRoute?
    @Published var carLocation: (lat: Double, lng: Double)?

    private var session: WCSession?

    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
        }
    }

    func activate() {
        session?.activate()
    }

    // MARK: - Send to Phone

    func syncWalkData(tracker: WalkTracker) {
        let data: [String: Any] = [
            "gps_lats": tracker.gpsPoints.map { $0.lat },
            "gps_lngs": tracker.gpsPoints.map { $0.lng },
            "gps_alts": tracker.gpsPoints.map { $0.alt },
            "gps_speeds": tracker.gpsPoints.map { $0.speed },
            "distance_km": tracker.distanceKm,
            "duration_seconds": tracker.durationSeconds,
            "heart_rate": tracker.heartRate,
            "timestamp": Date().timeIntervalSince1970
        ]
        session?.transferUserInfo(data)
    }

    func sendSOS(lat: Double, lng: Double) {
        let data: [String: Any] = [
            "type": "sos",
            "lat": lat,
            "lng": lng,
            "timestamp": Date().timeIntervalSince1970
        ]
        try? session?.updateApplicationContext(data)
        session?.sendMessage(data, replyHandler: nil)
    }

    func sendDmsOk() {
        dmsActive = false
        let data: [String: Any] = [
            "type": "dms_ok",
            "timestamp": Date().timeIntervalSince1970
        ]
        session?.sendMessage(data, replyHandler: nil)
    }

    func saveCarLocation(lat: Double, lng: Double) {
        guard lat != 0 || lng != 0 else { return }
        let data: [String: Any] = [
            "type": "car_save",
            "lat": lat,
            "lng": lng,
            "timestamp": Date().timeIntervalSince1970
        ]
        session?.sendMessage(data, replyHandler: nil)
    }

    func sendQuickReply(senderId: String, reply: String) {
        let data: [String: Any] = [
            "type": "quick_reply",
            "sender_id": senderId,
            "reply": reply,
            "timestamp": Date().timeIntervalSince1970
        ]
        session?.sendMessage(data, replyHandler: nil)
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("[WatchSession] Activation: \(activationState.rawValue)")
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            self.handleMessage(message)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            self.handleMessage(applicationContext)
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        DispatchQueue.main.async {
            self.handleMessage(userInfo)
        }
    }

    private func handleMessage(_ message: [String: Any]) {
        if let type = message["type"] as? String {
            switch type {
            case "settings":
                WatchSettings.shared.applySettings(message)
            case "dms_check":
                dmsActive = true
                WKInterfaceDevice.current().play(.notification)
            case "messages":
                if let msgArray = message["messages"] as? [[String: Any]] {
                    messages = msgArray.compactMap { WatchMessage(from: $0) }
                }
            case "route":
                if let routeData = message["route"] as? [String: Any] {
                    activeRoute = WatchRoute(from: routeData)
                }
            case "car_location":
                if let lat = message["lat"] as? Double, let lng = message["lng"] as? Double {
                    carLocation = (lat: lat, lng: lng)
                }
            case "notification":
                // Handle push notification on watch
                let title = message["title"] as? String ?? "WoofWalk"
                let body = message["body"] as? String ?? ""
                WKInterfaceDevice.current().play(.notification)
                print("[WatchSession] Notification: \(title) - \(body)")
            default:
                print("[WatchSession] Unknown message type: \(type)")
            }
        }
    }
}
