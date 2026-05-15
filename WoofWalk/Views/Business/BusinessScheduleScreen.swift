import SwiftUI

// MARK: - View Mode

private enum ScheduleViewMode: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case agenda = "Agenda"
}

// MARK: - Filter Chip

private enum ScheduleFilter: String, CaseIterable {
    case myJobs = "My Jobs"
    case walks = "Walks"
    case grooming = "Grooming"
    case sitting = "Sitting"

    var icon: String {
        switch self {
        case .myJobs: return "person.fill"
        case .walks: return "figure.walk"
        case .grooming: return "scissors"
        case .sitting: return "house.fill"
        }
    }
}

// MARK: - Color from Hex Helper

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Business Schedule Screen

struct BusinessScheduleScreen: View {
    @ObservedObject var viewModel: BusinessViewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedDate: Date = Date()
    @State private var selectedViewMode: ScheduleViewMode = .day
    @State private var selectedFilters: Set<ScheduleFilter> = [.myJobs]
    @State private var expandedBookingId: String?
    @State private var showRejectAlert = false
    @State private var bookingToReject: String?
    /// Set when the business owner taps "Cancel" on a confirmed booking.
    /// Presents the `RefundBookingDialog`, which talks to the
    /// `processRefund` CF + flips the booking status to CANCELLED.
    @State private var bookingToRefund: BusinessBooking?

    private let calendar = Calendar.current

    /// All bookings for the selected date, filtered by service type chips.
    private var jobsForSelectedDate: [BusinessBooking] {
        let dayStart = calendar.startOfDay(for: selectedDate)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

        return viewModel.allBookings.filter { job in
            job.scheduledDate >= dayStart && job.scheduledDate < dayEnd
        }.filter { job in
            guard !selectedFilters.contains(.myJobs) else { return true }
            let type = job.serviceType.lowercased()
            if selectedFilters.contains(.walks) && type.contains("walk") { return true }
            if selectedFilters.contains(.grooming) && type.contains("groom") { return true }
            if selectedFilters.contains(.sitting) && (type.contains("sit") || type.contains("board")) { return true }
            return false
        }
    }

    /// Bookings grouped by date for agenda view (next 7 days from selected date).
    private var agendaGroupedBookings: [(date: Date, bookings: [BusinessBooking])] {
        var groups: [(date: Date, bookings: [BusinessBooking])] = []

        for dayOffset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: selectedDate)) else { continue }
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: day) ?? day

            let dayBookings = viewModel.allBookings.filter { job in
                job.scheduledDate >= day && job.scheduledDate < dayEnd
            }.filter { job in
                guard !selectedFilters.contains(.myJobs) else { return true }
                let type = job.serviceType.lowercased()
                if selectedFilters.contains(.walks) && type.contains("walk") { return true }
                if selectedFilters.contains(.grooming) && type.contains("groom") { return true }
                if selectedFilters.contains(.sitting) && (type.contains("sit") || type.contains("board")) { return true }
                return false
            }.sorted { $0.scheduledDate < $1.scheduledDate }

            if !dayBookings.isEmpty {
                groups.append((date: day, bookings: dayBookings))
            }
        }

        return groups
    }

    /// Bookings count per day for the current week (for week view dots).
    private func bookingsForDay(_ day: Date) -> [BusinessBooking] {
        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        return viewModel.allBookings.filter { $0.scheduledDate >= dayStart && $0.scheduledDate < dayEnd }
    }

    // MARK: - Theme helpers

    private var surfaceColor: Color {
        colorScheme == .dark ? AppColors.Dark.surface : AppColors.Light.surface
    }

    private var onSurfaceColor: Color {
        colorScheme == .dark ? AppColors.Dark.onSurface : AppColors.Light.onSurface
    }

    private var onSurfaceVariantColor: Color {
        colorScheme == .dark ? AppColors.Dark.onSurfaceVariant : AppColors.Light.onSurfaceVariant
    }

    private var surfaceVariantColor: Color {
        colorScheme == .dark ? AppColors.Dark.surfaceVariant : AppColors.Light.surfaceVariant
    }

    private var primaryColor: Color {
        colorScheme == .dark ? AppColors.Dark.primary : AppColors.Light.primary
    }

    private var onPrimaryColor: Color {
        colorScheme == .dark ? AppColors.Dark.onPrimary : AppColors.Light.onPrimary
    }

    private var outlineColor: Color {
        colorScheme == .dark ? AppColors.Dark.outline : AppColors.Light.outline
    }

    private var outlineVariantColor: Color {
        colorScheme == .dark ? AppColors.Dark.outlineVariant : AppColors.Light.outlineVariant
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? AppColors.Dark.background : AppColors.Light.background
    }

    // MARK: - Date helpers

    private var dayOfWeekString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: selectedDate)
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: selectedDate)
    }

    private var isToday: Bool {
        calendar.isDateInToday(selectedDate)
    }

    private func dateHeaderString(for date: Date) -> String {
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date)
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                topBar
                dateNavigationHeader
                filterChipsRow
                viewModeTabs
                Divider().background(outlineVariantColor)

                // Content area
                switch selectedViewMode {
                case .day:
                    dayTimelineView
                case .week:
                    weekGridView
                case .agenda:
                    agendaListView
                }
            }
            .background(backgroundColor)

            // FAB
            fabButton
        }
        .alert("Reject Booking", isPresented: $showRejectAlert) {
            Button("Cancel", role: .cancel) {
                bookingToReject = nil
            }
            Button("Reject", role: .destructive) {
                if let id = bookingToReject {
                    viewModel.rejectBooking(bookingId: id)
                }
                bookingToReject = nil
            }
        } message: {
            Text("Are you sure you want to reject this booking? The client will be notified.")
        }
        // Refund sheet for confirmed-booking cancellations. Computes the
        // policy-recommended refund on-device, then routes through the
        // `processRefund` Cloud Function. Mirrors Android's
        // `BookingDetailScreen.kt#RefundDialog` flow.
        .sheet(item: $bookingToRefund) { businessBooking in
            RefundBookingDialog(
                booking: bookingFromBusinessBooking(businessBooking),
                onCompleted: {
                    bookingToRefund = nil
                    viewModel.refresh()
                },
                onDismiss: {
                    bookingToRefund = nil
                }
            )
        }
    }

    /// Build a minimal `Booking` from the lightweight `BusinessBooking`
    /// so the refund dialog can compute hours-until-start and price
    /// without re-fetching the doc. The dialog only reads `id`,
    /// `startTime`, `price`, `computedPrice` — everything else can be
    /// left at its default.
    private func bookingFromBusinessBooking(_ b: BusinessBooking) -> Booking {
        let startMs = Int64(b.scheduledDate.timeIntervalSince1970 * 1000)
        let endMs = Int64((b.endDate ?? b.scheduledDate).timeIntervalSince1970 * 1000)
        return Booking(
            id: b.id,
            clientName: b.clientName,
            startTime: startMs,
            endTime: endMs,
            status: b.status,
            location: b.location,
            price: b.price,
            isPaid: b.isPaid
        )
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Text("Schedule")
                .font(.title2.bold())
                .foregroundColor(onSurfaceColor)

            Spacer()

            Button {
                // Calendar grid action
            } label: {
                Image(systemName: "calendar")
                    .font(.title3)
                    .foregroundColor(onSurfaceVariantColor)
            }

            Button {
                // Filter action
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.title3)
                    .foregroundColor(onSurfaceVariantColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(surfaceColor)
    }

    // MARK: - Date Navigation Header

    private var dateNavigationHeader: some View {
        HStack {
            Button {
                selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundColor(onSurfaceVariantColor)
                    .frame(width: 40, height: 40)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(dayOfWeekString)
                    .font(.headline)
                    .foregroundColor(onSurfaceColor)
                Text(dateString)
                    .font(.subheadline)
                    .foregroundColor(onSurfaceVariantColor)
            }

            Spacer()

            Button {
                selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundColor(onSurfaceVariantColor)
                    .frame(width: 40, height: 40)
            }

            if !isToday {
                Button {
                    selectedDate = Date()
                } label: {
                    Text("Today")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(primaryColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(primaryColor, lineWidth: 1)
                        )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(surfaceColor)
    }

    // MARK: - Filter Chips Row

    private var filterChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ScheduleFilter.allCases, id: \.self) { filter in
                    filterChip(filter)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(surfaceColor)
    }

    private func filterChip(_ filter: ScheduleFilter) -> some View {
        let isSelected = selectedFilters.contains(filter)
        return Button {
            if isSelected {
                selectedFilters.remove(filter)
            } else {
                selectedFilters.insert(filter)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.caption)
                Text(filter.rawValue)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundColor(isSelected ? onPrimaryColor : onSurfaceVariantColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? primaryColor : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.clear : outlineColor, lineWidth: 1)
            )
        }
    }

    // MARK: - View Mode Tabs

    private var viewModeTabs: some View {
        HStack(spacing: 0) {
            ForEach(ScheduleViewMode.allCases, id: \.self) { mode in
                viewModeTab(mode)
            }
        }
        .background(surfaceColor)
    }

    private func viewModeTab(_ mode: ScheduleViewMode) -> some View {
        let isSelected = selectedViewMode == mode
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedViewMode = mode
            }
        } label: {
            VStack(spacing: 8) {
                Text(mode.rawValue)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? primaryColor : onSurfaceVariantColor)

                Rectangle()
                    .fill(isSelected ? primaryColor : Color.clear)
                    .frame(height: 2)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Service Color Helper

    private func serviceColor(for job: BusinessBooking) -> Color {
        Color(hex: job.serviceTypeEnum.colorHex)
    }

    // MARK: - Status Badge

    private func statusBadge(for job: BusinessBooking) -> some View {
        let status = job.statusEnum
        return Text(status.displayName)
            .font(.caption2.weight(.semibold))
            .foregroundColor(status.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(status.color.opacity(0.15))
            )
    }

    // MARK: - Day Timeline View

    private var dayTimelineView: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(6..<22, id: \.self) { hour in
                    timelineRow(hour: hour)
                }
            }
            .padding(.top, 8)
        }
    }

    private func jobsAtHour(_ hour: Int) -> [BusinessBooking] {
        jobsForSelectedDate.filter { job in
            calendar.component(.hour, from: job.scheduledDate) == hour
        }
    }

    private func timelineRow(hour: Int) -> some View {
        let hourJobs = jobsAtHour(hour)

        return HStack(alignment: .top, spacing: 0) {
            // Hour label
            Text(String(format: "%02d:00", hour))
                .font(.caption)
                .foregroundColor(onSurfaceVariantColor)
                .frame(width: 56, alignment: .trailing)
                .padding(.trailing, 8)

            // Divider line and slot area
            VStack(alignment: .leading, spacing: 4) {
                Divider()
                    .background(outlineVariantColor)

                if hourJobs.isEmpty {
                    Spacer()
                } else {
                    ForEach(hourJobs) { job in
                        dayTimelineBookingCard(job: job)
                    }
                }
            }
            .frame(minHeight: 60)
        }
        .padding(.horizontal, 8)
    }

    /// Rich booking card for day timeline view.
    private func dayTimelineBookingCard(job: BusinessBooking) -> some View {
        let color = serviceColor(for: job)
        let isExpanded = expandedBookingId == job.id

        return VStack(alignment: .leading, spacing: 0) {
            // Color indicator bar
            Rectangle()
                .fill(color)
                .frame(height: 4)

            VStack(alignment: .leading, spacing: 6) {
                // Header: time range + status badge
                HStack {
                    Image(systemName: job.serviceTypeEnum.icon)
                        .font(.caption)
                        .foregroundColor(color)

                    Text(job.timeRangeString)
                        .font(.caption.bold())
                        .foregroundColor(onSurfaceColor)

                    Spacer()

                    statusBadge(for: job)
                }

                // Dog name
                if let dogName = job.dogName, !dogName.isEmpty {
                    Text(dogName)
                        .font(.subheadline.bold())
                        .foregroundColor(onSurfaceColor)
                }

                // Client + service type
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.caption2)
                        .foregroundColor(onSurfaceVariantColor)
                    Text(job.clientName)
                        .font(.caption)
                        .foregroundColor(onSurfaceVariantColor)

                    Text(" -- ")
                        .font(.caption2)
                        .foregroundColor(onSurfaceVariantColor)

                    Text(job.serviceTypeEnum.displayName)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(color)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(color.opacity(0.12))
                        )
                }

                // Expanded details
                if isExpanded {
                    if !job.location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                                .foregroundColor(onSurfaceVariantColor)
                            Text(job.location)
                                .font(.caption2)
                                .foregroundColor(onSurfaceVariantColor)
                        }
                    }

                    if let instructions = job.specialInstructions, !instructions.isEmpty {
                        Text(instructions)
                            .font(.caption2)
                            .foregroundColor(onSurfaceVariantColor)
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(surfaceVariantColor.opacity(0.5))
                            )
                    }

                    // Price row
                    HStack {
                        Text(job.priceString)
                            .font(.subheadline.bold())
                            .foregroundColor(onSurfaceColor)

                        Spacer()

                        Text(job.isPaid ? "Paid" : "Unpaid")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(job.isPaid ? Color(hex: "#4CAF50") : .red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill((job.isPaid ? Color(hex: "#4CAF50") : .red).opacity(0.12))
                            )
                    }
                }

                // Start Walk button for confirmed bookings
                if job.statusEnum == .confirmed || job.statusEnum == .inProgress {
                    NavigationLink(value: AppRoute.businessWalkConsole(bookingId: job.id)) {
                        HStack(spacing: 6) {
                            Image(systemName: "figure.walk")
                                .font(.caption2.bold())
                            Text(job.statusEnum == .inProgress ? "Resume Walk" : "Start Walk")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(hex: "#4CAF50"))
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Accept/Reject buttons for pending bookings
                if job.statusEnum == .pending {
                    HStack(spacing: 8) {
                        Spacer()

                        Button {
                            bookingToReject = job.id
                            showRejectAlert = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark")
                                    .font(.caption2.bold())
                                Text("Reject")
                                    .font(.caption.weight(.medium))
                            }
                            .foregroundColor(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.red.opacity(0.1))
                            )
                        }

                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewModel.acceptBooking(bookingId: job.id)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                    .font(.caption2.bold())
                                Text("Accept")
                                    .font(.caption.weight(.medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(hex: "#4CAF50"))
                            )
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .padding(10)
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedBookingId = (expandedBookingId == job.id) ? nil : job.id
            }
        }
    }

    // MARK: - Week Grid View

    private var weekGridView: some View {
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        let days = (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: startOfWeek)
        }
        let dayFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "EEE"
            return f
        }()
        let dayNumberFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "d"
            return f
        }()

        return ScrollView {
            VStack(spacing: 0) {
                // Day headers with booking dots
                HStack(spacing: 0) {
                    // Time column spacer
                    Color.clear
                        .frame(width: 56)

                    ForEach(days, id: \.self) { day in
                        let isDayToday = calendar.isDateInToday(day)
                        let isDaySelected = calendar.isDate(day, inSameDayAs: selectedDate)
                        let dayBookings = bookingsForDay(day)

                        Button {
                            selectedDate = day
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedViewMode = .day
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Text(dayFormatter.string(from: day))
                                    .font(.caption2)
                                    .foregroundColor(isDayToday ? primaryColor : onSurfaceVariantColor)
                                Text(dayNumberFormatter.string(from: day))
                                    .font(.subheadline.weight(isDayToday ? .bold : .regular))
                                    .foregroundColor(isDayToday ? onPrimaryColor : onSurfaceColor)
                                    .frame(width: 28, height: 28)
                                    .background(
                                        Circle()
                                            .fill(isDayToday ? primaryColor : (isDaySelected ? surfaceVariantColor : Color.clear))
                                    )

                                // Booking indicator dots
                                if !dayBookings.isEmpty {
                                    HStack(spacing: 2) {
                                        // Show up to 3 colored dots representing service types
                                        let uniqueTypes = Array(Set(dayBookings.map { $0.serviceTypeEnum })).prefix(3)
                                        ForEach(Array(uniqueTypes.enumerated()), id: \.offset) { _, serviceType in
                                            Circle()
                                                .fill(Color(hex: serviceType.colorHex))
                                                .frame(width: 5, height: 5)
                                        }
                                        if dayBookings.count > 3 {
                                            Text("+")
                                                .font(.system(size: 7, weight: .bold))
                                                .foregroundColor(onSurfaceVariantColor)
                                        }
                                    }
                                    .frame(height: 6)
                                } else {
                                    Spacer().frame(height: 6)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.vertical, 12)
                .background(surfaceColor)

                Divider().background(outlineVariantColor)

                // Hour rows with booking indicators
                ForEach(6..<22, id: \.self) { hour in
                    HStack(alignment: .top, spacing: 0) {
                        Text(String(format: "%02d", hour))
                            .font(.caption2)
                            .foregroundColor(onSurfaceVariantColor)
                            .frame(width: 56, alignment: .trailing)
                            .padding(.trailing, 4)

                        ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                            let dayStart = calendar.startOfDay(for: day)
                            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
                            let hourBookings = viewModel.allBookings.filter { job in
                                job.scheduledDate >= dayStart && job.scheduledDate < dayEnd &&
                                calendar.component(.hour, from: job.scheduledDate) == hour
                            }

                            ZStack(alignment: .topLeading) {
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 40)
                                    .overlay(
                                        Rectangle()
                                            .fill(outlineVariantColor.opacity(0.3))
                                            .frame(height: 0.5),
                                        alignment: .top
                                    )

                                if !hourBookings.isEmpty {
                                    VStack(spacing: 1) {
                                        ForEach(hourBookings.prefix(2)) { booking in
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(Color(hex: booking.serviceTypeEnum.colorHex).opacity(0.7))
                                                .frame(height: hourBookings.count > 1 ? 16 : 34)
                                                .overlay(
                                                    Text(booking.dogName ?? booking.serviceTypeEnum.displayName.prefix(1).uppercased())
                                                        .font(.system(size: 8, weight: .bold))
                                                        .foregroundColor(.white)
                                                        .lineLimit(1)
                                                )
                                        }
                                    }
                                    .padding(.horizontal, 1)
                                    .padding(.top, 2)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Agenda List View

    private var agendaListView: some View {
        ScrollView {
            let groups = agendaGroupedBookings

            if groups.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 48))
                        .foregroundColor(onSurfaceVariantColor)

                    Text("No events scheduled")
                        .font(.headline)
                        .foregroundColor(onSurfaceColor)

                    Text("Tap + to add a new booking")
                        .font(.subheadline)
                        .foregroundColor(onSurfaceVariantColor)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 80)
            } else {
                LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                    ForEach(groups, id: \.date) { group in
                        Section {
                            ForEach(group.bookings) { job in
                                agendaBookingCard(job: job)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                            }
                        } header: {
                            HStack {
                                Text(dateHeaderString(for: group.date))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(onSurfaceColor)
                                Spacer()
                                Text("\(group.bookings.count) booking\(group.bookings.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundColor(onSurfaceVariantColor)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(backgroundColor)
                        }
                    }
                }
            }
        }
    }

    /// Full booking card for the agenda view with accept/reject actions.
    private func agendaBookingCard(job: BusinessBooking) -> some View {
        let color = serviceColor(for: job)

        return VStack(alignment: .leading, spacing: 0) {
            // Color indicator bar
            Rectangle()
                .fill(color)
                .frame(height: 4)

            VStack(alignment: .leading, spacing: 8) {
                // Header: time + status
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                            .foregroundColor(onSurfaceVariantColor)
                        Text(job.timeRangeString)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(onSurfaceColor)
                    }

                    Spacer()

                    statusBadge(for: job)
                }

                // Dog name
                if let dogName = job.dogName, !dogName.isEmpty {
                    Text(dogName)
                        .font(.body.bold())
                        .foregroundColor(onSurfaceColor)
                }

                // Service type chip
                HStack(spacing: 6) {
                    Image(systemName: job.serviceTypeEnum.icon)
                        .font(.caption)
                        .foregroundColor(color)

                    Text(job.serviceTypeEnum.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(color.opacity(0.12))
                        )
                }

                // Client info
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.caption2)
                        .foregroundColor(onSurfaceVariantColor)
                    Text(job.clientName)
                        .font(.subheadline)
                        .foregroundColor(onSurfaceColor)
                }

                // Location
                if !job.location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                            .foregroundColor(onSurfaceVariantColor)
                        Text(job.location)
                            .font(.caption)
                            .foregroundColor(onSurfaceVariantColor)
                    }
                }

                // Special instructions
                if let instructions = job.specialInstructions, !instructions.isEmpty {
                    Text(instructions)
                        .font(.caption)
                        .foregroundColor(onSurfaceVariantColor)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(surfaceVariantColor.opacity(0.4))
                        )
                }

                // Price + payment row
                HStack {
                    Text(job.priceString)
                        .font(.subheadline.bold())
                        .foregroundColor(onSurfaceColor)

                    Spacer()

                    Text(job.isPaid ? "Paid" : "Unpaid")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(job.isPaid ? Color(hex: "#4CAF50") : .red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill((job.isPaid ? Color(hex: "#4CAF50") : .red).opacity(0.1))
                        )
                }

                // Start Walk button for confirmed bookings
                if job.statusEnum == .confirmed || job.statusEnum == .inProgress {
                    Divider()

                    HStack(spacing: 8) {
                        NavigationLink(value: AppRoute.businessWalkConsole(bookingId: job.id)) {
                            HStack(spacing: 6) {
                                Image(systemName: "figure.walk")
                                    .font(.subheadline.bold())
                                Text(job.statusEnum == .inProgress ? "Resume Walk" : "Start Walk")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(hex: "#4CAF50"))
                            )
                        }
                        .buttonStyle(.plain)

                        // Cancel with refund — Android parity hook into
                        // the RefundBookingDialog + processRefund CF.
                        // Hidden once the booking is in progress so we
                        // don't surface a destructive action mid-walk.
                        if job.statusEnum == .confirmed {
                            Button {
                                bookingToRefund = job
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.red)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(.red.opacity(0.1))
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Cancel booking")
                        }
                    }
                }

                // Accept/Reject buttons for pending bookings
                if job.statusEnum == .pending {
                    Divider()

                    HStack(spacing: 12) {
                        Spacer()

                        Button {
                            bookingToReject = job.id
                            showRejectAlert = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark")
                                    .font(.caption.bold())
                                Text("Reject")
                                    .font(.subheadline.weight(.medium))
                            }
                            .foregroundColor(.red)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.red.opacity(0.1))
                            )
                        }

                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewModel.acceptBooking(bookingId: job.id)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                Text("Accept")
                                    .font(.subheadline.weight(.medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(hex: "#4CAF50"))
                            )
                        }
                    }
                }
            }
            .padding(12)
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(surfaceColor)
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(outlineVariantColor.opacity(0.5), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - FAB

    private var fabButton: some View {
        Button {
            // Add new booking
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundColor(onPrimaryColor)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(primaryColor)
                        .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
                )
        }
        .padding(.trailing, 16)
        .padding(.bottom, 16)
    }
}

// MARK: - Preview

#Preview {
    BusinessScheduleScreen(viewModel: BusinessViewModel())
        .preferredColorScheme(.dark)
}
