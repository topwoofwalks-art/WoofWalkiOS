import Foundation
import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

/// ViewModel for the Client Home Screen.
/// Loads real dogs from the user document and upcoming bookings from Firestore.
@MainActor
class ClientHomeViewModel: ObservableObject {
    /// Dogs rendered on the client home screen — uses the denormalised
    /// public projection from `users/{uid}.dogs[]`. For screens that need
    /// medical/medication data, fetch the full `UnifiedDog` via
    /// `DogRepository.fetchDogs(forUserId:)`.
    @Published var dogs: [DogProfilePublic] = []
    @Published var upcomingBookings: [Booking] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    private let userRepository = UserRepository()
    private let bookingRepository = BookingRepository()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Greeting

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    /// Display name from Firebase Auth (first name or fallback)
    var displayName: String {
        if let name = Auth.auth().currentUser?.displayName, !name.isEmpty {
            return name.components(separatedBy: " ").first ?? name
        }
        return ""
    }

    // MARK: - Load Data

    func loadData() {
        isLoading = true
        errorMessage = nil
        loadDogs()
        loadBookings()
    }

    private func loadDogs() {
        userRepository.getUserProfile()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        print("[ClientHomeVM] Error loading user profile: \(error.localizedDescription)")
                        self?.errorMessage = error.localizedDescription
                        self?.isLoading = false
                    }
                },
                receiveValue: { [weak self] user in
                    self?.dogs = user?.dogs ?? []
                    self?.isLoading = false
                }
            )
            .store(in: &cancellables)
    }

    private func loadBookings() {
        guard let userId = Auth.auth().currentUser?.uid else {
            upcomingBookings = []
            return
        }

        bookingRepository.getClientBookings(clientId: userId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("[ClientHomeVM] Error loading bookings: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] bookings in
                    let now = Date()
                    self?.upcomingBookings = bookings
                        .filter { booking in
                            let status = booking.statusEnum
                            let isFuture = booking.startDate >= now
                            let isActive = status == .pending || status == .confirmed || status == .inProgress
                            return isFuture && isActive
                        }
                        .sorted { $0.startTime < $1.startTime }
                        .prefix(3)
                        .map { $0 }
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Formatting Helpers

    func formatBookingDate(_ booking: Booking) -> String {
        let date = booking.startDate
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Today at \(formatter.string(from: date))"
        } else if calendar.isDateInTomorrow(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Tomorrow at \(formatter.string(from: date))"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, MMM d 'at' h:mm a"
            return formatter.string(from: date)
        }
    }

    func formatPrice(_ price: Double) -> String {
        CurrencyFormatter.shared.formatPrice(price)
    }

    deinit {
        bookingRepository.cleanup()
    }
}
