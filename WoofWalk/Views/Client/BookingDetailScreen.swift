import SwiftUI
import Combine
import FirebaseAuth

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

    // Snackbar
    @Published var snackbarMessage: String?

    private let bookingRepository = BookingRepository()
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

        Task {
            do {
                let reason = cancelReason.trimmingCharacters(in: .whitespacesAndNewlines)
                try await bookingRepository.cancelBooking(
                    bookingId: bookingId,
                    reason: reason.isEmpty ? nil : reason
                )
                isCancelling = false
                showCancelDialog = false
                cancelReason = ""
                snackbarMessage = "Booking cancelled"
            } catch {
                isCancelling = false
                snackbarMessage = "Failed to cancel: \(error.localizedDescription)"
            }
        }
    }

    func submitReview() {
        // In a real app, this would write to a reviews collection
        showReviewSheet = false
        snackbarMessage = "Review submitted - thank you!"
        reviewRating = 5
        reviewComment = ""
    }

    func addTip() {
        // In a real app, this would trigger a payment flow
        showTipSheet = false
        snackbarMessage = "Tip of \(formatPrice(tipAmount)) added - thank you!"
        tipAmount = 5.0
    }

    func submitReport() {
        // In a real app, this would write to a reports collection
        showReportSheet = false
        snackbarMessage = "Issue reported - we'll look into it"
        reportText = ""
    }

    func formatPrice(_ amount: Double) -> String {
        String(format: "$%.2f", amount)
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
                providerCard(booking)
                bookingDetailsCard(booking)

                if booking.statusEnum == .completed {
                    walkReportCard(booking)
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
                Text(booking.serviceTypeEnum.displayName)
                    .font(.subheadline)
                    .foregroundColor(AppColors.Dark.onSurfaceVariant)
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

            detailRow(icon: "banknote", label: "Price", value: String(format: "$%.2f", booking.price))

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
            case .pending, .confirmed:
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
                Button {
                    // Navigate to live tracking
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                        Text("View Live Tracking")
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

    // MARK: - Cancel Sheet

    private var cancelSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)

                Text("Cancel Booking?")
                    .font(.title2.bold())
                    .foregroundColor(AppColors.Dark.onSurface)

                Text("Are you sure you want to cancel this booking? This action cannot be undone.")
                    .font(.subheadline)
                    .foregroundColor(AppColors.Dark.onSurfaceVariant)
                    .multilineTextAlignment(.center)

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
                    Text("Add \(viewModel.formatPrice(viewModel.tipAmount)) Tip")
                        .font(.subheadline.bold())
                        .foregroundColor(AppColors.Dark.onPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.Dark.primary)
                        )
                }
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
                    Text("Submit Review")
                        .font(.subheadline.bold())
                        .foregroundColor(AppColors.Dark.onPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.Dark.primary)
                        )
                }
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
                    Text("Submit Report")
                        .font(.subheadline.bold())
                        .foregroundColor(AppColors.Dark.onPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.Dark.primary)
                        )
                }
                .disabled(viewModel.reportText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
