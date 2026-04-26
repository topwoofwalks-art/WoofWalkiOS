import Foundation
import FirebaseFunctions

/// Stripe Connect destination-charge payment service.
///
/// Mirrors the Android `UnifiedBookingFlowViewModel` Stripe flow:
///   1. After `createClientBooking` returns a bookingId, call
///      `processBookingPayment` to create the PaymentIntent server-side
///      (the CF derives amount from the booking doc, splits via Stripe
///      Connect's on_behalf_of + transfer_data, and returns a clientSecret).
///   2. Present PaymentSheet with that clientSecret on the client.
///   3. On `.completed`, call `confirmPayment` with the bookingId +
///      paymentIntentId so the server flips the booking to `paid` and
///      emits the Firestore activity event.
///
/// Region is `europe-west2` to match BookingRepository / Android.
final class StripePaymentService {
    private lazy var functions = Functions.functions(region: "europe-west2")

    /// Request a PaymentIntent clientSecret for the given booking.
    ///
    /// Calls the `processBookingPayment` callable. Server response shape
    /// (functions/src/index.ts processBookingPayment):
    ///   { success: Bool, clientSecret: String?, errorMessage: String? }
    ///
    /// Throws if the call fails, the server reports `success == false`,
    /// or the response is missing the clientSecret.
    ///
    /// TODO(phase-1.2): multi-dog needs createPaymentIntent — the
    /// current single-booking `processBookingPayment` returns ONE
    /// PaymentIntent per booking doc. iOS only creates one booking via
    /// `BookingRepository.createBooking`, so a single processBookingPayment
    /// call is sufficient for v1. When iOS gains multi-dog booking (one
    /// booking per dog → array of IDs), call processBookingPayment per
    /// booking and present the sheet per intent (matching Android's
    /// per-dog confirm loop).
    func requestClientSecret(bookingId: String) async throws -> String {
        let payload: [String: Any] = ["bookingId": bookingId]
        let result = try await functions
            .httpsCallable("processBookingPayment")
            .call(payload)

        guard let response = result.data as? [String: Any] else {
            throw StripePaymentError.malformedResponse
        }

        // Mirrors Android's contract: `success` boolean gates `clientSecret`.
        // `success: false` ships an `errorMessage` string we surface to
        // the caller for the toast / errorMessage state.
        let success = (response["success"] as? Bool) ?? false
        if !success {
            let msg = response["errorMessage"] as? String ?? "Payment setup failed"
            throw StripePaymentError.serverFailure(message: msg)
        }

        guard let clientSecret = response["clientSecret"] as? String,
              !clientSecret.isEmpty else {
            throw StripePaymentError.malformedResponse
        }

        return clientSecret
    }

    /// Confirm payment server-side after PaymentSheet completes successfully.
    ///
    /// Calls the `confirmPayment` callable with both bookingId and
    /// paymentIntentId. Mirrors `UnifiedBookingFlowViewModel.kt:1322`.
    /// The server validates that the PaymentIntent belongs to the booking,
    /// flips `isPaid: true`, and emits the activity-feed event.
    func confirmOnServer(bookingId: String, paymentIntentId: String) async throws {
        let payload: [String: Any] = [
            "bookingId": bookingId,
            "paymentIntentId": paymentIntentId
        ]
        _ = try await functions
            .httpsCallable("confirmPayment")
            .call(payload)
    }

    /// Derive the PaymentIntent ID from a clientSecret.
    ///
    /// Stripe clientSecrets follow the format `pi_<id>_secret_<random>`,
    /// so the substring before `_secret_` is the PaymentIntent ID.
    /// Mirrors Android `UnifiedBookingFlowViewModel.kt:1315`:
    ///   `clientSecret.substringBefore("_secret_")`
    ///
    /// Returns `nil` if the input doesn't contain `_secret_` (which would
    /// indicate a malformed clientSecret — caller should treat that as
    /// an unrecoverable error).
    static func paymentIntentId(fromClientSecret secret: String) -> String? {
        guard let range = secret.range(of: "_secret_") else { return nil }
        let id = String(secret[..<range.lowerBound])
        return id.isEmpty ? nil : id
    }
}

// MARK: - Errors

enum StripePaymentError: LocalizedError {
    case malformedResponse
    case serverFailure(message: String)
    case missingPaymentIntentId

    var errorDescription: String? {
        switch self {
        case .malformedResponse:
            return "Couldn't read payment response from server"
        case .serverFailure(let message):
            return message
        case .missingPaymentIntentId:
            return "Payment intent ID missing from clientSecret"
        }
    }
}
