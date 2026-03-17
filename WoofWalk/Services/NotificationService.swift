import Foundation
import UserNotifications
import UIKit

class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
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
        // Forward to Firebase Messaging when available
    }

    func didReceiveFCMToken(_ token: String?) {
        DispatchQueue.main.async {
            self.fcmToken = token
        }
        if let token = token {
            print("[NotificationService] FCM token: \(token)")
            // TODO: Send token to backend for targeting
        }
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
        default:
            break
        }
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
}
