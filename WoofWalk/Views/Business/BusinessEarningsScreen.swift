import SwiftUI
import Charts
import FirebaseAuth
import FirebaseFirestore

// MARK: - Earnings Data Models

struct EarningRecord: Identifiable {
    let id: String
    let date: String
    let description: String
    let grossAmount: Double
    let netAmount: Double
    let commission: Double
    let serviceType: String
    let clientName: String
    let timestamp: Date
    let isIncome: Bool

    var icon: String {
        switch serviceType.lowercased() {
        case "walk", "solo walk": return "figure.walk"
        case "group walk": return "person.2.fill"
        case "daycare": return "house.fill"
        case "boarding": return "moon.fill"
        case "fee", "platform fee": return "building.columns"
        default: return "sterlingsign.circle"
        }
    }

    var formattedAmount: String {
        let prefix = isIncome ? "+" : "-"
        return "\(prefix)\(CurrencyFormatter.shared.formatPrice(abs(netAmount)))"
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let calendar = Calendar.current
        let today = formatter.string(from: Date())
        let yesterday = formatter.string(from: calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date())

        if date == today {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "h:mm a"
            return "Today, \(timeFormatter.string(from: timestamp))"
        } else if date == yesterday {
            return "Yesterday"
        } else {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "d MMM"
            if let d = formatter.date(from: date) {
                return displayFormatter.string(from: d)
            }
            return date
        }
    }
}

struct DailyEarningPoint: Identifiable {
    let id = UUID()
    let date: Date
    let label: String
    let amount: Double
}

// MARK: - Earnings ViewModel

@MainActor
class EarningsViewModel: ObservableObject {
    @Published var earnings: [EarningRecord] = []
    @Published var isLoading: Bool = false
    @Published var error: String?

    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
    }

    func loadEarnings() {
        guard let userId = auth.currentUser?.uid else {
            error = "Not signed in"
            return
        }

        isLoading = true
        error = nil
        listener?.remove()

        listener = db.collection("organizations")
            .document(userId)
            .collection("earnings")
            .order(by: "date", descending: true)
            .limit(to: 500)
            .addSnapshotListener { [weak self] snapshot, err in
                guard let self else { return }
                self.isLoading = false

                if let err = err {
                    print("Error loading earnings: \(err.localizedDescription)")
                    self.error = "Failed to load earnings"
                    return
                }

                guard let documents = snapshot?.documents else {
                    self.earnings = []
                    return
                }

                self.earnings = documents.compactMap { doc in
                    let data = doc.data()
                    let dateStr = data["date"] as? String ?? ""
                    let description = data["description"] as? String ?? data["serviceType"] as? String ?? "Earning"
                    let grossAmount = data["grossAmount"] as? Double ?? data["amount"] as? Double ?? 0.0
                    let netAmount = data["netAmount"] as? Double ?? grossAmount
                    let commission = data["commission"] as? Double ?? 0.0
                    let serviceType = data["serviceType"] as? String ?? "walk"
                    let clientName = data["clientName"] as? String ?? ""
                    let isIncome = data["isIncome"] as? Bool ?? (netAmount >= 0)

                    var timestamp = Date()
                    if let ts = data["timestamp"] as? Timestamp {
                        timestamp = ts.dateValue()
                    } else {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd"
                        timestamp = formatter.date(from: dateStr) ?? Date()
                    }

                    return EarningRecord(
                        id: doc.documentID,
                        date: dateStr,
                        description: description,
                        grossAmount: grossAmount,
                        netAmount: netAmount,
                        commission: commission,
                        serviceType: serviceType,
                        clientName: clientName,
                        timestamp: timestamp,
                        isIncome: isIncome
                    )
                }
            }
    }
}

// MARK: - Earnings Period

private enum EarningsPeriod: String, CaseIterable {
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case lastMonth = "Last Month"
    case allTime = "All Time"

    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .thisWeek:
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            return (weekStart, now)
        case .thisMonth:
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            return (monthStart, now)
        case .lastMonth:
            let thisMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: thisMonthStart) ?? now
            return (lastMonthStart, thisMonthStart)
        case .allTime:
            let distantPast = calendar.date(byAdding: .year, value: -10, to: now) ?? now
            return (distantPast, now)
        }
    }
}

// MARK: - Business Earnings Screen

struct BusinessEarningsScreen: View {
    @StateObject private var earningsVM = EarningsViewModel()
    @State private var selectedPeriod: EarningsPeriod = .thisMonth

    private var filteredEarnings: [EarningRecord] {
        let range = selectedPeriod.dateRange
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let startStr = formatter.string(from: range.start)
        let endStr = formatter.string(from: range.end)

        return earningsVM.earnings.filter { earning in
            earning.date >= startStr && earning.date <= endStr
        }
    }

    private var totalRevenue: Double {
        filteredEarnings.filter { $0.isIncome }.reduce(0.0) { $0 + $1.netAmount }
    }

    private var totalWalks: Int {
        filteredEarnings.filter { $0.isIncome }.count
    }

    private var averagePerWalk: Double {
        guard totalWalks > 0 else { return 0 }
        return totalRevenue / Double(totalWalks)
    }

    private var dailyChartData: [DailyEarningPoint] {
        let incomeEarnings = filteredEarnings.filter { $0.isIncome }
        var dailyTotals: [String: Double] = [:]

        for earning in incomeEarnings {
            dailyTotals[earning.date, default: 0] += earning.netAmount
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dayFormatter = DateFormatter()

        switch selectedPeriod {
        case .thisWeek:
            dayFormatter.dateFormat = "EEE"
        case .thisMonth, .lastMonth:
            dayFormatter.dateFormat = "d"
        case .allTime:
            dayFormatter.dateFormat = "MMM yy"
        }

        return dailyTotals.compactMap { key, value in
            guard let date = formatter.date(from: key) else { return nil }
            return DailyEarningPoint(
                date: date,
                label: dayFormatter.string(from: date),
                amount: value
            )
        }
        .sorted { $0.date < $1.date }
    }

    private var recentTransactions: [EarningRecord] {
        Array(filteredEarnings.prefix(10))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Period selector
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(EarningsPeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if earningsVM.isLoading && earningsVM.earnings.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                } else {
                    // Revenue summary
                    revenueSummary

                    // Revenue chart
                    revenueChart

                    // Recent transactions
                    recentTransactionsSection

                    // Payout info
                    payoutInfo
                }

                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("Earnings")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    earningsVM.loadEarnings()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .onAppear {
            earningsVM.loadEarnings()
        }
    }

    // MARK: - Revenue Summary

    private var revenueSummary: some View {
        HStack(spacing: 0) {
            earningsStat(
                title: "Revenue",
                value: CurrencyFormatter.shared.formatPrice(totalRevenue),
                icon: "sterlingsign.circle.fill",
                color: .green
            )
            Divider().frame(height: 50)
            earningsStat(
                title: "Walks",
                value: "\(totalWalks)",
                icon: "figure.walk",
                color: .blue
            )
            Divider().frame(height: 50)
            earningsStat(
                title: "Avg/Walk",
                value: CurrencyFormatter.shared.formatPrice(averagePerWalk),
                icon: "chart.line.uptrend.xyaxis",
                color: .orange
            )
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private func earningsStat(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(value)
                .font(.title3.bold())
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Revenue Chart

    private var revenueChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Revenue Trend")
                .font(.headline)

            if dailyChartData.isEmpty {
                Text("No earnings data for this period")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                Chart(dailyChartData) { point in
                    BarMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Amount", point.amount)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: chartStride)) { value in
                        AxisValueLabel(format: chartDateFormat)
                        AxisGridLine()
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(CurrencyFormatter.shared.formatInteger(Int(amount)))
                                    .font(.caption2)
                            }
                        }
                        AxisGridLine()
                    }
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private var chartStride: Calendar.Component {
        switch selectedPeriod {
        case .thisWeek: return .day
        case .thisMonth: return .weekOfYear
        case .lastMonth: return .weekOfYear
        case .allTime: return .month
        }
    }

    private var chartDateFormat: Date.FormatStyle {
        switch selectedPeriod {
        case .thisWeek:
            return .dateTime.weekday(.abbreviated)
        case .thisMonth, .lastMonth:
            return .dateTime.day()
        case .allTime:
            return .dateTime.month(.abbreviated)
        }
    }

    // MARK: - Recent Transactions

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Transactions")
                    .font(.headline)
                Spacer()
                if filteredEarnings.count > 10 {
                    Text("\(filteredEarnings.count) total")
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                }
            }

            if recentTransactions.isEmpty {
                Text("No transactions in this period")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(recentTransactions) { tx in
                    HStack {
                        Image(systemName: tx.icon)
                            .foregroundColor(tx.isIncome ? .green : .red)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(tx.isIncome ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tx.description)
                                .font(.subheadline)
                            HStack(spacing: 4) {
                                if !tx.clientName.isEmpty {
                                    Text(tx.clientName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("--")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                Text(tx.formattedDate)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                        Text(tx.formattedAmount)
                            .font(.subheadline.bold())
                            .foregroundColor(tx.isIncome ? .green : .red)
                    }
                    if tx.id != recentTransactions.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Payout Info

    private var payoutInfo: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "banknote")
                    .foregroundColor(.green)
                Text("Next Payout")
                    .font(.headline)
                Spacer()
            }

            let pendingPayout = filteredEarnings
                .filter { $0.isIncome }
                .reduce(0.0) { $0 + $1.netAmount }
            let nextPayoutDate = nextPayoutDateString()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(CurrencyFormatter.shared.formatPrice(pendingPayout))
                        .font(.title2.bold())
                        .foregroundColor(.green)
                    Text("Estimated for \(nextPayoutDate)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("via Stripe")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: "creditcard.fill")
                        .foregroundColor(.accentColor)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private func nextPayoutDateString() -> String {
        let calendar = Calendar.current
        let now = Date()
        // Next payout is the 25th of current or next month
        var components = calendar.dateComponents([.year, .month], from: now)
        components.day = 25
        if let payoutDate = calendar.date(from: components), payoutDate > now {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d"
            return formatter.string(from: payoutDate)
        } else {
            components.month = (components.month ?? 1) + 1
            if let payoutDate = calendar.date(from: components) {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM d"
                return formatter.string(from: payoutDate)
            }
            return "next month"
        }
    }
}

// MARK: - Business Settings Screen

struct BusinessSettingsScreen: View {
    @State private var businessName: String = "Pawsome Walks"
    @State private var serviceRadius: Double = 5.0
    @State private var basePrice: String = "15.00"
    @State private var groupDiscount: String = "25"
    @State private var maxDogsPerWalk: Int = 4
    @State private var isAcceptingBookings: Bool = true
    @State private var autoConfirmBookings: Bool = false
    @State private var showCancellationPolicy: Bool = false

    var body: some View {
        Form {
            // Business Profile
            Section("Business Profile") {
                HStack {
                    Image(systemName: "building.2.fill")
                        .foregroundColor(.accentColor)
                        .frame(width: 28)
                    TextField("Business Name", text: $businessName)
                }
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.red)
                        .frame(width: 28)
                    VStack(alignment: .leading) {
                        Text("Service Radius")
                        Text("\(String(format: "%.0f", serviceRadius)) km")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Slider(value: $serviceRadius, in: 1...20, step: 1)
                        .frame(width: 120)
                }
            }

            // Pricing
            Section("Pricing") {
                HStack {
                    Image(systemName: "sterlingsign.circle")
                        .foregroundColor(.green)
                        .frame(width: 28)
                    Text("Base Price (per walk)")
                    Spacer()
                    TextField("Price", text: $basePrice)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
                HStack {
                    Image(systemName: "person.2")
                        .foregroundColor(.blue)
                        .frame(width: 28)
                    Text("Group Discount")
                    Spacer()
                    TextField("Discount", text: $groupDiscount)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                    Text("%")
                        .foregroundStyle(.secondary)
                }
                Stepper(value: $maxDogsPerWalk, in: 1...8) {
                    HStack {
                        Image(systemName: "pawprint.fill")
                            .foregroundColor(.orange)
                            .frame(width: 28)
                        Text("Max Dogs Per Walk")
                        Spacer()
                        Text("\(maxDogsPerWalk)")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Availability
            Section("Availability") {
                Toggle(isOn: $isAcceptingBookings) {
                    HStack {
                        Image(systemName: "calendar.badge.checkmark")
                            .foregroundColor(.green)
                            .frame(width: 28)
                        Text("Accepting Bookings")
                    }
                }
                Toggle(isOn: $autoConfirmBookings) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .frame(width: 28)
                        Text("Auto-Confirm Bookings")
                    }
                }
            }

            // Working Hours
            Section("Working Hours") {
                workingHoursRow(day: "Monday", hours: "8:00 AM - 5:00 PM")
                workingHoursRow(day: "Tuesday", hours: "8:00 AM - 5:00 PM")
                workingHoursRow(day: "Wednesday", hours: "8:00 AM - 5:00 PM")
                workingHoursRow(day: "Thursday", hours: "8:00 AM - 5:00 PM")
                workingHoursRow(day: "Friday", hours: "8:00 AM - 3:00 PM")
                workingHoursRow(day: "Saturday", hours: "9:00 AM - 1:00 PM")
                workingHoursRow(day: "Sunday", hours: "Closed")
            }

            // Policies
            Section("Policies") {
                Button {
                    showCancellationPolicy = true
                } label: {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.accentColor)
                            .frame(width: 28)
                        Text("Cancellation Policy")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .navigationTitle("Business Settings")
        .navigationBarTitleDisplayMode(.large)
        .alert("Cancellation Policy", isPresented: $showCancellationPolicy) {
            Button("OK") { }
        } message: {
            Text("24-hour cancellation policy. Clients who cancel within 24 hours will be charged 50% of the booking fee.")
        }
    }

    private func workingHoursRow(day: String, hours: String) -> some View {
        HStack {
            Text(day)
                .frame(width: 90, alignment: .leading)
            Spacer()
            Text(hours)
                .foregroundStyle(hours == "Closed" ? .secondary : .primary)
                .font(.subheadline)
        }
    }
}
