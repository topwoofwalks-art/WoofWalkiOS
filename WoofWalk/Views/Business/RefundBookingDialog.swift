import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

// MARK: - Refund Mode

/// User's pick from the refund radio group. Drives the amount the
/// `processRefund` callable is invoked with.
enum RefundMode: Hashable {
    case full          // 100% of booking price
    case partial       // user-typed partial amount (validated 0…price)
    case none          // £0, but still cancel the booking
}

// MARK: - ViewModel

/// iOS parity port of Android
/// `app/src/main/java/com/woofwalk/ui/business/booking/BookingDetailScreen.kt`
/// `RefundDialog` + `BookingDetailViewModel#confirmCancellation`.
///
/// The Android policy lives in `BookingViewModel#calculateRefund`:
///   • ≥ 24 h before start → 100% refund
///   • 12–24 h            → 50% refund
///   • < 12 h             → 0%
/// We compute that on-device for the UI hint, then call the
/// `processRefund` Cloud Function (functions/src/index.ts:8335). The CF
/// is the source of truth — it enforces its own caps server-side and
/// rejects unauthorised callers. We pass `amount` in MINOR units
/// (pence), matching the CF contract and the Android `requestRefund`
/// `amount: Long` parameter on PaymentFlowRepository.
///
/// When the booking has no payment_flow yet (legacy / unpaid cash
/// bookings created before the Stripe wiring) we skip the refund leg
/// and only mark the booking cancelled, mirroring Android's pre-paid-
/// flow fallback in `BookingDetailViewModel#cancelBookingWithRefund`.
@MainActor
final class RefundBookingViewModel: ObservableObject {
    @Published var mode: RefundMode = .full
    @Published var partialAmountString: String = ""
    @Published var reason: String = ""
    @Published var isSubmitting: Bool = false
    @Published var error: String?
    @Published var completed: Bool = false

    let booking: Booking
    let recommendedRefundAmount: Double
    let recommendedRefundPercent: Int
    let policyLabel: String

    private let db = Firestore.firestore()
    private let functions = Functions.functions(region: "europe-west2")

    init(booking: Booking) {
        self.booking = booking

        let price = booking.computedPrice ?? booking.price
        let hoursBefore = Self.hoursUntil(booking.startDate)

        let percent: Int
        let label: String
        if hoursBefore >= 24 {
            percent = 100
            label = "24h+ before start → full refund"
        } else if hoursBefore >= 12 {
            percent = 50
            label = "12–24h before start → 50% refund"
        } else if hoursBefore > 0 {
            percent = 0
            label = "Under 12h before start → no refund (override below)"
        } else {
            percent = 0
            label = "Booking has started — no refund (override below)"
        }
        self.recommendedRefundPercent = percent
        self.recommendedRefundAmount = (price * Double(percent)) / 100.0
        self.policyLabel = label

        // Pre-fill partial field with the policy recommendation, but
        // default the radio to .full so the business owner sees the
        // good-customer-service option first. They can drop to .partial
        // / .none if needed.
        self.partialAmountString = String(format: "%.2f", self.recommendedRefundAmount)
        self.mode = percent == 100 ? .full : (percent == 0 ? .none : .partial)
    }

    var bookingPrice: Double {
        booking.computedPrice ?? booking.price
    }

    /// The amount that will actually be sent to the CF, in major units
    /// (GBP). Driven by the selected mode.
    var resolvedRefundAmount: Double {
        switch mode {
        case .full:
            return bookingPrice
        case .partial:
            let raw = Double(partialAmountString.replacingOccurrences(of: ",", with: ".")) ?? 0
            return max(0, min(raw, bookingPrice))
        case .none:
            return 0
        }
    }

    var resolvedRefundAmountMinor: Int64 {
        Int64((resolvedRefundAmount * 100).rounded())
    }

    var canSubmit: Bool {
        guard !isSubmitting else { return false }
        // Force a reason for partial / no-refund cancels so the audit
        // log isn't ambiguous about why the policy was overridden.
        if mode != .full && reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        if mode == .partial && resolvedRefundAmount <= 0 {
            return false
        }
        return true
    }

    func submit(onSuccess: @escaping () -> Void) {
        guard canSubmit else { return }
        guard let bookingId = booking.id else {
            error = "Booking has no ID — cannot process refund"
            return
        }
        isSubmitting = true
        error = nil

        Task {
            do {
                // Look up the payment_flow for this booking. The
                // processRefund CF keys off `paymentFlowId`, not
                // bookingId, so we need this hop. The flow doc is
                // written by `processBookingPayment` / the Stripe
                // confirm path; cash bookings or pre-payment bookings
                // won't have one, in which case we fall back to a pure
                // cancel-without-refund (Android matches: `cancelBooking`
                // with no payment side-effect).
                let flowSnap = try await db.collection("payment_flows")
                    .whereField("bookingId", isEqualTo: bookingId)
                    .limit(to: 1)
                    .getDocuments()

                let paymentFlowId = flowSnap.documents.first?.documentID

                let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
                let reasonForCf = trimmedReason.isEmpty ? "BUSINESS_CANCELLED" : trimmedReason

                if let paymentFlowId, resolvedRefundAmountMinor > 0 {
                    // Real refund path — fire the CF, then mark the
                    // booking cancelled in the same task so the UI
                    // refresh is atomic.
                    let payload: [String: Any] = [
                        "paymentFlowId": paymentFlowId,
                        "amount": resolvedRefundAmountMinor,
                        "reason": "BUSINESS_CANCELLED",
                        "notes": trimmedReason
                    ]
                    _ = try await functions.httpsCallable("processRefund").call(payload)
                }

                try await markBookingCancelled(
                    bookingId: bookingId,
                    reason: reasonForCf
                )

                await MainActor.run {
                    self.isSubmitting = false
                    self.completed = true
                    onSuccess()
                }
            } catch {
                await MainActor.run {
                    self.isSubmitting = false
                    self.error = "Refund failed: \(error.localizedDescription)"
                }
            }
        }
    }

    /// Mirror of Android's `BookingRepository#cancelBooking`. We don't
    /// have a dedicated cancelBooking CF on the business side yet
    /// (processRefund + this write replicate the same end state).
    private func markBookingCancelled(bookingId: String, reason: String) async throws {
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        try await db.collection("bookings").document(bookingId).updateData([
            "status": "CANCELLED",
            "cancellationReason": reason,
            "cancelledBy": Auth.auth().currentUser?.uid ?? "",
            "cancelledByRole": "BUSINESS",
            "updatedAt": nowMs
        ])
    }

    private static func hoursUntil(_ date: Date) -> Double {
        date.timeIntervalSinceNow / 3600.0
    }
}

// MARK: - Dialog

struct RefundBookingDialog: View {
    let booking: Booking
    let onCompleted: () -> Void
    let onDismiss: () -> Void

    @StateObject private var viewModel: RefundBookingViewModel
    @FocusState private var partialFieldFocused: Bool

    init(booking: Booking, onCompleted: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.booking = booking
        self.onCompleted = onCompleted
        self.onDismiss = onDismiss
        _viewModel = StateObject(wrappedValue: RefundBookingViewModel(booking: booking))
    }

    var body: some View {
        NavigationStack {
            Form {
                policySection
                modeSection
                reasonSection

                if let err = viewModel.error {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(err)
                                .font(.subheadline)
                        }
                    }
                }
            }
            .navigationTitle("Cancel with refund")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                        .disabled(viewModel.isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSubmitting {
                        ProgressView()
                    } else {
                        Button {
                            viewModel.submit { onCompleted() }
                        } label: {
                            Text(submitButtonTitle)
                                .bold()
                                .foregroundColor(viewModel.canSubmit ? .red : .secondary)
                        }
                        .disabled(!viewModel.canSubmit)
                    }
                }
            }
        }
    }

    private var submitButtonTitle: String {
        switch viewModel.mode {
        case .full:    return "Cancel & Refund"
        case .partial: return "Cancel & Refund"
        case .none:    return "Cancel (no refund)"
        }
    }

    // MARK: - Sections

    private var policySection: some View {
        Section {
            HStack {
                Text("Booking total")
                Spacer()
                Text(format(viewModel.bookingPrice))
                    .bold()
            }
            HStack {
                Text("Recommended refund")
                Spacer()
                Text("\(viewModel.recommendedRefundPercent)% — \(format(viewModel.recommendedRefundAmount))")
                    .foregroundColor(.accentColor)
            }
            Text(viewModel.policyLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Cancellation policy")
        }
    }

    private var modeSection: some View {
        Section {
            modeRow(
                mode: .full,
                title: "Full refund",
                detail: format(viewModel.bookingPrice)
            )
            modeRow(
                mode: .partial,
                title: "Partial refund",
                detail: nil,
                trailing: AnyView(
                    HStack {
                        Text("£")
                        TextField(
                            "0.00",
                            text: $viewModel.partialAmountString
                        )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($partialFieldFocused)
                        .frame(maxWidth: 100)
                        .onTapGesture {
                            viewModel.mode = .partial
                            partialFieldFocused = true
                        }
                    }
                )
            )
            modeRow(
                mode: .none,
                title: "No refund",
                detail: "Cancel without refunding"
            )
        } header: {
            Text("Refund amount")
        } footer: {
            if viewModel.mode == .partial {
                Text("Capped at the booking total (\(format(viewModel.bookingPrice))).")
            } else {
                EmptyView()
            }
        }
    }

    private var reasonSection: some View {
        Section {
            TextEditor(text: $viewModel.reason)
                .frame(minHeight: 80)
        } header: {
            Text(viewModel.mode == .full ? "Reason (optional)" : "Reason (required)")
        } footer: {
            Text("Shared with the client and stored on the booking audit log.")
        }
    }

    private func modeRow(
        mode: RefundMode,
        title: String,
        detail: String? = nil,
        trailing: AnyView? = nil
    ) -> some View {
        Button {
            viewModel.mode = mode
            if mode == .partial {
                partialFieldFocused = true
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: viewModel.mode == mode
                      ? "largecircle.fill.circle"
                      : "circle")
                    .foregroundColor(viewModel.mode == mode ? .accentColor : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundColor(.primary)
                    if let detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let trailing {
                    trailing
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func format(_ amount: Double) -> String {
        String(format: "£%.2f", amount)
    }
}

#Preview {
    RefundBookingDialog(
        booking: Booking(
            id: "preview",
            clientName: "Jane Smith",
            startTime: Int64(Date().addingTimeInterval(36 * 3600).timeIntervalSince1970 * 1000),
            endTime: Int64(Date().addingTimeInterval(37 * 3600).timeIntervalSince1970 * 1000),
            price: 30.0
        ),
        onCompleted: {},
        onDismiss: {}
    )
}
