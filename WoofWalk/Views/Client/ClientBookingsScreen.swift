import SwiftUI
import Combine
import FirebaseAuth

// MARK: - Booking Tab

enum BookingTab: String, CaseIterable {
    case upcoming
    case past
    case cancelled

    var title: String {
        switch self {
        case .upcoming: return "Upcoming"
        case .past: return "Past"
        case .cancelled: return "Cancelled"
        }
    }

    var emptyIcon: String {
        switch self {
        case .upcoming: return "calendar"
        case .past: return "clock.arrow.circlepath"
        case .cancelled: return "xmark.circle"
        }
    }

    var emptyTitle: String {
        switch self {
        case .upcoming: return "No upcoming bookings"
        case .past: return "No past bookings"
        case .cancelled: return "No cancelled bookings"
        }
    }

    var emptyMessage: String {
        switch self {
        case .upcoming: return "Book a service to see your upcoming appointments here"
        case .past: return "Your completed bookings will appear here"
        case .cancelled: return "Any cancelled bookings will appear here"
        }
    }
}

// MARK: - Client Bookings View Model

@MainActor
class ClientBookingsViewModel: ObservableObject {
    @Published var bookings: [Booking] = []
    @Published var isLoading = true

    private let bookingRepository = BookingRepository()
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadBookings()
    }

    func loadBookings() {
        guard let userId = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }

        isLoading = true

        bookingRepository.getClientBookings(clientId: userId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] bookings in
                self?.bookings = bookings
                self?.isLoading = false
            }
            .store(in: &cancellables)
    }

    func upcomingBookings(search: String) -> [Booking] {
        filterBookings(
            bookings.filter { booking in
                let status = booking.statusEnum
                return (status == .pending || status == .confirmed || status == .inProgress)
            },
            search: search
        )
    }

    func pastBookings(search: String) -> [Booking] {
        filterBookings(
            bookings.filter { $0.statusEnum == .completed },
            search: search
        )
    }

    func cancelledBookings(search: String) -> [Booking] {
        filterBookings(
            bookings.filter { $0.statusEnum == .cancelled || $0.statusEnum == .rejected },
            search: search
        )
    }

    private func filterBookings(_ list: [Booking], search: String) -> [Booking] {
        guard !search.isEmpty else { return list }
        let query = search.lowercased()
        return list.filter { booking in
            booking.dogName.lowercased().contains(query) ||
            booking.serviceTypeEnum.displayName.lowercased().contains(query) ||
            booking.location.lowercased().contains(query) ||
            (booking.assignedTo?.lowercased().contains(query) ?? false)
        }
    }

    func bookingsForTab(_ tab: BookingTab, search: String) -> [Booking] {
        switch tab {
        case .upcoming: return upcomingBookings(search: search)
        case .past: return pastBookings(search: search)
        case .cancelled: return cancelledBookings(search: search)
        }
    }

    func countForTab(_ tab: BookingTab) -> Int {
        switch tab {
        case .upcoming: return upcomingBookings(search: "").count
        case .past: return pastBookings(search: "").count
        case .cancelled: return cancelledBookings(search: "").count
        }
    }

    deinit {
        bookingRepository.cleanup()
    }
}

// MARK: - Client Bookings Screen

struct ClientBookingsScreen: View {
    @StateObject private var viewModel = ClientBookingsViewModel()
    @State private var searchText: String = ""
    @State private var selectedTab: BookingTab = .upcoming

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Search bar
                searchBar

                // Tab pills
                tabBar

                // Content
                bookingContent
            }
            .background(AppColors.Dark.background)

            // Floating Book Now button
            fabButton
        }
        .navigationTitle("My Bookings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    viewModel.loadBookings()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(AppColors.Dark.onSurface)
                }

                Button {
                    // Filter action
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundColor(AppColors.Dark.onSurface)
                }
            }
        }
        .toolbarBackground(AppColors.Dark.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppColors.Dark.onSurfaceVariant)
                .font(.subheadline)

            TextField("Search bookings...", text: $searchText)
                .font(.subheadline)
                .foregroundColor(AppColors.Dark.onSurface)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.Dark.onSurfaceVariant)
                        .font(.subheadline)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.Dark.surfaceVariant)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(BookingTab.allCases, id: \.self) { tab in
                tabPill(tab)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    private func tabPill(_ tab: BookingTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 8) {
                Text("\(tab.title) (\(viewModel.countForTab(tab)))")
                    .font(.subheadline)
                    .fontWeight(selectedTab == tab ? .semibold : .regular)
                    .foregroundColor(
                        selectedTab == tab
                            ? AppColors.Dark.primary
                            : AppColors.Dark.onSurfaceVariant
                    )
                    .frame(maxWidth: .infinity)

                // Underline indicator
                Rectangle()
                    .fill(selectedTab == tab ? AppColors.Dark.primary : Color.clear)
                    .frame(height: 2)
                    .cornerRadius(1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Booking Content

    private var bookingContent: some View {
        Group {
            if viewModel.isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .tint(AppColors.Dark.primary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let filtered = viewModel.bookingsForTab(selectedTab, search: searchText)
                if filtered.isEmpty {
                    VStack {
                        Spacer()
                        emptyStateView(for: selectedTab)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filtered, id: \.id) { booking in
                                NavigationLink(value: AppRoute.clientBookingDetail(bookingId: booking.id ?? "")) {
                                    bookingCard(booking)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 80) // Space for FAB
                    }
                }
            }
        }
    }

    // MARK: - Booking Card

    private func bookingCard(_ booking: Booking) -> some View {
        let timeFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "EEE, MMM d 'at' h:mm a"
            return f
        }()

        return VStack(alignment: .leading, spacing: 10) {
            // Top row: service type + status badge
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: booking.serviceTypeEnum.icon)
                        .font(.subheadline)
                        .foregroundColor(AppColors.Dark.primary)
                    Text(booking.serviceTypeEnum.displayName)
                        .font(.subheadline.bold())
                        .foregroundColor(AppColors.Dark.onSurface)
                }

                Spacer()

                // Status badge
                Text(booking.statusEnum.displayName)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(booking.statusEnum.color)
                    )
            }

            // Provider
            if let assignedTo = booking.assignedTo, !assignedTo.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "person.fill")
                        .font(.caption2)
                        .foregroundColor(AppColors.Dark.onSurfaceVariant)
                    Text(assignedTo)
                        .font(.caption)
                        .foregroundColor(AppColors.Dark.onSurfaceVariant)
                }
            }

            // Date + dog
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                        .foregroundColor(AppColors.Dark.onSurfaceVariant)
                    Text(timeFormatter.string(from: booking.startDate))
                        .font(.caption)
                        .foregroundColor(AppColors.Dark.onSurfaceVariant)
                }

                HStack(spacing: 4) {
                    Image(systemName: "dog.fill")
                        .font(.caption2)
                        .foregroundColor(AppColors.Dark.onSurfaceVariant)
                    Text(booking.dogName)
                        .font(.caption)
                        .foregroundColor(AppColors.Dark.onSurfaceVariant)
                }
            }

            // Bottom row: price + chevron
            HStack {
                Text(String(format: "$%.2f", booking.price))
                    .font(.subheadline.bold())
                    .foregroundColor(AppColors.Dark.primary)

                if booking.isPaid {
                    Text("Paid")
                        .font(.caption2.bold())
                        .foregroundColor(.success60)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.Dark.onSurfaceVariant)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppColors.Dark.surfaceVariant)
        )
    }

    // MARK: - Empty State

    private func emptyStateView(for tab: BookingTab) -> some View {
        VStack(spacing: 16) {
            // Calendar grid icon in circle
            ZStack {
                Circle()
                    .fill(AppColors.Dark.surfaceVariant)
                    .frame(width: 80, height: 80)

                Image(systemName: tab.emptyIcon)
                    .font(.system(size: 32))
                    .foregroundColor(AppColors.Dark.onSurfaceVariant)
            }

            Text(tab.emptyTitle)
                .font(.title3.bold())
                .foregroundColor(AppColors.Dark.onSurface)

            Text(tab.emptyMessage)
                .font(.subheadline)
                .foregroundColor(AppColors.Dark.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if tab == .upcoming {
                Button {
                    // Navigate to booking flow
                } label: {
                    Text("Book Now")
                        .font(.subheadline.bold())
                        .foregroundColor(AppColors.Dark.onPrimary)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(AppColors.Dark.primary)
                        )
                }
                .padding(.top, 8)
            }
        }
    }

    // MARK: - FAB

    private var fabButton: some View {
        Button {
            // Navigate to booking flow
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.body.bold())
                Text("Book Now")
                    .font(.subheadline.bold())
            }
            .foregroundColor(AppColors.Dark.onPrimaryContainer)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(AppColors.Dark.primaryContainer)
                    .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
            )
        }
        .padding(.trailing, 16)
        .padding(.bottom, 16)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ClientBookingsScreen()
    }
    .preferredColorScheme(.dark)
}
