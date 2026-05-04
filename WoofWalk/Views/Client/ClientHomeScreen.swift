import SwiftUI

// MARK: - Client Home Screen

struct ClientHomeScreen: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = ClientHomeViewModel()
    @State private var showAddDog = false
    @State private var showBookingFlow = false
    @State private var preselectedService: ServiceType?
    @State private var providerSearchService: ServiceType?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Green top banner with greeting
                topBanner

                if viewModel.isLoading {
                    loadingView
                } else {
                    VStack(spacing: 20) {
                        // Book Now button
                        bookNowButton
                            .padding(.top, 16)

                        // Services section
                        servicesSection

                        // Upcoming Bookings section
                        upcomingBookingsSection

                        // Meet & Greet inbox entry — return path for
                        // anyone who started a request and navigated
                        // away. Lives between Bookings and Dogs so
                        // it's discoverable without crowding the top.
                        meetGreetInboxCard

                        // My Dogs section
                        myDogsSection

                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .background(Color.neutral10)
        .navigationBarHidden(true)
        .refreshable {
            viewModel.loadData()
        }
        .onAppear {
            viewModel.loadData()
        }
        .sheet(isPresented: $showAddDog) {
            NavigationStack {
                DogProfileSheet(dog: nil, onDismiss: { showAddDog = false }, onSave: { _ in showAddDog = false })
            }
        }
        .fullScreenCover(isPresented: $showBookingFlow) {
            BookingFlowScreen(preselectedService: preselectedService)
        }
        .sheet(item: $providerSearchService) { service in
            NavigationStack {
                ProviderSearchView(serviceType: service)
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .tint(.white)
            Text("Loading...")
                .font(.subheadline)
                .foregroundColor(.neutral60)
            Spacer()
        }
        .frame(minHeight: 300)
    }

    // MARK: - Top Banner

    private var topBanner: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.greeting + (viewModel.displayName.isEmpty ? "" : ","))
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))

                if !viewModel.displayName.isEmpty {
                    Text(viewModel.displayName)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                } else {
                    Text("WoofWalk")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }
            }

            Spacer()

            Image(systemName: "pawprint.fill")
                .font(.title2)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.success40)
    }

    // MARK: - Book Now Button

    private var bookNowButton: some View {
        Button {
            preselectedService = nil
            showBookingFlow = true
        } label: {
            HStack {
                Image(systemName: "calendar.badge.plus")
                    .font(.title3)
                Text("Book Now")
                    .font(.title3.bold())
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x7C4DFF), Color(hex: 0xB388FF)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
        }
    }

    // MARK: - Services Section

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Services")
                .font(.title3.bold())
                .foregroundColor(.neutral90)

            ServiceCardsGrid { service in
                providerSearchService = service
            }
        }
    }

    // MARK: - Upcoming Bookings Section

    private var upcomingBookingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming Bookings")
                    .font(.title3.bold())
                    .foregroundColor(.neutral90)

                Spacer()

                if !viewModel.upcomingBookings.isEmpty {
                    Button {
                        // Navigate to bookings tab
                    } label: {
                        Text("View All")
                            .font(.subheadline.bold())
                            .foregroundColor(.turquoise60)
                    }
                }
            }

            if viewModel.upcomingBookings.isEmpty {
                emptyBookingsCard
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.upcomingBookings) { booking in
                        bookingCard(booking)
                    }
                }
            }
        }
    }

    private var emptyBookingsCard: some View {
        HStack(spacing: 16) {
            Image(systemName: "calendar")
                .font(.system(size: 28))
                .foregroundColor(.neutral50)
            VStack(alignment: .leading, spacing: 4) {
                Text("No upcoming bookings")
                    .font(.subheadline)
                    .foregroundColor(.neutral60)
                Text("Book a service to get started")
                    .font(.caption)
                    .foregroundColor(.neutral50)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.neutral20)
        )
    }

    private func bookingCard(_ booking: Booking) -> some View {
        HStack(spacing: 12) {
            // Service type icon
            ZStack {
                Circle()
                    .fill(Color.turquoise30.opacity(0.5))
                    .frame(width: 44, height: 44)
                Image(systemName: booking.serviceTypeEnum.icon)
                    .font(.system(size: 18))
                    .foregroundColor(.turquoise70)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(booking.serviceTypeEnum.displayName)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)

                Text(booking.dogName)
                    .font(.caption)
                    .foregroundColor(.neutral60)

                Text(viewModel.formatBookingDate(booking))
                    .font(.caption2)
                    .foregroundColor(.neutral50)
            }

            Spacer()

            // Status pill
            Text(booking.statusEnum.displayName)
                .font(.caption2.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(booking.statusEnum.color)
                )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.neutral20)
        )
    }

    // MARK: - Meet & Greet inbox card

    /// Entry point to the client-side Meet & Greet inbox. Without
    /// this card, anyone who submits a request and navigates away
    /// has no way back to the conversation. Pushed inside the home
    /// NavigationStack via `.meetGreetClientInbox`.
    private var meetGreetInboxCard: some View {
        NavigationLink(value: AppRoute.meetGreetClientInbox) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.turquoise60.opacity(0.20))
                        .frame(width: 44, height: 44)
                    Image(systemName: "hand.wave.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.turquoise60)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Meet & Greets")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text("Conversations with providers before you book")
                        .font(.caption)
                        .foregroundColor(.neutral60)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(.neutral60)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.neutral20)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - My Dogs Section

    private var myDogsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("My Dogs")
                    .font(.title3.bold())
                    .foregroundColor(.neutral90)

                Spacer()

                Button {
                    showAddDog = true
                } label: {
                    Label("Add Dog", systemImage: "plus")
                        .font(.subheadline.bold())
                        .foregroundColor(.turquoise60)
                }
            }

            if viewModel.dogs.isEmpty {
                emptyDogsCard
            } else {
                // 2-column grid of dog cards
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                ], spacing: 12) {
                    ForEach(viewModel.dogs) { dog in
                        dogCard(dog)
                    }
                }
            }
        }
    }

    private var emptyDogsCard: some View {
        HStack(spacing: 16) {
            Image(systemName: "dog.fill")
                .font(.system(size: 36))
                .foregroundColor(.neutral50)
            VStack(alignment: .leading, spacing: 4) {
                Text("No dogs added yet")
                    .font(.subheadline)
                    .foregroundColor(.neutral60)
                Text("Add your dog to get started")
                    .font(.caption)
                    .foregroundColor(.neutral50)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.neutral20)
        )
    }

    private func dogCard(_ dog: DogProfilePublic) -> some View {
        Button {
            // Dog tap action
        } label: {
            HStack(spacing: 10) {
                // Dog avatar or placeholder
                if let photoUrl = dog.photoUrl, let url = URL(string: photoUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        dogPlaceholderIcon
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                } else {
                    dogPlaceholderIcon
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(dog.name)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text(dog.breed ?? "Mixed")
                        .font(.caption)
                        .foregroundColor(.neutral60)
                }

                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.neutral20)
            )
        }
    }

    private var dogPlaceholderIcon: some View {
        ZStack {
            Circle()
                .fill(Color.turquoise30.opacity(0.5))
                .frame(width: 44, height: 44)
            Image(systemName: "dog.fill")
                .font(.title3)
                .foregroundColor(.turquoise70)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ClientHomeScreen()
    }
    .preferredColorScheme(.dark)
}
