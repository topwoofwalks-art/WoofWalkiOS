import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

/// Business-side charity donation settings — parity with the web
/// portal CharityTab (`portal/src/features/settings/components/CharityTab.tsx`).
/// Distinct from `Views/Charity/CharitySettingsView` which is the
/// user-side walk-points donation feature; this is the booking-fee
/// percentage routed through Stripe Connect at completion time.
///
/// Wires to:
///   - `/charities` collection — read-only, only ACTIVE rows are
///     selectable. While the list is empty (we're still onboarding
///     the first partner) the view shows a "Coming soon" banner and
///     locks the toggle off.
///   - `/organization_charity_settings/{orgId}` — written by the
///     toggle / picker / percentage. The
///     `postBookingCharityDonation` Cloud Function reads this on
///     each completed booking and posts the Stripe Transfer.
struct BusinessCharityDonationView: View {
    let orgId: String

    @StateObject private var vm = BusinessCharityDonationViewModel()

    var body: some View {
        Form {
            if vm.charitiesLoading {
                Section {
                    HStack {
                        ProgressView()
                        Text("Loading charity partners…")
                            .foregroundColor(.secondary)
                    }
                }
            } else if vm.charities.isEmpty {
                comingSoonSection
            }

            toggleSection

            if vm.settings.enabled && !vm.charities.isEmpty {
                percentageSection
                charityPickerSection
                impactSection
                taxSection
            }
        }
        .navigationTitle("Charity Donations")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            vm.start(orgId: orgId)
        }
        .onDisappear { vm.stop() }
    }

    // MARK: - Sections

    private var comingSoonSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.orange)
                    Text("Charity partnerships — coming soon")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                Text("We're onboarding registered UK animal welfare charities. The donation feature goes live the moment our first partner completes Stripe onboarding — no app update needed.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("Want a charity you support included? Drop us a note and we'll reach out to them.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private var toggleSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { vm.settings.enabled },
                set: { vm.setEnabled($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Donate to charity")
                        .font(.headline)
                    Text("Auto-donate a percentage of each completed booking")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .disabled(vm.charities.isEmpty || vm.busy)
        }
    }

    private var percentageSection: some View {
        Section("Donation percentage") {
            HStack(spacing: 10) {
                ForEach([5, 10, 15, 20], id: \.self) { pct in
                    Button {
                        vm.setPercentage(pct)
                    } label: {
                        Text("\(pct)%")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                vm.settings.donationPercentage == pct
                                    ? Color.green
                                    : Color(.secondarySystemBackground)
                            )
                            .foregroundColor(
                                vm.settings.donationPercentage == pct ? .white : .primary
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.busy)
                }
            }
            Text("\(vm.settings.donationPercentage)% of each completed booking will go to your chosen charity, deducted from your earnings.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var charityPickerSection: some View {
        Section("Charity") {
            ForEach(vm.charities) { charity in
                Button {
                    vm.setSelectedCharity(charity.id)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.green)
                            .frame(width: 32, height: 32)
                            .background(Color.green.opacity(0.15))
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(charity.name)
                                .foregroundColor(.primary)
                                .font(.subheadline.bold())
                            if !charity.description.isEmpty {
                                Text(charity.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        Spacer()
                        if vm.settings.selectedCharityId == charity.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(vm.busy)
            }
        }
    }

    private var impactSection: some View {
        Section("Your impact") {
            HStack {
                Text("Total donated")
                Spacer()
                Text(vm.formattedTotalDonated)
                    .foregroundColor(.secondary)
                    .font(.system(.body, design: .monospaced))
            }
            if let charity = vm.charities.first(where: { $0.id == vm.settings.selectedCharityId }) {
                HStack {
                    Text("Receiving charity")
                    Spacer()
                    Text(charity.name)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var taxSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Tax")
                        .font(.headline)
                }
                Text("Limited companies: deductible from taxable profits before corporation tax.\n\nSole traders: charity claims Gift Aid on top; higher-rate taxpayers claim relief via Self Assessment.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - View model

@MainActor
final class BusinessCharityDonationViewModel: ObservableObject {

    struct OrgCharitySettings {
        var enabled: Bool = false
        var donationPercentage: Int = 10
        var selectedCharityId: String? = nil
        var totalDonatedMinor: Int64 = 0
    }

    struct CharityPartner: Identifiable, Hashable {
        let id: String
        let name: String
        let description: String
    }

    @Published var settings = OrgCharitySettings()
    @Published var charities: [CharityPartner] = []
    @Published var charitiesLoading: Bool = true
    @Published var busy: Bool = false

    private let db = Firestore.firestore()
    private var orgId: String = ""
    private var charitiesListener: ListenerRegistration?
    private var settingsListener: ListenerRegistration?

    var formattedTotalDonated: String {
        let pounds = Double(settings.totalDonatedMinor) / 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GBP"
        formatter.locale = Locale(identifier: "en_GB")
        return formatter.string(from: NSNumber(value: pounds)) ?? "£0.00"
    }

    func start(orgId: String) {
        guard self.orgId != orgId else { return }
        self.orgId = orgId
        observeCharities()
        observeSettings()
    }

    func stop() {
        charitiesListener?.remove()
        settingsListener?.remove()
        charitiesListener = nil
        settingsListener = nil
    }

    private func observeCharities() {
        charitiesLoading = true
        charitiesListener = db.collection("charities")
            .whereField("status", isEqualTo: "ACTIVE")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                let docs = snapshot?.documents ?? []
                self.charities = docs.map { doc in
                    let data = doc.data()
                    return CharityPartner(
                        id: doc.documentID,
                        name: data["name"] as? String ?? "Charity",
                        description: data["description"] as? String ?? ""
                    )
                }
                self.charitiesLoading = false
            }
    }

    private func observeSettings() {
        settingsListener = db.collection("organization_charity_settings")
            .document(orgId)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let data = snapshot?.data() else { return }
                self.settings = OrgCharitySettings(
                    enabled: data["enabled"] as? Bool ?? false,
                    donationPercentage: data["donationPercentage"] as? Int ?? 10,
                    selectedCharityId: data["selectedCharityId"] as? String,
                    totalDonatedMinor: data["totalDonatedMinor"] as? Int64 ?? 0
                )
            }
    }

    // MARK: - Mutations

    func setEnabled(_ on: Bool) {
        settings.enabled = on
        save()
    }

    func setPercentage(_ pct: Int) {
        settings.donationPercentage = max(1, min(50, pct))
        save()
    }

    func setSelectedCharity(_ id: String) {
        settings.selectedCharityId = id
        save()
    }

    private func save() {
        guard !orgId.isEmpty else { return }
        busy = true
        let payload: [String: Any] = [
            "enabled": settings.enabled,
            "donationPercentage": settings.donationPercentage,
            "selectedCharityId": settings.selectedCharityId as Any,
            "lastUpdated": FieldValue.serverTimestamp(),
        ]
        db.collection("organization_charity_settings").document(orgId)
            .setData(payload, merge: true) { [weak self] _ in
                Task { @MainActor in self?.busy = false }
            }
    }
}
