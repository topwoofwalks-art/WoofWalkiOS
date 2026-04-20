import Foundation
import UserNotifications

/// Schedules local notifications for upcoming / overdue dog vaccinations.
///
/// Android handles this via a WorkManager periodic worker
/// (`VaccinationReminderWorker`) that rescans Firestore daily. iOS has
/// no equivalent background runner, so we instead queue one
/// `UNCalendarNotificationTrigger` 14 days before expiry and a second
/// one on the expiry date itself, per vaccination record. The
/// identifiers are derived from the record id so editing or deleting a
/// record can cancel both reminders cleanly.
///
/// Notification authorization is requested on first use — we rely on
/// contextual permission (the user has explicitly asked to save a
/// vaccination) rather than prompting up front.
enum VaccinationReminderScheduler {

    /// Days before the expiry date to queue the "upcoming" reminder.
    /// Matches Android's `VaccinationReminder.REMINDER_WINDOW_DAYS`.
    static let upcomingWindowDays = 14

    // MARK: - Identifier helpers

    static func upcomingIdentifier(recordId: String) -> String {
        "vax-upcoming-\(recordId)"
    }

    static func overdueIdentifier(recordId: String) -> String {
        "vax-overdue-\(recordId)"
    }

    // MARK: - Public API

    /// Schedule the pair of reminders (14-days-before + on-expiry) for a
    /// vaccination record. Callers should cancel existing reminders for
    /// this record first if editing, so stale fire-dates don't linger.
    ///
    /// - Parameters:
    ///   - record: The saved vaccination record. Must have a non-nil
    ///             `id` and `expiresAt` to schedule anything.
    ///   - dogName: The dog's display name, used in the notification body.
    static func scheduleReminder(for record: MedicalRecord, dogName: String) {
        guard record.type == .vaccination else { return }
        guard let recordId = record.id, !recordId.isEmpty else { return }
        guard let expiresAtMs = record.expiresAt else { return }

        let expiryDate = Date(timeIntervalSince1970: TimeInterval(expiresAtMs) / 1000.0)
        let vaccineLabel = record.vaccinationName?.nilIfBlank
            ?? record.title.nilIfBlank
            ?? "Vaccination"

        // Request authorization on first use (no-op if already granted).
        ensureAuthorization { granted in
            guard granted else { return }

            // Cancel any stale reminders for this record before rescheduling.
            cancelReminders(for: recordId)

            scheduleUpcomingReminder(
                recordId: recordId,
                dogName: dogName,
                vaccineLabel: vaccineLabel,
                expiryDate: expiryDate
            )
            scheduleOverdueReminder(
                recordId: recordId,
                dogName: dogName,
                vaccineLabel: vaccineLabel,
                expiryDate: expiryDate
            )
        }
    }

    /// Remove both the upcoming and overdue reminders for a record.
    /// Safe to call even if no reminders were ever scheduled.
    static func cancelReminders(for recordId: String) {
        guard !recordId.isEmpty else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [
                upcomingIdentifier(recordId: recordId),
                overdueIdentifier(recordId: recordId)
            ]
        )
    }

    // MARK: - Internals

    private static func scheduleUpcomingReminder(
        recordId: String,
        dogName: String,
        vaccineLabel: String,
        expiryDate: Date
    ) {
        guard let fireDate = Calendar.current.date(
            byAdding: .day,
            value: -upcomingWindowDays,
            to: expiryDate
        ) else { return }
        // Only schedule the 14-day heads-up if it's still in the future;
        // a vaccination saved less than 14 days before expiry just gets
        // the on-expiry reminder.
        guard fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Vaccination due soon"
        content.body = "\(dogName)'s \(vaccineLabel) is due in \(upcomingWindowDays) days"
        content.sound = .default
        content.categoryIdentifier = NotificationService.NotificationCategory.alerts.rawValue
        content.userInfo = [
            "type": "vaccinationReminder",
            "recordId": recordId,
            "stage": "upcoming"
        ]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: upcomingIdentifier(recordId: recordId),
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[VaccinationReminderScheduler] upcoming schedule failed: \(error.localizedDescription)")
            }
        }
    }

    private static func scheduleOverdueReminder(
        recordId: String,
        dogName: String,
        vaccineLabel: String,
        expiryDate: Date
    ) {
        guard expiryDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Vaccination overdue"
        content.body = "\(dogName)'s \(vaccineLabel) is overdue"
        content.sound = .default
        content.categoryIdentifier = NotificationService.NotificationCategory.alerts.rawValue
        content.userInfo = [
            "type": "vaccinationReminder",
            "recordId": recordId,
            "stage": "overdue"
        ]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: expiryDate
        )
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: overdueIdentifier(recordId: recordId),
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[VaccinationReminderScheduler] overdue schedule failed: \(error.localizedDescription)")
            }
        }
    }

    /// Ensure notification authorization. If already granted, completion
    /// fires with `true` immediately. If not determined, prompt. If
    /// denied, completion fires with `false` and the caller should
    /// silently skip scheduling — the user explicitly declined.
    private static func ensureAuthorization(completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                completion(true)
            case .denied:
                completion(false)
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                    if let error = error {
                        print("[VaccinationReminderScheduler] auth request failed: \(error.localizedDescription)")
                    }
                    completion(granted)
                }
            @unknown default:
                completion(false)
            }
        }
    }
}

// MARK: - Small helper

private extension String {
    /// Returns nil if the string is empty after trimming, otherwise self.
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
