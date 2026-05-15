import Foundation
import UserNotifications
import UIKit
import FirebaseMessaging
import FirebaseAuth
import FirebaseFirestore

class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate, MessagingDelegate {
    static let shared = NotificationService()

    @Published var isAuthorized = false
    @Published var fcmToken: String?

    // MARK: - Notification Categories

    enum NotificationCategory: String, CaseIterable {
        case alerts = "ALERTS"
        case bookings = "BOOKINGS"
        case payments = "PAYMENTS"
        case messages = "MESSAGES"
        case walkUpdates = "WALK_UPDATES"
        case marketing = "MARKETING"
        case system = "SYSTEM"
        case streakReminders = "STREAK_REMINDERS"

        var displayName: String {
            switch self {
            case .alerts: return "Alerts"
            case .bookings: return "Bookings"
            case .payments: return "Payments"
            case .messages: return "Messages"
            case .walkUpdates: return "Walk Updates"
            case .marketing: return "Marketing"
            case .system: return "System"
            case .streakReminders: return "Streak Reminders"
            }
        }
    }

    // MARK: - Configuration

    func configure() {
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        registerCategories()
        checkAuthorizationStatus()
    }

    private func registerCategories() {
        let categories: Set<UNNotificationCategory> = Set(
            NotificationCategory.allCases.map { category in
                UNNotificationCategory(
                    identifier: category.rawValue,
                    actions: actionsForCategory(category),
                    intentIdentifiers: [],
                    options: .customDismissAction
                )
            }
        )
        UNUserNotificationCenter.current().setNotificationCategories(categories)
    }

    private func actionsForCategory(_ category: NotificationCategory) -> [UNNotificationAction] {
        switch category {
        case .messages:
            return [
                UNNotificationAction(identifier: "REPLY", title: "Reply", options: .foreground),
                UNNotificationAction(identifier: "MARK_READ", title: "Mark as Read", options: [])
            ]
        case .walkUpdates:
            return [
                UNNotificationAction(identifier: "VIEW_WALK", title: "View Walk", options: .foreground)
            ]
        case .bookings:
            return [
                UNNotificationAction(identifier: "VIEW_BOOKING", title: "View Booking", options: .foreground),
                UNNotificationAction(identifier: "CANCEL_BOOKING", title: "Cancel", options: .destructive)
            ]
        case .streakReminders:
            return [
                UNNotificationAction(identifier: "START_WALK", title: "Start Walk", options: .foreground),
                UNNotificationAction(identifier: "SNOOZE", title: "Remind Later", options: [])
            ]
        default:
            return []
        }
    }

    // MARK: - Permissions

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound, .provisional]
            )
            await MainActor.run {
                self.isAuthorized = granted
            }
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            return granted
        } catch {
            print("[NotificationService] Permission request failed: \(error.localizedDescription)")
            return false
        }
    }

    private func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional
            }
        }
    }

    // MARK: - Scheduling

    func scheduleStreakReminder(streakDays: Int, dogName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Keep your streak going!"
        content.body = "\(dogName) is waiting for walk #\(streakDays + 1). Don't break your \(streakDays)-day streak!"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.streakReminders.rawValue
        content.userInfo = ["type": "streak", "streakDays": streakDays]

        // Schedule for 6pm daily
        var dateComponents = DateComponents()
        dateComponents.hour = 18
        dateComponents.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: "streak_reminder_\(dogName)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[NotificationService] Failed to schedule streak reminder: \(error.localizedDescription)")
            }
        }
    }

    func scheduleMedicationReminder(medicationName: String, time: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Medication Reminder"
        content.body = "Time to give \(medicationName)"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.alerts.rawValue
        content.userInfo = ["type": "medication", "medicationName": medicationName]

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let identifier = "medication_\(medicationName.replacingOccurrences(of: " ", with: "_"))"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[NotificationService] Failed to schedule medication reminder: \(error.localizedDescription)")
            }
        }
    }

    func cancelAllReminders() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func cancelReminder(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [identifier]
        )
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .badge, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier

        handleNotificationAction(actionIdentifier: actionIdentifier, userInfo: userInfo)
        completionHandler()
    }

    // MARK: - FCM Token Handling

    func didReceiveRemoteNotificationToken(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("[NotificationService] APNs token: \(token)")
    }

    func didReceiveFCMToken(_ token: String?) {
        DispatchQueue.main.async {
            self.fcmToken = token
        }
        guard let token = token else { return }
        print("[NotificationService] FCM token: \(token)")
        persistFCMTokenToFirestore(token)
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        didReceiveFCMToken(fcmToken)
    }

    // MARK: - Firestore device-token sync

    /// Stable per-install identifier mirroring Android's
    /// `Settings.Secure.ANDROID_ID` use in `WoofWalkMessagingService`.
    /// `identifierForVendor` resets on full uninstall, which matches the
    /// Android behaviour and keeps the `users/{uid}/devices/{id}` doc
    /// scoped to a single physical install.
    private static let installationIdKey = "WoofWalk.installationId"

    private var installationId: String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: Self.installationIdKey), !existing.isEmpty {
            return existing
        }
        let fresh = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        defaults.set(fresh, forKey: Self.installationIdKey)
        return fresh
    }

    private var appVersionString: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(short) (\(build))"
    }

    private func persistFCMTokenToFirestore(_ token: String) {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("[NotificationService] Skipping FCM token write — no signed-in user")
            return
        }
        let deviceId = installationId
        let payload: [String: Any] = [
            "token": token,
            "platform": "ios",
            "updatedAt": FieldValue.serverTimestamp(),
            "appVersion": appVersionString
        ]
        Firestore.firestore()
            .collection("users")
            .document(uid)
            .collection("devices")
            .document(deviceId)
            .setData(payload, merge: true) { error in
                if let error = error {
                    print("[NotificationService] Failed to write FCM token: \(error.localizedDescription)")
                } else {
                    print("[NotificationService] FCM token written to users/\(uid)/devices/\(deviceId)")
                }
            }
    }

    // MARK: - Incoming remote notification routing
    //
    // Server payloads carry a `type` string (see Android
    // `WoofWalkMessagingService.onMessageReceived`). We re-broadcast each
    // type onto a `NotificationCenter` name that the relevant SwiftUI
    // screen already observes, and run the `actionUrl` deep-link mapper
    // afterwards so cash-request and other URL-driven flows still route
    // even when `type` is set.
    func handleRemoteNotification(userInfo: [AnyHashable: Any]) {
        let type = (userInfo["type"] as? String) ?? ""
        switch type {
        case "lost_dog_alert", "lostDogAlert":
            NotificationCenter.default.post(name: .lostDogAlertReceived, object: nil, userInfo: userInfo)
        case "walk_started", "WALK_STARTED":
            NotificationCenter.default.post(name: .startWalkFromNotification, object: nil, userInfo: userInfo)
        case "walk_update", "walk_completed", "WALK_UPDATE", "WALK_COMPLETED":
            NotificationCenter.default.post(name: .viewWalkFromNotification, object: nil, userInfo: userInfo)
        case "booking_reminder", "BOOKING_CONFIRMED", "BOOKING_CANCELLED",
             "BOOKING_REQUEST", "BOOKING_REMINDER", "bookingUpdate":
            NotificationCenter.default.post(name: .viewBookingFromNotification, object: nil, userInfo: userInfo)
        case "chat_message", "CHAT_MESSAGE", "MESSAGE_NEW", "MESSAGE_REPLY":
            NotificationCenter.default.post(name: .replyFromNotification, object: nil, userInfo: userInfo)
        default:
            NotificationCenter.default.post(name: .openFromNotification, object: nil, userInfo: userInfo)
        }

        routeFromActionUrl(in: userInfo)
    }

    // MARK: - Action Handling

    private func handleNotificationAction(actionIdentifier: String, userInfo: [AnyHashable: Any]) {
        switch actionIdentifier {
        case "START_WALK":
            NotificationCenter.default.post(name: .startWalkFromNotification, object: nil, userInfo: userInfo)
        case "VIEW_WALK":
            NotificationCenter.default.post(name: .viewWalkFromNotification, object: nil, userInfo: userInfo)
        case "VIEW_BOOKING":
            NotificationCenter.default.post(name: .viewBookingFromNotification, object: nil, userInfo: userInfo)
        case "REPLY":
            NotificationCenter.default.post(name: .replyFromNotification, object: nil, userInfo: userInfo)
        case "MARK_READ":
            NotificationCenter.default.post(name: .markReadFromNotification, object: nil, userInfo: userInfo)
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification itself
            NotificationCenter.default.post(name: .openFromNotification, object: nil, userInfo: userInfo)
            routeFromActionUrl(in: userInfo)
        default:
            break
        }
    }

    // MARK: - Deep-link routing (FCM `actionUrl`)

    /// Map an `actionUrl` from the FCM payload to an `AppRoute` and
    /// broadcast it via `.deepLinkRouteRequested`. The root navigator
    /// observes this and pushes onto the appropriate NavigationStack.
    ///
    /// Supported patterns:
    ///   * `/client/cash-requests/<id>`   → `.clientCashRequest(requestId:)`
    ///   * `/business/cash-requests/<id>` → `.businessCashRequest(requestId:)`
    private func routeFromActionUrl(in userInfo: [AnyHashable: Any]) {
        let actionUrl = (userInfo["actionUrl"] as? String)
            ?? (userInfo["action_url"] as? String)
            ?? (userInfo["url"] as? String)
        guard let actionUrl, !actionUrl.isEmpty else { return }

        if let route = NotificationService.appRoute(forActionUrl: actionUrl) {
            NotificationCenter.default.post(
                name: .deepLinkRouteRequested,
                object: nil,
                userInfo: ["route": route]
            )
        }
    }

    /// Pure mapper — exposed for unit tests / preview wiring.
    static func appRoute(forActionUrl actionUrl: String) -> AppRoute? {
        // Strip an optional scheme/host so we work for both
        // "/client/cash-requests/<id>" and "https://woofwalk.app/client/...".
        var path = actionUrl
        if let url = URL(string: actionUrl), url.host != nil {
            path = url.path
        }
        let segments = path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        if segments.count == 3,
           segments[0] == "client",
           segments[1] == "cash-requests" {
            return .clientCashRequest(requestId: segments[2])
        }
        if segments.count == 3,
           segments[0] == "business",
           segments[1] == "cash-requests" {
            return .businessCashRequest(requestId: segments[2])
        }
        return nil
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let startWalkFromNotification = Notification.Name("startWalkFromNotification")
    static let viewWalkFromNotification = Notification.Name("viewWalkFromNotification")
    static let viewBookingFromNotification = Notification.Name("viewBookingFromNotification")
    static let replyFromNotification = Notification.Name("replyFromNotification")
    static let markReadFromNotification = Notification.Name("markReadFromNotification")
    static let openFromNotification = Notification.Name("openFromNotification")

    /// Posted by `NotificationService` when an FCM payload of type
    /// `lost_dog_alert` lands. The lost-dog map screen observes this so
    /// an in-app banner / map pin can render while the user is on a
    /// foreground tab. Mirrors Android's
    /// `WoofWalkMessagingService.handleLostDogAlert` notification path.
    static let lostDogAlertReceived = Notification.Name("lostDogAlertReceived")

    /// Posted by `NotificationService` when an FCM payload's `actionUrl`
    /// resolves to a known `AppRoute`. `userInfo["route"]` is the resolved
    /// `AppRoute`. Root navigators (e.g. `MainTabView`, `BusinessTabView`)
    /// listen and push onto the active stack.
    static let deepLinkRouteRequested = Notification.Name("deepLinkRouteRequested")
}
