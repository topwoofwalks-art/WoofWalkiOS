import Foundation

/// Recurrence frequency for a recurring booking series. Raw values match
/// Android's `RecurringFrequency` enum and the server's
/// `RecurrenceFrequency` type in `functions/src/bookings/bookingSeriesShared.ts` —
/// the string is sent verbatim in the `recurrence.frequency` payload to
/// `createClientBooking` and stamped onto every materialised occurrence
/// as `recurrenceFrequency`.
enum RecurrenceFrequency: String, Codable, CaseIterable, Identifiable {
    case daily = "DAILY"
    case weekly = "WEEKLY"
    case biweekly = "BIWEEKLY"
    case monthly = "MONTHLY"

    var id: String { rawValue }

    /// Human-readable label for the booking-flow picker chips.
    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .biweekly: return "Every 2 weeks"
        case .monthly: return "Monthly"
        }
    }

    /// Short label for the recurring badge on the bookings list. Matches
    /// `Booking.recurrenceBadgeLabel` for parity with the snapshot string.
    var badgeLabel: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .biweekly: return "Every 2 weeks"
        case .monthly: return "Monthly"
        }
    }
}

/// Recurrence pattern selected in the booking-create flow. This is
/// the local UI/state shape — when the user submits, the booking flow
/// VM serialises it into the `recurrence` payload key the
/// `createClientBooking` Cloud Function accepts:
///
///     {
///       frequency: "WEEKLY" | ...,
///       interval: 1,
///       endDate?: <epoch ms>,
///       maxOccurrences?: <int>
///     }
///
/// Exactly one of `endDate` / `maxOccurrences` must be set — the server
/// rejects with `invalid-argument` otherwise. The booking-create VM
/// enforces that locally too so the user can't submit without a stop
/// condition.
struct RecurrencePattern: Equatable {
    var frequency: RecurrenceFrequency
    /// Every-N units. Defaults to 1; we currently expose only 1 in the
    /// UI (Android does the same — interval=2 is implied by BIWEEKLY).
    var interval: Int = 1
    /// Series end-by date (inclusive). Mutually exclusive with
    /// `maxOccurrences`. Setting one clears the other in the VM.
    var endDate: Date?
    /// Cap on number of occurrences. Mutually exclusive with `endDate`.
    var maxOccurrences: Int?

    /// True when the user has provided a stop condition. The submit
    /// button on the recurrence step is disabled until this is true.
    var hasStopCondition: Bool {
        endDate != nil || (maxOccurrences ?? 0) > 0
    }

    /// Build the payload dictionary the `createClientBooking` CF expects
    /// under the `recurrence` key. Always returns a payload when called
    /// — frequency is always present, endDate/maxOccurrences are added
    /// only when set. The CF will reject with `invalid-argument` if
    /// neither stop condition is provided, and the caller surfaces that
    /// error to the user (mirrors Android's submit path: the local UI
    /// doesn't pre-validate stop-condition presence).
    func toPayload() -> [String: Any] {
        var payload: [String: Any] = [
            "frequency": frequency.rawValue,
            "interval": max(1, interval)
        ]
        if let endDate = endDate {
            // Use end-of-day epoch ms so a same-day end-date includes the
            // last occurrence (matches Android's
            // `LocalDate.atTime(23,59,59)` conversion).
            let cal = Calendar.current
            let endOfDay = cal.date(
                bySettingHour: 23, minute: 59, second: 59, of: endDate
            ) ?? endDate
            payload["endDate"] = Int64(endOfDay.timeIntervalSince1970 * 1000)
        }
        if let maxOccurrences = maxOccurrences, maxOccurrences > 0 {
            payload["maxOccurrences"] = maxOccurrences
        }
        return payload
    }
}

/// Cancel-scope for a booking that's part of a recurring series. The raw
/// values are the strings the `cancelBookingSeries` Cloud Function
/// accepts under the `scope` key — see
/// `functions/src/bookings/cancelBookingSeries.ts`.
enum RecurrenceCancelScope: String, CaseIterable, Identifiable {
    /// Cancel only this occurrence. Series stays active, future
    /// occurrences continue to materialise.
    case this = "this"
    /// Cancel this occurrence + every future occurrence. Series.endDate
    /// is set to yesterday so the materialiser stops extending.
    case thisAndFuture = "thisAndFuture"
    /// Cancel every occurrence in the series, including past ones still
    /// in PENDING/AWAITING_PAYMENT. Series is marked cancelledAt.
    case all = "all"

    var id: String { rawValue }

    /// Label for the radio row.
    var displayName: String {
        switch self {
        case .this: return "Just this booking"
        case .thisAndFuture: return "This and all future bookings"
        case .all: return "Every booking in the series"
        }
    }

    /// Human-readable confirmation toast after the CF returns success.
    var successToast: String {
        switch self {
        case .this: return "Booking cancelled"
        case .thisAndFuture: return "This + future bookings cancelled"
        case .all: return "Series cancelled"
        }
    }
}
