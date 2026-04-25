import SwiftUI

/// Service catalogue editor — lists every `service_listings` doc owned by
/// the current org and lets the business owner toggle each on/off and tap
/// in for pricing edits. Mirrors Android's `ServicesTab` in
/// `ServiceSettingsScreen.kt`.
struct ServiceSettingsView: View {
    @StateObject private var viewModel: ServiceSettingsViewModel

    init(orgId: String? = nil) {
        if let orgId, !orgId.isEmpty {
            _viewModel = StateObject(wrappedValue: ServiceSettingsViewModel(orgId: orgId))
        } else {
            _viewModel = StateObject(wrappedValue: ServiceSettingsViewModel())
        }
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.services.isEmpty {
                ProgressView("Loading services...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.services.isEmpty {
                emptyState
            } else {
                List {
                    Section {
                        Text("Toggle services on or off and tap to set pricing. Sub-configs (durations, room types, grooming menu) keep their wizard values.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Section {
                        ForEach($viewModel.services) { $service in
                            ServiceRow(service: $service, viewModel: viewModel)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Services")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .alert(
            "Error",
            isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.clearError() } }
            )
        ) {
            Button("OK") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "briefcase")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No services configured")
                .font(.title3.bold())
            Text("Complete the business onboarding wizard on woofwalk.app to add service types.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Service Row

private struct ServiceRow: View {
    @Binding var service: ServicePricingItem
    let viewModel: ServiceSettingsViewModel

    var body: some View {
        // Toggle and the rest-of-row tap target are kept separate so the
        // toggle does not also fire a navigation push.
        HStack(spacing: 12) {
            NavigationLink {
                ServicePricingView(service: $service, viewModel: viewModel)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: BookingServiceType.from(rawValue: service.serviceType).icon)
                        .font(.title3)
                        .foregroundStyle(service.enabled ? Color.turquoise60 : Color.secondary)
                        .frame(width: 36, height: 36)
                        .background(
                            (service.enabled ? Color.turquoise60 : Color.secondary)
                                .opacity(0.12)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(service.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(CurrencyFormatter.shared.formatPrice(service.basePrice))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)

            Toggle("", isOn: Binding(
                get: { service.enabled },
                set: { newValue in
                    Task { await viewModel.toggle(service, enabled: newValue) }
                }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ServiceSettingsView(orgId: "preview-org")
    }
}
