import Foundation
import WatchKit
import CoreMotion
import CoreLocation

class WatchSettings: ObservableObject {
    static let shared = WatchSettings()

    // Feature toggles (synced from phone)
    @Published var heartRateEnabled: Bool {
        didSet { UserDefaults.standard.set(heartRateEnabled, forKey: "heart_rate_enabled") }
    }
    @Published var dmsEnabled: Bool {
        didSet { UserDefaults.standard.set(dmsEnabled, forKey: "dms_enabled") }
    }
    @Published var dmsIntervalMinutes: Int {
        didSet { UserDefaults.standard.set(dmsIntervalMinutes, forKey: "dms_interval_minutes") }
    }
    @Published var compassEnabled: Bool {
        didSet { UserDefaults.standard.set(compassEnabled, forKey: "compass_enabled") }
    }
    @Published var messagesEnabled: Bool {
        didSet { UserDefaults.standard.set(messagesEnabled, forKey: "messages_enabled") }
    }
    @Published var hazardAlertsEnabled: Bool {
        didSet { UserDefaults.standard.set(hazardAlertsEnabled, forKey: "hazard_alerts_enabled") }
    }
    @Published var walkInviteAlertsEnabled: Bool {
        didSet { UserDefaults.standard.set(walkInviteAlertsEnabled, forKey: "walk_invite_alerts_enabled") }
    }
    @Published var healthRemindersEnabled: Bool {
        didSet { UserDefaults.standard.set(healthRemindersEnabled, forKey: "health_reminders_enabled") }
    }
    @Published var paceDetectionEnabled: Bool {
        didSet { UserDefaults.standard.set(paceDetectionEnabled, forKey: "pace_detection_enabled") }
    }
    @Published var findCarEnabled: Bool {
        didSet { UserDefaults.standard.set(findCarEnabled, forKey: "find_car_enabled") }
    }
    @Published var autoSaveCarLocation: Bool {
        didSet { UserDefaults.standard.set(autoSaveCarLocation, forKey: "auto_save_car_location") }
    }

    // Hardware capabilities (detected on device)
    var hasHeartRate: Bool { HKHealthStore.isHealthDataAvailable() }
    var hasGps: Bool { CLLocationManager.locationServicesEnabled() }
    var hasMagnetometer: Bool { CMMotionManager().isMagnetometerAvailable }
    var hasAccelerometer: Bool { CMMotionManager().isAccelerometerAvailable }
    var hasHaptics: Bool { WKInterfaceDevice.current().supportsHaptics() }
    var watchModel: String { WKInterfaceDevice.current().model }
    var watchOS: String { "watchOS \(WKInterfaceDevice.current().systemVersion)" }

    private init() {
        let defaults = UserDefaults.standard
        heartRateEnabled = defaults.bool(forKey: "heart_rate_enabled")
        dmsEnabled = defaults.bool(forKey: "dms_enabled")
        dmsIntervalMinutes = defaults.object(forKey: "dms_interval_minutes") as? Int ?? 15
        compassEnabled = defaults.object(forKey: "compass_enabled") as? Bool ?? true
        messagesEnabled = defaults.object(forKey: "messages_enabled") as? Bool ?? true
        hazardAlertsEnabled = defaults.object(forKey: "hazard_alerts_enabled") as? Bool ?? true
        walkInviteAlertsEnabled = defaults.object(forKey: "walk_invite_alerts_enabled") as? Bool ?? true
        healthRemindersEnabled = defaults.object(forKey: "health_reminders_enabled") as? Bool ?? true
        paceDetectionEnabled = defaults.object(forKey: "pace_detection_enabled") as? Bool ?? true
        findCarEnabled = defaults.bool(forKey: "find_car_enabled")
        autoSaveCarLocation = defaults.bool(forKey: "auto_save_car_location")
    }

    func applySettings(_ data: [String: Any]) {
        if let v = data["heart_rate_enabled"] as? Bool { heartRateEnabled = v }
        if let v = data["dms_enabled"] as? Bool { dmsEnabled = v }
        if let v = data["dms_interval_minutes"] as? Int { dmsIntervalMinutes = v }
        if let v = data["compass_enabled"] as? Bool { compassEnabled = v }
        if let v = data["messages_enabled"] as? Bool { messagesEnabled = v }
        if let v = data["hazard_alerts_enabled"] as? Bool { hazardAlertsEnabled = v }
        if let v = data["walk_invite_alerts_enabled"] as? Bool { walkInviteAlertsEnabled = v }
        if let v = data["health_reminders_enabled"] as? Bool { healthRemindersEnabled = v }
        if let v = data["pace_detection_enabled"] as? Bool { paceDetectionEnabled = v }
        if let v = data["find_car_enabled"] as? Bool { findCarEnabled = v }
        if let v = data["auto_save_car_location"] as? Bool { autoSaveCarLocation = v }
        print("[WatchSettings] Settings applied from phone")
    }

    func sendCapabilitiesToPhone() {
        let capabilities: [String: Any] = [
            "type": "watch_capabilities",
            "has_heart_rate": hasHeartRate,
            "has_gps": hasGps,
            "has_magnetometer": hasMagnetometer,
            "has_accelerometer": hasAccelerometer,
            "has_haptics": hasHaptics,
            "watch_model": watchModel,
            "watch_os": watchOS,
            "timestamp": Date().timeIntervalSince1970
        ]
        WatchSessionManager.shared.session?.sendMessage(capabilities, replyHandler: nil)
    }
}

import HealthKit
import WatchConnectivity
