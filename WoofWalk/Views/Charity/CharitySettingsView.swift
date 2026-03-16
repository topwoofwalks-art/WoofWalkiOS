import SwiftUI

struct CharitySettingsView: View {
    @StateObject private var viewModel = CharitySettingsViewModel()
    @State private var showCharityPicker = false

    var body: some View {
        Form {
            Section {
                Toggle("Donate Walk Points to Charity", isOn: $viewModel.charityEnabled)
                    .tint(.turquoise60)
            } footer: {
                Text("When enabled, 25% of your walk points will be donated to your chosen charity.")
            }

            if viewModel.charityEnabled {
                Section("Selected Charity") {
                    Button(action: { showCharityPicker = true }) {
                        HStack(spacing: 12) {
                            if let charity = viewModel.selectedCharity {
                                Text(charity.logoEmoji)
                                    .font(.title2)
                                VStack(alignment: .leading) {
                                    Text(charity.name)
                                        .foregroundColor(.primary)
                                    Text(charity.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Text("Choose a charity")
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("Your Impact") {
                    HStack {
                        Text("This Walk")
                        Spacer()
                        Text("\(viewModel.lastWalkPoints) pts")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("This Month")
                        Spacer()
                        Text("\(viewModel.monthlyPoints) pts")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Lifetime")
                        Spacer()
                        Text(FormatUtils.formatPoints(Int(viewModel.lifetimePoints)))
                            .fontWeight(.bold)
                            .foregroundColor(.turquoise60)
                    }
                }
            }
        }
        .navigationTitle("Charity Walks")
        .sheet(isPresented: $showCharityPicker) {
            CharityPickerSheet(selectedCharityId: $viewModel.selectedCharityId)
        }
    }
}

@MainActor
class CharitySettingsViewModel: ObservableObject {
    @Published var charityEnabled = false
    @Published var selectedCharityId = "dogs_trust"
    @Published var lastWalkPoints: Int64 = 0
    @Published var monthlyPoints: Int64 = 0
    @Published var lifetimePoints: Int64 = 0

    private let repository = CharityRepository()

    var selectedCharity: CharityOrg? {
        CharityOrg.supportedCharities.first { $0.id == selectedCharityId }
    }

    init() {
        loadProfile()
    }

    func loadProfile() {
        Task {
            if let profile = try? await repository.getCharityProfile() {
                charityEnabled = profile.enabled
                selectedCharityId = profile.selectedCharityId
                lastWalkPoints = profile.lastWalkCharityPoints
                monthlyPoints = profile.monthlyPoints
                lifetimePoints = profile.lifetimePoints
            }
        }
    }
}
