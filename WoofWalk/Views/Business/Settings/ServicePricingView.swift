import SwiftUI

/// Per-service pricing editor. Mirrors Android's `ServicePricingDialog`
/// inside `ServiceSettingsScreen.kt`. Saves a sparse update against the
/// underlying `service_listings` doc — the wizard's nested sub-configs
/// (walkConfig, groomingConfig, …) are never overwritten.
struct ServicePricingView: View {
    @Binding var service: ServicePricingItem
    let viewModel: ServiceSettingsViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var basePriceText: String = ""
    @State private var perDogText: String = ""
    @State private var isSaving: Bool = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: BookingServiceType.from(rawValue: service.serviceType).icon)
                        .foregroundStyle(Color.turquoise60)
                        .frame(width: 28)
                    Text(service.displayName)
                        .font(.headline)
                }
                Toggle("Active", isOn: Binding(
                    get: { service.enabled },
                    set: { newValue in
                        Task { await viewModel.toggle(service, enabled: newValue) }
                    }
                ))
            } header: {
                Text("Service")
            } footer: {
                if !service.description.isEmpty {
                    Text(service.description)
                }
            }

            Section("Pricing") {
                HStack {
                    Text("Base price")
                    Spacer()
                    Text(CurrencyFormatter.shared.symbol())
                        .foregroundStyle(.secondary)
                    TextField("0.00", text: $basePriceText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)
                }
                HStack {
                    Text("Per additional dog")
                    Spacer()
                    Text(CurrencyFormatter.shared.symbol())
                        .foregroundStyle(.secondary)
                    TextField("0.00", text: $perDogText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)
                }
            }

            Section {
                LabeledContent("Default duration") {
                    Text("\(service.duration) min")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Max dogs") {
                    Text("\(service.maxDogs)")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Defaults")
            } footer: {
                Text("Walk durations, grooming menu, room types, and other rich options are managed in the onboarding wizard on woofwalk.app.")
            }
        }
        .navigationTitle(service.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                }
                .disabled(!hasChanges || isSaving)
            }
        }
        .onAppear { resetTextFields() }
    }

    // MARK: Helpers

    private var basePriceValue: Double {
        Double(basePriceText.replacingOccurrences(of: ",", with: "."))
            ?? service.basePrice
    }

    private var perDogValue: Double {
        Double(perDogText.replacingOccurrences(of: ",", with: "."))
            ?? service.pricePerAdditionalDog
    }

    private var hasChanges: Bool {
        basePriceValue != service.basePrice || perDogValue != service.pricePerAdditionalDog
    }

    private func resetTextFields() {
        basePriceText = String(format: "%.2f", service.basePrice)
        perDogText = String(format: "%.2f", service.pricePerAdditionalDog)
    }

    private func save() {
        let base = basePriceValue
        let perDog = perDogValue
        isSaving = true
        Task {
            await viewModel.updatePricing(
                service,
                basePrice: base,
                pricePerAdditionalDog: perDog
            )
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        }
    }
}

#Preview {
    NavigationStack {
        ServicePricingView(
            service: .constant(
                ServicePricingItem(
                    listingId: "preview",
                    serviceType: "WALK",
                    displayName: "Walk",
                    description: "Standard 60 minute dog walk.",
                    enabled: true,
                    basePrice: 15,
                    pricePerAdditionalDog: 5,
                    duration: 60,
                    maxDogs: 4
                )
            ),
            viewModel: ServiceSettingsViewModel(orgId: "preview-org")
        )
    }
}
