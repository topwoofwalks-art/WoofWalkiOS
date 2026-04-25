import SwiftUI
import FirebaseAuth

struct BusinessHomeScreen: View {
    // MARK: - ViewModel
    @ObservedObject var viewModel: BusinessViewModel

    // MARK: - Constants
    private let tealAccent = Color(red: 0.6, green: 0.9, blue: 0.9)
    private let darkTeal = Color.turquoise30
    private let cardBackground = Color.neutral20
    private let surfaceBackground = Color.neutral10

    // MARK: - Cash-shortage inbox state
    @State private var cashRequests: [CashTopupRequest] = []
    @State private var isLoadingCashRequests = false
    private let cashRepo = CashTopupRepository()

    /// Route to walk console for the next upcoming job, if available.
    private var nextJobWalkConsoleRoute: AppRoute? {
        guard let nextJob = viewModel.upcomingJobs.first else { return nil }
        return .businessWalkConsole(bookingId: nextJob.id)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 16) {
                    managementToolsBanner
                    onlineStatusCard
                    if !cashRequests.isEmpty {
                        cashRequestsCard
                    }
                    jobsCard
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .background(surfaceBackground.ignoresSafeArea())
            .refreshable {
                viewModel.refresh()
                await loadCashRequests()
            }
            .task {
                await loadCashRequests()
            }

            quickActionsBar
        }
        .navigationTitle("Business")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(value: AppRoute.businessSettings) {
                    Image(systemName: "gearshape")
                }
            }
        }
    }

    // MARK: - Management Tools Banner

    private var managementToolsBanner: some View {
        Button(action: {
            if let url = URL(string: "https://woofwalk.app") {
                UIApplication.shared.open(url)
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: "key.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(tealAccent.opacity(0.3)))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Full Management Tools")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Reports, scheduling & billing on woofwalk.app")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                Text("Open")
                    .font(.subheadline.bold())
                    .foregroundColor(darkTeal)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(.white))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [darkTeal, Color.turquoise40],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Online Status Card

    private var onlineStatusCard: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.isOnline ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                Text(viewModel.isOnline ? "Online" : "Offline")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            Spacer()

            Text("Today: \(viewModel.todayEarnings, format: .currency(code: "GBP"))")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))

            Toggle("", isOn: Binding(
                get: { viewModel.isOnline },
                set: { _ in viewModel.toggleOnlineStatus() }
            ))
            .labelsHidden()
            .tint(tealAccent)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
        )
    }

    // MARK: - Cash booking requests inbox

    /// Compact inbox card surfaced on the business home when there are
    /// pending cash-shortage requests for this org. Tapping a row pushes
    /// `CashTopupReplyView` via `.businessCashRequest`. Empty state renders
    /// nothing (the card is conditionally added in `body`).
    private var cashRequestsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "banknote")
                    .foregroundColor(tealAccent)
                Text("Cash booking requests")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(cashRequests.count)")
                    .font(.caption.bold())
                    .foregroundColor(Color.neutral10)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(tealAccent))
            }

            VStack(spacing: 8) {
                ForEach(cashRequests) { req in
                    NavigationLink(value: AppRoute.businessCashRequest(requestId: req.id)) {
                        cashRequestRow(req)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
        )
    }

    private func cashRequestRow(_ req: CashTopupRequest) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(tealAccent.opacity(0.25))
                    .frame(width: 36, height: 36)
                Image(systemName: "person.fill")
                    .font(.subheadline)
                    .foregroundColor(tealAccent)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(req.clientName.isEmpty ? "A WoofWalk client" : req.clientName)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Spacer()
                    Text(req.requestedAt, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
                if let preview = req.messages.last?.text, !preview.isEmpty {
                    Text(preview)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 6)
    }

    /// Server-side list of pending requests for this business. We use the
    /// callable rather than a direct collection-group query because the
    /// list rule requires `auth.token.organizationId` which not every
    /// business user has set; the callable verifies membership server-side.
    @MainActor
    private func loadCashRequests() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            cashRequests = []
            return
        }
        isLoadingCashRequests = true
        defer { isLoadingCashRequests = false }
        do {
            // Convention across the iOS codebase (see BusinessViewModel
            // online-status writes): the organization doc id is the
            // owner's Firebase Auth uid.
            let requests = try await cashRepo.listOrgCashTopupRequests(
                orgId: userId,
                status: "pending",
                limit: 5
            )
            self.cashRequests = requests
        } catch {
            // Permission-denied is expected when the user is logged in
            // but isn't claimed as an org member yet (fresh signup).
            // Don't surface — empty inbox is the correct render.
            print("[BusinessHomeScreen] cash topup inbox load failed: \(error.localizedDescription)")
            self.cashRequests = []
        }
    }

    // MARK: - Jobs Card

    private var jobsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text(viewModel.upcomingJobs.isEmpty ? "No Upcoming Jobs" : "\(viewModel.upcomingJobs.count) Upcoming Job\(viewModel.upcomingJobs.count == 1 ? "" : "s")")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(tealAccent)
                        .font(.subheadline)
                    Text("\(viewModel.todayJobCount) today")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            if viewModel.upcomingJobs.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.3))
                    Text("No upcoming jobs")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                // Upcoming jobs list
                VStack(spacing: 8) {
                    ForEach(viewModel.upcomingJobs.prefix(3)) { job in
                        HStack(spacing: 12) {
                            Image(systemName: "figure.walk")
                                .foregroundColor(tealAccent)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(job.displayTitle)
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Text(job.clientName)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }

                            Spacer()

                            Text(job.scheduledDate, style: .time)
                                .font(.caption.bold())
                                .foregroundColor(tealAccent)
                        }
                        .padding(.vertical, 6)
                    }
                }

                if let nextDetails = viewModel.nextJobDetails {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(tealAccent)
                        Text("Next: \(viewModel.timeUntilNextJob)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }

            // Action buttons
            VStack(spacing: 10) {
                if let route = nextJobWalkConsoleRoute {
                    NavigationLink(value: route) {
                        HStack(spacing: 8) {
                            Image(systemName: "figure.walk")
                                .font(.body)
                            Text("Start Now")
                                .font(.body.bold())
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(darkTeal)
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: {}) {
                        HStack(spacing: 8) {
                            Image(systemName: "figure.walk")
                                .font(.body)
                            Text("Start Now")
                                .font(.body.bold())
                        }
                        .foregroundColor(.white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(darkTeal.opacity(0.4))
                        )
                    }
                    .disabled(true)
                }

                Button(action: {
                    // Schedule action
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.body)
                        Text("Schedule")
                            .font(.body.bold())
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
        )
    }

    // MARK: - Quick Actions Bar

    private var quickActionsBar: some View {
        HStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    if let route = nextJobWalkConsoleRoute {
                        NavigationLink(value: route) {
                            HStack(spacing: 6) {
                                Image(systemName: "figure.walk")
                                    .font(.subheadline)
                                Text("Start Walk")
                                    .font(.subheadline.bold())
                                    .lineLimit(1)
                            }
                            .foregroundColor(Color.neutral10)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(tealAccent)
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        QuickActionChip(
                            title: "Start Walk",
                            icon: "figure.walk",
                            background: tealAccent.opacity(0.4),
                            foreground: Color.neutral10.opacity(0.5)
                        ) {}
                    }

                    QuickActionChip(
                        title: "Bookings",
                        icon: "calendar",
                        background: cardBackground,
                        foreground: .white
                    ) {
                        // Open bookings
                    }

                    NavigationLink(value: AppRoute.scanKey) {
                        HStack(spacing: 6) {
                            Image(systemName: "key.fill")
                                .font(.subheadline)
                            Text("Scan Key")
                                .font(.subheadline.bold())
                                .lineLimit(1)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(cardBackground)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Button(action: {
                // Add new action
            }) {
                Image(systemName: "plus")
                    .font(.title3.bold())
                    .foregroundColor(Color.neutral10)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(tealAccent))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(surfaceBackground)
                .shadow(color: .black.opacity(0.3), radius: 8, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - Quick Action Chip

private struct QuickActionChip: View {
    let title: String
    let icon: String
    let background: Color
    let foreground: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.subheadline)
                Text(title)
                    .font(.subheadline.bold())
                    .lineLimit(1)
            }
            .foregroundColor(foreground)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(background)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BusinessHomeScreen(viewModel: BusinessViewModel())
    }
    .preferredColorScheme(.dark)
}
