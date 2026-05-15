import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import StripePaymentSheet

// MARK: - Booking Detail View Model

@MainActor
class BookingDetailViewModel: ObservableObject {
    @Published var booking: Booking?
    @Published var isLoading = true
    @Published var error: String?

    // Cancel dialog
    @Published var showCancelDialog = false
    @Published var cancelReason = ""
    @Published var isCancelling = false
    /// Selected cancel scope when this booking is part of a recurring
    /// series. Default is `.this` (cancel only this occurrence) —
    /// matches Android's pre-selection in
    /// `ClientBookingDetailScreen#CancelBookingDialog`. Ignored for
    /// one-off bookings.
    @Published var cancelScope: RecurrenceCancelScope = .this

    // Tip sheet
    @Published var showTipSheet = false
    @Published var tipAmount: Double = 5.0

    // Review sheet
    @Published var showReviewSheet = false
    @Published var reviewRating: Int = 5
    @Published var reviewComment = ""

    // Report sheet
    @Published var showReportSheet = false
    @Published var reportText = ""

    // On My Way
    @Published var isOnMyWay = false
    @Published var isSendingOnMyWay = false

    // In-flight indicators for the new wired actions
    @Published var isSubmittingTip = false
    @Published var isSubmittingReview = false
    @Published var isSubmittingReport = false

    // Stripe PaymentSheet state — tip flow and switch-to-card flow both
    // present a sheet built off a clientSecret from processTip /
    // processBookingPayment. Cleared on completion / cancel / failure.
    @Published var paymentClientSecret: String?
    @Published var pendingPaymentBookingId: String?
    @Published var presentPaymentSheet: Bool = false

    // Snackbar
    @Published var snackbarMessage: String?

    private let bookingRepository = BookingRepository()
    private let stripeService = StripePaymentService()
    private let functions = Functions.functions(region: "europe-west2")
    private var cancellables = Set<AnyCancellable>()
    private let bookingId: String

    init(bookingId: String) {
        self.bookingId = bookingId
        loadBooking()
    }

    func loadBooking() {
        isLoading = true
        error = nil

        bookingRepository.getBookingById(bookingId)
            .receive(on: DispatchQueue.main)
            .catch { _ in Just(nil) }
            .sink { [weak self] booking in
                self?.booking = booking
                self?.isLoading = false
                if booking == nil {
                    self?.error = "Booking not found"
                }
            }
            .store(in: &cancellables)
    }

    func cancelBooking() {
        guard !cancelReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || true else { return }
        isCancelling = true

        // Snapshot what we need before crossing the await — the booking
        // may still load when the user taps Cancel, but isRecurring is
        // captured deterministically off the doc that's currently in VM
        // state. Worst case the booking is nil → fall back to the
        // standard one-off path (the CF would reject `cancelBookingSeries`
        // for a non-recurring booking anyway).
        let recurring = booking?.isRecurring ?? false
        let scope = cancelScope

        Task {
            do {
                let reason = cancelReason.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedReason = reason.isEmpty ? nil : reason

                if recurring {
                    // Recurring — route through the cancelBookingSeries
                    // CF so the series rule + every affected occurrence
                    // are updated together with a server-stamped audit
                    // trail. Mirrors Android's
                    // `ClientBookingDetailViewModel#onCancelBooking(scope=…)`.
                    _ = try await bookingRepository.cancelBookingSeries(
                        bookingId: bookingId,
                        scope: scope,
                        reason: trimmedReason
                    )
                    snackbarMessage = scope.successToast
                } else {
                    try await bookingRepository.cancelBooking(
                        bookingId: bookingId,
                        reason: trimmedReason
                    )
                    snackbarMessage = "Booking cancelled"
                }

                isCancelling = false
                showCancelDialog = false
                cancelReason = ""
                cancelScope = .this
            } catch {
                isCancelling = false
                snackbarMessage = "Failed to cancel: \(error.localizedDescription)"
            }
        }
    }

    func submitReview() {
        guard Auth.auth().currentUser != nil else {
            snackbarMessage = "Sign in to leave a review"
            return
        }
        guard let booking = booking else { return }
        let rating = reviewRating
        let comment = reviewComment.trimmingCharacters(in: .whitespacesAndNewlines)
        isSubmittingReview = true
        let providerId = booking.assignedTo ?? booking.businessId
        let payload: [String: Any] = [
            "bookingId": bookingId,
            "providerId": providerId,
            "rating": rating,
            "comment": comment,
            "photos": [String]()
        ]
        Task {
            do {
                _ = try await functions.httpsCallable("submitReview").call(payload)
                await MainActor.run {
                    self.isSubmittingReview = false
                    self.showReviewSheet = false
                    self.reviewRating = 5
                    self.reviewComment = ""
                    self.snackbarMessage = "Review submitted — thank you!"
                }
            } catch {
                await MainActor.run {
                    self.isSubmittingReview = false
                    self.snackbarMessage = "Failed to submit review: \(error.localizedDescription)"
                }
            }
        }
    }

    func addTip() {
        guard Auth.auth().currentUser != nil else {
            snackbarMessage = "Sign in to add a tip"
            return
        }
        guard tipAmount > 0 else { return }
        isSubmittingTip = true
        let amount = tipAmount
        Task {
            do {
                let payload: [String: Any] = [
                    "bookingId": bookingId,
                    "amountGbp": amount
                ]
                let result = try await functions.httpsCallable("processTip").call(payload)
                guard let response = result.data as? [String: Any],
                      let secret = response["clientSecret"] as? String,
                      !secret.isEmpty else {
                    throw NSError(domain: "BookingDetail", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "Tip could not be prepared"])
                }
                await MainActor.run {
                    self.isSubmittingTip = false
                    self.showTipSheet = false
                    self.paymentClientSecret = secret
                    self.pendingPaymentBookingId = self.bookingId
                    self.presentPaymentSheet = true
                }
            } catch {
                await MainActor.run {
                    self.isSubmittingTip = false
                    self.snackbarMessage = "Tip failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func submitReport() {
        guard let uid = Auth.auth().currentUser?.uid else {
            snackbarMessage = "Sign in to report an issue"
            return
        }
        guard let booking = booking else { return }
        let reason = reportText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reason.isEmpty else { return }
        isSubmittingReport = true
        let reportedUserId = booking.assignedTo ?? booking.businessId
        let payload: [String: Any] = [
            "reporterId": uid,
            "reportedUserId": reportedUserId,
            "reason": reason,
            "bookingId": bookingId,
            "orgId": booking.businessId,
            "status": "open",
            "createdAt": Int64(Date().timeIntervalSince1970 * 1000)
        ]
        Firestore.firestore()
            .collection("reports")
            .addDocument(data: payload) { [weak self] error in
                Task { @MainActor in
                    guard let self else { return }
                    self.isSubmittingReport = false
                    if let error {
                        self.snackbarMessage = "Report failed: \(error.localizedDescription)"
                    } else {
                        self.showReportSheet = false
                        self.reportText = ""
                        self.snackbarMessage = "Issue reported — we'll look into it"
                    }
                }
            }
    }

    func sendOnMyWay() {
        guard !isSendingOnMyWay else { return }
        guard Auth.auth().currentUser != nil else {
            snackbarMessage = "Sign in to notify your provider"
            return
        }
        isSendingOnMyWay = true
        Task {
            do {
                _ = try await functions
                    .httpsCallable("sendOnMyWayNotification")
                    .call(["bookingId": bookingId])
                await MainActor.run {
                    self.isOnMyWay = true
                    self.isSendingOnMyWay = false
                    self.snackbarMessage = "Your provider has been notified!"
                }
            } catch {
                await MainActor.run {
                    self.isSendingOnMyWay = false
                    self.snackbarMessage = "Could not notify provider: \(error.localizedDescription)"
                }
            }
        }
    }

    /// Switch an existing cash booking onto card payment by requesting a
    /// Stripe PaymentIntent for the booking and presenting PaymentSheet.
    /// The standard `processBookingPayment` callable resolves amount and
    /// destination from the booking doc server-side; on PaymentSheet
    /// success we call `confirmPayment` to flip the booking to paid.
    func switchToCardAndPay() {
        guard Auth.auth().currentUser != nil else {
            snackbarMessage = "Sign in to pay by card"
            return
        }
        isSubmittingTip = true
        Task {
            do {
                let secret = try await stripeService.requestClientSecret(bookingId: bookingId)
                await MainActor.run {
                    self.isSubmittingTip = false
                    self.paymentClientSecret = secret
                    self.pendingPaymentBookingId = self.bookingId
                    self.presentPaymentSheet = true
                }
            } catch {
                await MainActor.run {
                    self.isSubmittingTip = false
                    self.snackbarMessage = "Payment setup failed: \(error.localizedDescription)"
                }
            }
        }
    }

    /// Handle PaymentSheet result for both tip and switch-to-card flows.
    /// Tips: on completed the server webhook flips state — no extra
    /// confirm needed. Switch-to-card: call confirmPayment so the booking
    /// flips to paid + the activity event fires (mirrors BookingFlowVM).
    func handlePaymentSheetResult(_ result: PaymentSheetResult, isTip: Bool) {
        switch result {
        case .completed:
            guard let secret = paymentClientSecret,
                  let bid = pendingPaymentBookingId,
                  let paymentIntentId = StripePaymentService.paymentIntentId(fromClientSecret: secret)
            else {
                clearPaymentState()
                snackbarMessage = "Payment captured"
                return
            }
            if isTip {
                // processTip webhook handles bookkeeping server-side.
                clearPaymentState()
                snackbarMessage = "Tip sent — thank you!"
            } else {
                Task {
                    do {
                        try await stripeService.confirmOnServer(
                            bookingId: bid,
                            paymentIntentId: paymentIntentId
                        )
                        await MainActor.run {
                            self.clearPaymentState()
                            self.snackbarMessage = "Payment received — booking confirmed"
                        }
                    } catch {
                        await MainActor.run {
                            self.clearPaymentState()
                            self.snackbarMessage = "Paid, but confirm failed — contact support"
                        }
                    }
                }
            }
        case .canceled:
            clearPaymentState()
        case .failed(let error):
            clearPaymentState()
            snackbarMessage = "Payment failed: \(error.localizedDescription)"
        }
    }

    private func clearPaymentState() {
        paymentClientSecret = nil
        pendingPaymentBookingId = nil
        presentPaymentSheet = false
    }

    func formatPrice(_ amount: Double) -> String {
        CurrencyFormatter.shared.formatPrice(amount)
    }

    deinit {
        bookingRepository.cleanup()
    }
}

// MARK: - Booking Detail Screen

struct BookingDetailScreen: View {
    let bookingId: String

    @StateObject private var viewModel: BookingDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var paymentSheet: PaymentSheet?
    @State private var paymentSheetIsTip: Bool = false

    init(bookingId: String) {
        self.bookingId = bookingId
        _viewModel = StateObject(wrappedValue: BookingDetailViewModel(bookingId: bookingId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if let booking = viewModel.booking {
                bookingContent(booking)
            } else {
                errorView
            }
        }
        .background(AppColors.Dark.background)
        .navigationTitle("Booking Details")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(AppColors.Dark.onSurface)
                }
            }
        }
        .toolbarBackground(AppColors.Dark.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $viewModel.showCancelDialog) {
            cancelSheet
        }
        .sheet(isPresented: $viewModel.showTipSheet) {
            tipSheet
        }
        .sheet(isPresented: $viewModel.showReviewSheet) {
            reviewSheet
        }
        .sheet(isPresented: $viewModel.showReportSheet) {
            reportSheet
        }
        .overlay(alignment: .bottom) {
            if let message = viewModel.snackbarMessage {
                snackbar(message: message)
            }
        }
        .onChange(of: viewModel.paymentClientSecret) { newSecret in
            guard let secret = newSecret, !secret.isEmpty else {
                paymentSheet = nil
                return
            }
            let booking = viewModel.booking
            let isCashOrAwaiting = booking?.paymentMethodEnum == .cash
                || booking?.statusEnum == .awaitingPayment
            paymentSheetIsTip = !isCashOrAwaiting
            var config = PaymentSheet.Configuration()
            config.merchantDisplayName = "WoofWalk"
            config.allowsDelayedPaymentMethods = false
            paymentSheet = PaymentSheet(
                paymentIntentClientSecret: secret,
                configuration: config
            )
        }
        .background(paymentSheetSentinel)
    }

    @ViewBuilder
    private var paymentSheetSentinel: some View {
        if let sheet = paymentSheet {
            Color.clear
                .frame(width: 0, height: 0)
                .paymentSheet(
                    isPresented: $viewModel.presentPaymentSheet,
                    paymentSheet: sheet,
                    onCompletion: { result in
                        viewModel.handlePaymentSheetResult(result, isTip: paymentSheetIsTip)
                    }
                )
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .tint(AppColors.Dark.primary)
            Text("Loading booking...")
                .font(.subheadline)
                .foregroundColor(AppColors.Dark.onSurfaceVariant)
                .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Error

    private var errorView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(AppColors.Dark.onSurfaceVariant)
            Text(viewModel.error ?? "Booking not found")
                .font(.body)
                .foregroundColor(AppColors.Dark.onSurfaceVariant)
            Button("Go Back") { dismiss() }
                .font(.subheadline.bold())
                .foregroundColor(AppColors.Dark.onPrimary)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Capsule().fill(AppColors.Dark.primary))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Main Content

    private func bookingContent(_ booking: Booking) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                statusHeader(booking)
                paymentCard(booking)
                providerCard(booking)
                bookingDetailsCard(booking)

                // Service-specific detail card
                ServiceDetailCard(
                    serviceType: booking.serviceTypeEnum,
                    bookingStatus: booking.statusEnum,
                    serviceDetails: nil // Populated from Firestore serviceDetails sub-doc when available
                )

                if booking.statusEnum == .completed {
                    walkReportCard(booking)

                    // Phase 5 — surface walker photos / note / branded
                    // close-out when the business shared a live walk
                    // for this booking. Self-hides when no share exists.
                    if let bookingId = booking.id {
                        BusinessLiveShareRecapSection(bookingId: bookingId)
                    }
                }

                timelineCard(booking)
                actionButtons(booking)
            }
            .padding(16)
        }
    }

    // MARK: - Status Header

    private func statusHeader(_ booking: Booking) -> some View {
        let config = statusConfig(booking.statusEnum)

        return HStack(spacing: 12) {
            Image(systemName: config.icon)
                .font(.system(size: 28))
                .foregroundColor(config.color)

            VStack(alignment: .leading, spacing: 4) {
                Text(config.text)
                    .font(.title3.bold())
                    .foregroundColor(config.color)
                HStack(spacing: 6) {
                    Text(booking.serviceTypeEnum.displayName)
                        .font(.subheadline)
                        .foregroundColor(AppColors.Dark.onSurfaceVariant)

                    // Recurring chip — also on the detail header so the
                    // user knows the cancel dialog will offer scope.
                    if let label = booking.recurrenceBadgeLabel {
                        HStack(spacing: 3) {
                            Image(systemName: "repeat")
                                .font(.system(size: 10, weight: .bold))
                            Text(label)
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(AppColors.Dark.onTertiaryContainer)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(AppColors.Dark.tertiaryContainer)
                        )
                    }
                }
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(config.color.opacity(0.12))
        )
    }

    private func statusConfig(_ status: BookingStatus) -> (color: Color, text: String, icon: String) {
        switch status {
        case .pending:
            return (.orange, "Pending Confirmation", "clock.fill")
        case .awaitingPayment:
            return (Color(hex: 0xB26A00), "Awaiting Payment", "creditcard.fill")
        case .confirmed:
            return (.blue, "Confirmed", "checkmark.circle.fill")
        case .inProgress:
            return (Color(hex: 0x2E7D32), "In Progress", "figure.walk")
        case .completed:
            return (Color(hex: 0x2E7D32), "Completed", "checkmark.seal.fill")
        case .cancelled:
            return (.red, "Cancelled", "xmark.circle.fill")
        case .rejected:
            return (Color(hex: 0xC2185B), "Rejected", "hand.thumbsdown.fill")
        case .noShow:
            return (Color(hex: 0xC2185B), "No Show", "flag.fill")
        }
    }

    // MARK: - Payment Card

    /// Cash bookings get a confirmation card matching Android's Set-to-pay-
    /// in-cash UI; card bookings in AWAITING_PAYMENT get a payment-required
    /// card. Bookings in any other state (or already-paid card bookings)
    /// render no card. Mirrors the Android branch in
    /// `ClientBookingDetailScreen.kt` after the cash-booking UX fix.
    @ViewBuilder
    private func paymentCard(_ booking: Booking) -> some View {
        let isTerminal = booking.statusEnum == .completed
            || booking.statusEnum == .cancelled
            || booking.statusEnum == .rejected
            || booking.statusEnum == .noShow

        if booking.paymentMethodEnum == .cash && !isTerminal {
            cashBookingCard(booking)
        } else if booking.statusEnum == .awaitingPayment {
            awaitingPaymentCard(booking)
        }
    }

    private func cashBookingCard(_ booking: Booking) -> some View {
        let priceText = String(format: "£%.2f", booking.computedPrice ?? booking.price)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Set to pay in cash")
                .font(.headline)
                .foregroundColor(Color(hex: 0x1B5E20))
            Text("You'll pay your provider \(priceText) in cash on the day. No card payment needed.")
                .font(.body)
                .foregroundColor(Color(hex: 0x1B5E20))
            Button {
                viewModel.switchToCardAndPay()
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isSubmittingTip {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "creditcard.fill")
                    }
                    Text("Switch to card payment")
                        .font(.subheadline.bold())
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: 0x2E7D32))
                )
            }
            .disabled(viewModel.isSubmittingTip)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: 0xE8F5E9))
        )
    }

    private func awaitingPaymentCard(_ booking: Booking) -> some View {
        let priceText = String(format: "£%.2f", booking.computedPrice ?? booking.price)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Payment required")
                .font(.headline)
                .foregroundColor(Color(hex: 0x8A5600))
            Text("Confirm this booking by paying \(priceText). Your booking starts only after payment clears.")
                .font(.body)
                .foregroundColor(Color(hex: 0x8A5600))
            Button {
                viewModel.switchToCardAndPay()
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isSubmittingTip {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "creditcard.fill")
                    }
                    Text("Pay \(priceText) now")
                        .font(.subheadline.bold())
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: 0xB26A00))
                )
            }
            .disabled(viewModel.isSubmittingTip)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: 0xFFF8E1))
        )
    }

    // MARK: - Provider Card

    private func providerCard(_ booking: Booking) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Provider")
                .font(.headline)
                .foregroundColor(AppColors.Dark.onSurface)

            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(AppColors.Dark.primaryContainer)
                        .frame(width: 56, height: 56)
                    Image(systemName: "person.fill")
                        .font(.title2)
                        .foregroundColor(AppColors.Dark.onPrimaryContainer)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(booking.assignedTo ?? "Assigned Walker")
                        .font(.body.bold())
                        .foregroundColor(AppColors.Dark.onSurface)
                    Text(booking.businessId.isEmpty ? "Your provider" : "Business ID: \(booking.businessId.prefix(8))...")
                        .font(.caption)
                        .foregroundColor(AppColors.Dark.onSurfaceVariant)
                }

                Spacer()
            }

            HStack(spacing: 8) {
                // Message button
                Button {
                    // Navigate to chat - would use navigator in real app
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left.fill")
                            .font(.caption)
                        Text("Message")
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(AppColors.Dark.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppColors.Dark.primary, lineWidth: 1)
                    )
                }

                // Call button
                Button {
                    if let phone = booking.clientPhone, let url = URL(string: "tel:\(phone)") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "phone.fill")
                            .font(.caption)
                        Text("Call")
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(AppColors.Dark.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppColors.Dark.primary, lineWidth: 1)
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.Dark.surfaceVariant)
        )
    }

    // MARK: - Booking Details Card

    private func bookingDetailsCard(_ booking: Booking) -> some View {
        let dateFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "EEEE, MMMM d, yyyy"
            return f
        }()

        let timeFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "h:mm a"
            return f
        }()

        return VStack(alignment: .leading, spacing: 12) {
            Text("Booking Details")
                .font(.headline)
                .foregroundColor(AppColors.Dark.onSurface)

            detailRow(icon: booking.serviceTypeEnum.icon, label: "Service", value: booking.serviceTypeEnum.displayName)
            detailRow(icon: "calendar", label: "Date", value: dateFormatter.string(from: booking.startDate))
            detailRow(icon: "clock", label: "Time", value: "\(timeFormatter.string(from: booking.startDate)) - \(timeFormatter.string(from: booking.endDate))")
            detailRow(icon: "timer", label: "Duration", value: "\(booking.durationMinutes) min")
            detailRow(icon: "dog.fill", label: "Dog", value: booking.dogName)

            if !booking.location.isEmpty {
                detailRow(icon: "mappin.and.ellipse", label: "Location", value: booking.location)
            }

            detailRow(icon: "banknote", label: "Price", value: CurrencyFormatter.shared.formatPrice(booking.price))

            if booking.isPaid {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.success60)
                        .font(.caption)
                    Text("Paid")
                        .font(.caption.bold())
                        .foregroundColor(.success60)
                }
                .padding(.leading, 32)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.Dark.surfaceVariant)
        )
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(AppColors.Dark.onSurfaceVariant)
                .frame(width: 20, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(AppColors.Dark.onSurfaceVariant)
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(AppColors.Dark.onSurface)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Walk Report Card

    private func walkReportCard(_ booking: Booking) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Walk Report")
                    .font(.headline)
                    .foregroundColor(AppColors.Dark.onSurface)
                Spacer()
            }

            HStack(spacing: 0) {
                reportStat(value: String(format: "%.1f km", Double(booking.durationMinutes) * 0.08), label: "Distance")
                Spacer()
                reportStat(value: "\(booking.durationMinutes) min", label: "Duration")
                Spacer()
                reportStat(value: "--", label: "Potty")
            }

            if let notes = booking.notes, !notes.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "note.text")
                        .font(.caption)
                        .foregroundColor(AppColors.Dark.onSurfaceVariant)
                    Text(notes)
                        .font(.subheadline)
                        .foregroundColor(AppColors.Dark.onSurfaceVariant)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.Dark.surfaceVariant)
        )
    }

    private func reportStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .foregroundColor(AppColors.Dark.onSurface)
            Text(label)
                .font(.caption)
                .foregroundColor(AppColors.Dark.onSurfaceVariant)
        }
    }

    // MARK: - Timeline Card

    private func timelineCard(_ booking: Booking) -> some View {
        let events = buildTimeline(booking)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Timeline")
                .font(.headline)
                .foregroundColor(AppColors.Dark.onSurface)

            ForEach(Array(events.enumerated()), id: \.offset) { index, event in
                HStack(alignment: .top, spacing: 12) {
                    // Timeline dot and line
                    VStack(spacing: 0) {
                        Circle()
                            .fill(event.isActive ? AppColors.Dark.primary : AppColors.Dark.outlineVariant)
                            .frame(width: 12, height: 12)

                        if index < events.count - 1 {
                            Rectangle()
                                .fill(AppColors.Dark.outlineVariant)
                                .frame(width: 2, height: 32)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(event.isActive ? AppColors.Dark.onSurface : AppColors.Dark.onSurfaceVariant)

                        if let time = event.time {
                            Text(time)
                                .font(.caption)
                                .foregroundColor(AppColors.Dark.onSurfaceVariant)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.Dark.surfaceVariant)
        )
    }

    private func buildTimeline(_ booking: Booking) -> [TimelineEvent] {
        let timeFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "MMM d, h:mm a"
            return f
        }()

        let createdDate = Date(timeIntervalSince1970: TimeInterval(booking.createdAt) / 1000.0)
        let status = booking.statusEnum

        var events: [TimelineEvent] = []

        events.append(TimelineEvent(
            title: "Booking Created",
            time: timeFormatter.string(from: createdDate),
            isActive: true
        ))

        let isConfirmedOrBeyond = [.confirmed, .inProgress, .completed].contains(status)
        events.append(TimelineEvent(
            title: "Confirmed",
            time: isConfirmedOrBeyond ? timeFormatter.string(from: createdDate) : nil,
            isActive: isConfirmedOrBeyond
        ))

        let isInProgressOrBeyond = [.inProgress, .completed].contains(status)
        events.append(TimelineEvent(
            title: "In Progress",
            time: isInProgressOrBeyond ? timeFormatter.string(from: booking.startDate) : nil,
            isActive: isInProgressOrBeyond
        ))

        let isCompleted = status == .completed
        events.append(TimelineEvent(
            title: "Completed",
            time: isCompleted ? timeFormatter.string(from: booking.endDate) : nil,
            isActive: isCompleted
        ))

        if status == .cancelled {
            let updatedDate = Date(timeIntervalSince1970: TimeInterval(booking.updatedAt) / 1000.0)
            events.append(TimelineEvent(
                title: "Cancelled",
                time: timeFormatter.string(from: updatedDate),
                isActive: true
            ))
        }

        return events
    }

    // MARK: - Action Buttons

    private func actionButtons(_ booking: Booking) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(.headline)
                .foregroundColor(AppColors.Dark.onSurface)

            switch booking.statusEnum {
            case .pending:
                // Cancel Booking
                Button {
                    viewModel.showCancelDialog = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                        Text("Cancel Booking")
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.error50)
                    )
                }

            case .confirmed:
                // On My Way button
                if !viewModel.isOnMyWay {
                    Button {
                        viewModel.sendOnMyWay()
                    } label: {
                        HStack(spacing: 8) {
                            if viewModel.isSendingOnMyWay {
                                ProgressView()
                                    .tint(AppColors.Dark.onPrimary)
                            } else {
                                Image(systemName: "figure.walk.departure")
                            }
                            Text("I'm On My Way")
                                .font(.subheadline.bold())
                        }
                        .foregroundColor(AppColors.Dark.onPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(red: 0.18, green: 0.49, blue: 0.20))
                        )
                    }
                    .disabled(viewModel.isSendingOnMyWay)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Provider Notified")
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(Color(red: 0.18, green: 0.49, blue: 0.20))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(red: 0.18, green: 0.49, blue: 0.20), lineWidth: 1)
                    )
                }

                // Cancel Booking
                Button {
                    viewModel.showCancelDialog = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                        Text("Cancel Booking")
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.error50)
                    )
                }

            case .inProgress:
                // Service-aware live tracking navigation
                NavigationLink(destination: liveScreenForBooking(booking)) {
                    HStack(spacing: 8) {
                        Image(systemName: liveIconForService(booking.serviceTypeEnum))
                        Text(liveLabelForService(booking.serviceTypeEnum))
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(AppColors.Dark.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.Dark.primary)
                    )
                }

            case .completed:
                // Book Again
                Button {
                    // Navigate to booking flow
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text("Book Again")
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(AppColors.Dark.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.Dark.primary)
                    )
                }

                // Leave Review
                Button {
                    viewModel.showReviewSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                        Text("Leave Review")
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(AppColors.Dark.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.Dark.primary, lineWidth: 1)
                    )
                }

                // Add Tip
                Button {
                    viewModel.showTipSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "dollarsign.circle.fill")
                        Text("Add Tip")
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(AppColors.Dark.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.Dark.primary, lineWidth: 1)
                    )
                }

                // Report Issue
                Button {
                    viewModel.showReportSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "flag.fill")
                        Text("Report Issue")
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(AppColors.Dark.onSurfaceVariant)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }

            default:
                EmptyView()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.Dark.surfaceVariant)
        )
    }

    // MARK: - Service-Aware Live Navigation

    @ViewBuilder
    private func liveScreenForBooking(_ booking: Booking) -> some View {
        let sessionId = booking.id ?? bookingId
        switch booking.serviceTypeEnum {
        case .walk, .meetGreet:
            LiveTrackingScreen(
                walkId: sessionId,
                onNavigateBack: {},
                onNavigateToChat: { _ in }
            )
        case .grooming:
            GroomingLiveScreen(sessionId: sessionId)
        case .inSitting, .outSitting, .petSitting:
            CareLiveScreen(sessionId: sessionId, serviceType: .sitting)
        case .boarding:
            CareLiveScreen(sessionId: sessionId, serviceType: .boarding)
        case .daycare:
            DaycareLiveScreen(sessionId: sessionId)
        case .training:
            TrainingLiveScreen(sessionId: sessionId)
        }
    }

    private func liveIconForService(_ type: BookingServiceType) -> String {
        switch type {
        case .walk:       return "location.fill"
        case .grooming:   return "scissors"
        case .inSitting, .outSitting, .petSitting: return "house.fill"
        case .boarding:   return "bed.double.fill"
        case .daycare:    return "sun.and.horizon.fill"
        case .training:   return "star.fill"
        case .meetGreet:  return "hand.wave.fill"
        }
    }

    private func liveLabelForService(_ type: BookingServiceType) -> String {
        switch type {
        case .walk:       return "View Live Tracking"
        case .grooming:   return "View Grooming Progress"
        case .inSitting, .outSitting, .petSitting: return "View Care Updates"
        case .boarding:   return "View Boarding Updates"
        case .daycare:    return "View Daycare Activity"
        case .training:   return "View Training Session"
        case .meetGreet:  return "View Live Tracking"
        }
    }

    // MARK: - Cancel Sheet

    private var cancelSheet: some View {
        let isRecurring = viewModel.booking?.isRecurring ?? false

        return NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: isRecurring ? "repeat.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(isRecurring ? .turquoise60 : .orange)

                Text(isRecurring ? "Cancel Repeating Booking" : "Cancel Booking?")
                    .font(.title2.bold())
                    .foregroundColor(AppColors.Dark.onSurface)

                Text(isRecurring
                     ? "This booking is part of a repeating series. What would you like to cancel?"
                     : "Are you sure you want to cancel this booking? This action cannot be undone.")
                    .font(.subheadline)
                    .foregroundColor(AppColors.Dark.onSurfaceVariant)
                    .multilineTextAlignment(.center)

                if isRecurring {
                    VStack(spacing: 8) {
                        ForEach(RecurrenceCancelScope.allCases) { scope in
                            cancelScopeRow(scope)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Reason (optional)")
                        .font(.caption)
                        .foregroundColor(AppColors.Dark.onSurfaceVariant)

                    TextEditor(text: $viewModel.cancelReason)
                        .frame(minHeight: 80)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppColors.Dark.surfaceVariant)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AppColors.Dark.outlineVariant, lineWidth: 1)
                        )
                }

                Spacer()

                Button {
                    viewModel.cancelBooking()
                } label: {
                    HStack {
                        if viewModel.isCancelling {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Cancel Booking")
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.error50)
                    )
                }
                .disabled(viewModel.isCancelling)

                Button("Keep Booking") {
                    viewModel.showCancelDialog = false
                }
                .font(.subheadline.bold())
                .foregroundColor(AppColors.Dark.onSurfaceVariant)
            }
            .padding(24)
            .background(AppColors.Dark.background)
            .navigationTitle("Cancel Booking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { viewModel.showCancelDialog = false } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.Dark.onSurfaceVariant)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func cancelScopeRow(_ scope: RecurrenceCancelScope) -> some View {
        let isSelected = viewModel.cancelScope == scope
        return Button {
            viewModel.cancelScope = scope
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isSelected ? .turquoise60 : AppColors.Dark.onSurfaceVariant)
                Text(scope.displayName)
                    .font(.subheadline)
                    .foregroundColor(AppColors.Dark.onSurface)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected
                          ? AppColors.Dark.surfaceVariant
                          : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isSelected ? Color.turquoise60 : AppColors.Dark.outlineVariant,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tip Sheet

    private var tipSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Show your appreciation")
                    .font(.subheadline)
                    .foregroundColor(AppColors.Dark.onSurfaceVariant)

                Text(viewModel.formatPrice(viewModel.tipAmount))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.Dark.primary)

                // Preset amounts
                HStack(spacing: 12) {
                    ForEach([5.0, 10.0, 15.0, 20.0], id: \.self) { amount in
                        Button {
                            viewModel.tipAmount = amount
                        } label: {
                            Text(viewModel.formatPrice(amount))
                                .font(.subheadline.bold())
                                .foregroundColor(
                                    viewModel.tipAmount == amount
                                        ? AppColors.Dark.onPrimaryContainer
                                        : AppColors.Dark.onSurfaceVariant
                                )
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(
                                            viewModel.tipAmount == amount
                                                ? AppColors.Dark.primaryContainer
                                                : AppColors.Dark.surfaceVariant
                                        )
                                )
                        }
                    }
                }

                Slider(value: $viewModel.tipAmount, in: 1...50, step: 1)
                    .tint(AppColors.Dark.primary)

                Spacer()

                Button {
                    viewModel.addTip()
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isSubmittingTip {
                            ProgressView()
                                .tint(AppColors.Dark.onPrimary)
                        }
                        Text("Add \(viewModel.formatPrice(viewModel.tipAmount)) Tip")
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(AppColors.Dark.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.Dark.primary)
                    )
                }
                .disabled(viewModel.isSubmittingTip)
            }
            .padding(24)
            .background(AppColors.Dark.background)
            .navigationTitle("Add a Tip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { viewModel.showTipSheet = false } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.Dark.onSurfaceVariant)
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Review Sheet

    private var reviewSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("How was your experience?")
                    .font(.subheadline)
                    .foregroundColor(AppColors.Dark.onSurfaceVariant)

                // Star rating
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { star in
                        Button {
                            viewModel.reviewRating = star
                        } label: {
                            Image(systemName: star <= viewModel.reviewRating ? "star.fill" : "star")
                                .font(.system(size: 36))
                                .foregroundColor(
                                    star <= viewModel.reviewRating
                                        ? Color(hex: 0xFFB300)
                                        : AppColors.Dark.outlineVariant
                                )
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Your review (optional)")
                        .font(.caption)
                        .foregroundColor(AppColors.Dark.onSurfaceVariant)

                    TextEditor(text: $viewModel.reviewComment)
                        .frame(minHeight: 100)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppColors.Dark.surfaceVariant)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AppColors.Dark.outlineVariant, lineWidth: 1)
                        )
                }

                Spacer()

                Button {
                    viewModel.submitReview()
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isSubmittingReview {
                            ProgressView()
                                .tint(AppColors.Dark.onPrimary)
                        }
                        Text("Submit Review")
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(AppColors.Dark.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.Dark.primary)
                    )
                }
                .disabled(viewModel.isSubmittingReview)
            }
            .padding(24)
            .background(AppColors.Dark.background)
            .navigationTitle("Leave a Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { viewModel.showReviewSheet = false } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.Dark.onSurfaceVariant)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Report Sheet

    private var reportSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Please describe the issue you experienced:")
                    .font(.subheadline)
                    .foregroundColor(AppColors.Dark.onSurfaceVariant)

                TextEditor(text: $viewModel.reportText)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppColors.Dark.surfaceVariant)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppColors.Dark.outlineVariant, lineWidth: 1)
                    )

                Spacer()

                Button {
                    viewModel.submitReport()
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isSubmittingReport {
                            ProgressView()
                                .tint(AppColors.Dark.onPrimary)
                        }
                        Text("Submit Report")
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(AppColors.Dark.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.Dark.primary)
                    )
                }
                .disabled(viewModel.isSubmittingReport || viewModel.reportText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(viewModel.reportText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
            }
            .padding(24)
            .background(AppColors.Dark.background)
            .navigationTitle("Report an Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { viewModel.showReportSheet = false } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.Dark.onSurfaceVariant)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Snackbar

    private func snackbar(message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.neutral30)
            )
            .padding(.bottom, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation { viewModel.snackbarMessage = nil }
                }
            }
    }
}

// MARK: - Timeline Event Model

private struct TimelineEvent {
    let title: String
    let time: String?
    let isActive: Bool
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BookingDetailScreen(bookingId: "preview-123")
    }
    .preferredColorScheme(.dark)
}
