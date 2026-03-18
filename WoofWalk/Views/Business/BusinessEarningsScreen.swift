import SwiftUI

struct BusinessEarningsScreen: View {
    @State private var selectedPeriod: EarningsPeriod = .thisMonth

    private enum EarningsPeriod: String, CaseIterable {
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case lastMonth = "Last Month"
        case allTime = "All Time"
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

                // Revenue summary
                revenueSummary

                // Revenue chart placeholder
                revenueChart

                // Recent transactions
                recentTransactions

                // Payout info
                payoutInfo

                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("Earnings")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Revenue Summary

    private var revenueSummary: some View {
        HStack(spacing: 0) {
            earningsStat(title: "Revenue", value: periodRevenue, icon: "sterlingsign.circle.fill", color: .green)
            Divider().frame(height: 50)
            earningsStat(title: "Walks", value: periodWalks, icon: "figure.walk", color: .blue)
            Divider().frame(height: 50)
            earningsStat(title: "Avg/Walk", value: periodAvg, icon: "chart.line.uptrend.xyaxis", color: .orange)
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

            // Simple bar chart
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(chartData, id: \.label) { data in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.accentColor.opacity(0.8))
                            .frame(height: max(8, CGFloat(data.value) * 1.5))
                        Text(data.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 120)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Recent Transactions

    private var recentTransactions: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Transactions")
                    .font(.headline)
                Spacer()
                Text("See All")
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
            }

            ForEach(transactions) { tx in
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
                        Text(tx.date)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Text(tx.amount)
                        .font(.subheadline.bold())
                        .foregroundColor(tx.isIncome ? .green : .red)
                }
                if tx.id != transactions.last?.id {
                    Divider()
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

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("£187.50")
                        .font(.title2.bold())
                        .foregroundColor(.green)
                    Text("Estimated for March 25")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Bank Account")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("****4521")
                        .font(.caption.bold())
                        .monospaced()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Computed Properties

    private var periodRevenue: String {
        switch selectedPeriod {
        case .thisWeek: return "£97.50"
        case .thisMonth: return "£367.50"
        case .lastMonth: return "£420.00"
        case .allTime: return "£2,145.00"
        }
    }

    private var periodWalks: String {
        switch selectedPeriod {
        case .thisWeek: return "7"
        case .thisMonth: return "24"
        case .lastMonth: return "28"
        case .allTime: return "143"
        }
    }

    private var periodAvg: String {
        switch selectedPeriod {
        case .thisWeek: return "£13.93"
        case .thisMonth: return "£15.31"
        case .lastMonth: return "£15.00"
        case .allTime: return "£15.00"
        }
    }

    private var chartData: [ChartDataPoint] {
        [
            ChartDataPoint(label: "Mon", value: 30),
            ChartDataPoint(label: "Tue", value: 45),
            ChartDataPoint(label: "Wed", value: 15),
            ChartDataPoint(label: "Thu", value: 60),
            ChartDataPoint(label: "Fri", value: 45),
            ChartDataPoint(label: "Sat", value: 30),
            ChartDataPoint(label: "Sun", value: 0),
        ]
    }

    private var transactions: [EarningsTransaction] {
        [
            EarningsTransaction(id: "1", description: "Walk - Bella (Sarah)", amount: "+£15.00", date: "Today, 10:15 AM", icon: "figure.walk", isIncome: true),
            EarningsTransaction(id: "2", description: "Walk - Max (Tom)", amount: "+£15.00", date: "Today, 12:30 PM", icon: "figure.walk", isIncome: true),
            EarningsTransaction(id: "3", description: "Group walk - Luna & Daisy", amount: "+£22.50", date: "Yesterday", icon: "person.2.fill", isIncome: true),
            EarningsTransaction(id: "4", description: "Platform fee - March", amount: "-£18.75", date: "1 Mar", icon: "building.columns", isIncome: false),
            EarningsTransaction(id: "5", description: "Walk - Rocky (James)", amount: "+£15.00", date: "28 Feb", icon: "figure.walk", isIncome: true),
        ]
    }
}

// MARK: - Supporting Types

private struct ChartDataPoint {
    let label: String
    let value: Int
}

private struct EarningsTransaction: Identifiable {
    let id: String
    let description: String
    let amount: String
    let date: String
    let icon: String
    let isIncome: Bool
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
