import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Models

struct BusinessBooking: Identifiable {
    let id: String
    let clientName: String
    let dogName: String?
    let serviceType: String
    let scheduledDate: Date
    let endDate: Date?
    let status: String
    let price: Double
    let isPaid: Bool
    let location: String
    let specialInstructions: String?

    var displayTitle: String {
        if let dog = dogName {
            return "\(serviceType) with \(dog)"
        }
        return serviceType
    }

    var displaySubtitle: String {
        if let dog = dogName {
            return "\(clientName) — \(dog)"
        }
        return clientName
    }

    /// Parsed booking status enum
    var statusEnum: BookingStatus {
        BookingStatus.from(rawValue: status)
    }

    /// Parsed service type enum
    var serviceTypeEnum: BookingServiceType {
        BookingServiceType.from(rawValue: serviceType)
    }

    /// Formatted time range string
    var timeRangeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let start = formatter.string(from: scheduledDate)
        if let end = endDate {
            let endStr = formatter.string(from: end)
            return "\(start) - \(endStr)"
        }
        return start
    }

    /// Formatted price string
    var priceString: String {
        CurrencyFormatter.shared.formatPrice(price)
    }
}

struct BusinessClient: Identifiable, Equatable {
    let id: String
    let name: String
    let email: String
    let phone: String
    let dogs: [String]
    let isActive: Bool
    let lastBooking: String
    let totalWalks: Int
    let totalSpent: Double
    let notes: String
}

struct ImportedClient: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let email: String
    let phone: String
    let dogs: [String]
    let notes: String
    let source: String
    var isDuplicate: Bool = false
    var duplicateMatch: String? = nil
}

// MARK: - ViewModel

@MainActor
class BusinessViewModel: ObservableObject {
    // MARK: - Published State

    @Published var isOnline: Bool = false
    @Published var todayEarnings: Double = 0.0
    @Published var monthlyEarnings: Double = 0.0
    @Published var upcomingJobs: [BusinessBooking] = []
    @Published var allBookings: [BusinessBooking] = []
    @Published var todayJobCount: Int = 0
    @Published var completedJobCount: Int = 0
    @Published var nextJobDetails: String?
    @Published var nextJobTime: Date?
    @Published var clients: [BusinessClient] = []
    @Published var isLoading: Bool = false
    @Published var error: String?

    // MARK: - Private

    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private var onlineStatusListener: ListenerRegistration?
    private var bookingsListener: ListenerRegistration?
    private var earningsListener: ListenerRegistration?
    private var clientsListener: ListenerRegistration?

    // MARK: - Init / Deinit

    init() {
        loadDashboardData()
    }

    deinit {
        onlineStatusListener?.remove()
        bookingsListener?.remove()
        earningsListener?.remove()
        clientsListener?.remove()
    }

    // MARK: - Public API

    func loadDashboardData() {
        guard let userId = auth.currentUser?.uid else {
            error = "Not signed in"
            isLoading = false
            return
        }

        isLoading = true
        error = nil

        observeOnlineStatus(userId: userId)
        observeBookings(userId: userId)
        observeEarnings(userId: userId)
        observeClients(userId: userId)
    }

    func toggleOnlineStatus() {
        guard let userId = auth.currentUser?.uid else { return }

        let newStatus = !isOnline

        db.collection("organizations")
            .document(userId)
            .setData([
                "isOnline": newStatus,
                "lastStatusUpdate": FieldValue.serverTimestamp()
            ], merge: true) { [weak self] error in
                if let error = error {
                    print("Failed to toggle online status: \(error.localizedDescription)")
                    self?.error = "Failed to update status"
                } else {
                    // Listener will update the local state
                    print("Online status toggled to: \(newStatus)")
                }
            }
    }

    func refresh() {
        loadDashboardData()
    }

    /// Accept a pending booking (sets status to CONFIRMED)
    func acceptBooking(bookingId: String) {
        guard let userId = auth.currentUser?.uid else { return }

        let updates: [String: Any] = [
            "status": BookingStatus.confirmed.rawValue,
            "updatedAt": Int64(Date().timeIntervalSince1970 * 1000)
        ]

        // Try org-scoped path first, then top-level bookings collection
        db.collection("organizations")
            .document(userId)
            .collection("bookings")
            .document(bookingId)
            .updateData(updates) { [weak self] error in
                if let error = error {
                    print("[BusinessViewModel] Error accepting booking in org path: \(error.localizedDescription)")
                    // Fallback to top-level bookings collection
                    self?.db.collection("bookings")
                        .document(bookingId)
                        .updateData(updates) { error in
                            if let error = error {
                                print("[BusinessViewModel] Error accepting booking: \(error.localizedDescription)")
                                self?.error = "Failed to accept booking"
                            } else {
                                print("[BusinessViewModel] Booking \(bookingId) accepted")
                            }
                        }
                } else {
                    print("[BusinessViewModel] Booking \(bookingId) accepted")
                }
            }
    }

    /// Reject a pending booking (sets status to REJECTED)
    func rejectBooking(bookingId: String) {
        guard let userId = auth.currentUser?.uid else { return }

        let updates: [String: Any] = [
            "status": BookingStatus.rejected.rawValue,
            "updatedAt": Int64(Date().timeIntervalSince1970 * 1000)
        ]

        db.collection("organizations")
            .document(userId)
            .collection("bookings")
            .document(bookingId)
            .updateData(updates) { [weak self] error in
                if let error = error {
                    print("[BusinessViewModel] Error rejecting booking in org path: \(error.localizedDescription)")
                    self?.db.collection("bookings")
                        .document(bookingId)
                        .updateData(updates) { error in
                            if let error = error {
                                print("[BusinessViewModel] Error rejecting booking: \(error.localizedDescription)")
                                self?.error = "Failed to reject booking"
                            } else {
                                print("[BusinessViewModel] Booking \(bookingId) rejected")
                            }
                        }
                } else {
                    print("[BusinessViewModel] Booking \(bookingId) rejected")
                }
            }
    }

    var timeUntilNextJob: String {
        guard let nextTime = nextJobTime else { return "No upcoming jobs" }

        let now = Date()
        if nextTime < now { return "Overdue" }

        let interval = nextTime.timeIntervalSince(now)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 24 {
            let days = hours / 24
            let remainingHours = hours % 24
            return "\(days)d \(remainingHours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    // MARK: - Client Stats

    var totalClients: Int { clients.count }

    var activePercentage: Double {
        guard !clients.isEmpty else { return 0.0 }
        let activeCount = clients.filter { $0.isActive }.count
        return Double(activeCount) / Double(clients.count) * 100.0
    }

    var averageLTV: Double {
        guard !clients.isEmpty else { return 0.0 }
        let total = clients.reduce(0.0) { $0 + $1.totalSpent }
        return total / Double(clients.count)
    }

    var churnRate: Double {
        guard !clients.isEmpty else { return 0.0 }
        let churned = clients.filter { !$0.isActive }.count
        return Double(churned) / Double(clients.count) * 100.0
    }

    // MARK: - Client Import

    func importClients(_ importClients: [ImportedClient], completion: @escaping (Int, Int) -> Void) {
        guard let userId = auth.currentUser?.uid else {
            error = "Not signed in"
            completion(0, importClients.count)
            return
        }

        let batch = db.batch()
        var successCount = 0

        for client in importClients where !client.isDuplicate {
            let docRef = db.collection("organizations")
                .document(userId)
                .collection("clients")
                .document()

            let data: [String: Any] = [
                "name": client.name,
                "email": client.email,
                "phone": client.phone,
                "dogs": client.dogs,
                "isActive": true,
                "lastBooking": "",
                "totalWalks": 0,
                "totalSpent": 0.0,
                "notes": client.notes,
                "createdAt": FieldValue.serverTimestamp(),
                "source": client.source
            ]
            batch.setData(data, forDocument: docRef)
            successCount += 1
        }

        batch.commit { [weak self] err in
            if let err = err {
                print("Error importing clients: \(err.localizedDescription)")
                self?.error = "Failed to import clients"
                completion(0, importClients.count)
            } else {
                completion(successCount, importClients.count)
            }
        }
    }

    // MARK: - Client Export

    func exportClientsCSV() -> URL? {
        var csv = "Name,Email,Phone,Dogs,Status,Total Walks,Total Spent,Last Booking\n"

        for client in clients {
            let dogsStr = client.dogs.joined(separator: "; ")
            let status = client.isActive ? "Active" : "Inactive"
            let spent = String(format: "%.2f", client.totalSpent)
            let row = "\(csvEscape(client.name)),\(csvEscape(client.email)),\(csvEscape(client.phone)),\(csvEscape(dogsStr)),\(status),\(client.totalWalks),\(spent),\(csvEscape(client.lastBooking))\n"
            csv += row
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("clients_export.csv")
        do {
            try csv.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            print("Failed to write CSV: \(error.localizedDescription)")
            self.error = "Failed to export clients"
            return nil
        }
    }

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    // MARK: - Private: Snapshot Listeners

    private func observeOnlineStatus(userId: String) {
        onlineStatusListener?.remove()
        onlineStatusListener = db.collection("organizations")
            .document(userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error = error {
                    print("Error observing online status: \(error.localizedDescription)")
                    return
                }
                guard let data = snapshot?.data() else { return }
                self.isOnline = data["isOnline"] as? Bool ?? false
            }
    }

    private func observeBookings(userId: String) {
        bookingsListener?.remove()

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart

        bookingsListener = db.collection("organizations")
            .document(userId)
            .collection("bookings")
            .whereField("scheduledDate", isGreaterThanOrEqualTo: Timestamp(date: todayStart))
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false

                if let error = error {
                    print("Error observing bookings: \(error.localizedDescription)")
                    self.error = "Failed to load bookings"
                    return
                }

                guard let documents = snapshot?.documents else {
                    self.upcomingJobs = []
                    self.todayJobCount = 0
                    self.completedJobCount = 0
                    return
                }

                var bookings: [BusinessBooking] = []
                var todayCount = 0
                var completedCount = 0

                for doc in documents {
                    let data = doc.data()
                    let clientName = data["clientName"] as? String ?? "Unknown"
                    let dogName = data["dogName"] as? String
                    let serviceType = data["serviceType"] as? String ?? "Service"
                    let status = data["status"] as? String ?? "PENDING"
                    let price = (data["price"] as? NSNumber)?.doubleValue ?? 0.0
                    let isPaid = data["isPaid"] as? Bool ?? false
                    let location = data["location"] as? String ?? ""
                    let specialInstructions = data["specialInstructions"] as? String

                    var scheduledDate = Date()
                    if let timestamp = data["scheduledDate"] as? Timestamp {
                        scheduledDate = timestamp.dateValue()
                    } else if let startMs = (data["startTime"] as? NSNumber)?.int64Value, startMs > 0 {
                        scheduledDate = Date(timeIntervalSince1970: TimeInterval(startMs) / 1000.0)
                    } else if let dateStr = data["scheduledDate"] as? String {
                        let formatter = ISO8601DateFormatter()
                        scheduledDate = formatter.date(from: dateStr) ?? Date()
                    }

                    var endDate: Date? = nil
                    if let endMs = (data["endTime"] as? NSNumber)?.int64Value, endMs > 0 {
                        endDate = Date(timeIntervalSince1970: TimeInterval(endMs) / 1000.0)
                    }

                    let booking = BusinessBooking(
                        id: doc.documentID,
                        clientName: clientName,
                        dogName: dogName,
                        serviceType: serviceType,
                        scheduledDate: scheduledDate,
                        endDate: endDate,
                        status: status,
                        price: price,
                        isPaid: isPaid,
                        location: location,
                        specialInstructions: specialInstructions
                    )

                    bookings.append(booking)

                    // Count today's bookings
                    if scheduledDate >= todayStart && scheduledDate < todayEnd {
                        todayCount += 1
                        if BookingStatus.from(rawValue: status) == .completed {
                            completedCount += 1
                        }
                    }
                }

                // Sort by date, upcoming first
                bookings.sort { $0.scheduledDate < $1.scheduledDate }

                // Store all bookings for schedule views
                self.allBookings = bookings

                let upcoming = bookings.filter {
                    let s = BookingStatus.from(rawValue: $0.status)
                    return (s == .confirmed || s == .pending) && $0.scheduledDate >= Date()
                }

                self.upcomingJobs = upcoming
                self.todayJobCount = todayCount
                self.completedJobCount = completedCount

                if let next = upcoming.first {
                    self.nextJobTime = next.scheduledDate
                    self.nextJobDetails = next.displayTitle + " — " + next.clientName
                } else {
                    self.nextJobTime = nil
                    self.nextJobDetails = nil
                }
            }
    }

    private func observeEarnings(userId: String) {
        earningsListener?.remove()

        let calendar = Calendar.current
        let today = Date()
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today
        let todayStart = calendar.startOfDay(for: today)
        let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart

        // Query earnings from month start
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let monthStartStr = formatter.string(from: monthStart)

        earningsListener = db.collection("organizations")
            .document(userId)
            .collection("earnings")
            .whereField("date", isGreaterThanOrEqualTo: monthStartStr)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error = error {
                    print("Error observing earnings: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    self.todayEarnings = 0.0
                    self.monthlyEarnings = 0.0
                    return
                }

                let todayStr = formatter.string(from: today)
                var dayTotal = 0.0
                var monthTotal = 0.0

                for doc in documents {
                    let data = doc.data()
                    let amount = data["netAmount"] as? Double ?? 0.0
                    let dateStr = data["date"] as? String ?? ""

                    monthTotal += amount
                    if dateStr == todayStr {
                        dayTotal += amount
                    }
                }

                self.todayEarnings = dayTotal
                self.monthlyEarnings = monthTotal
            }
    }

    private func observeClients(userId: String) {
        clientsListener?.remove()
        clientsListener = db.collection("organizations")
            .document(userId)
            .collection("clients")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error = error {
                    print("Error observing clients: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    self.clients = []
                    return
                }

                self.clients = documents.compactMap { doc in
                    let data = doc.data()
                    let name = data["name"] as? String ?? "Unknown"
                    let email = data["email"] as? String ?? ""
                    let phone = data["phone"] as? String ?? ""
                    let dogs = data["dogs"] as? [String] ?? []
                    let isActive = data["isActive"] as? Bool ?? true
                    let lastBooking = data["lastBooking"] as? String ?? ""
                    let totalWalks = data["totalWalks"] as? Int ?? 0
                    let totalSpent = data["totalSpent"] as? Double ?? 0.0
                    let notes = data["notes"] as? String ?? ""

                    return BusinessClient(
                        id: doc.documentID,
                        name: name,
                        email: email,
                        phone: phone,
                        dogs: dogs,
                        isActive: isActive,
                        lastBooking: lastBooking,
                        totalWalks: totalWalks,
                        totalSpent: totalSpent,
                        notes: notes
                    )
                }
            }
    }
}
