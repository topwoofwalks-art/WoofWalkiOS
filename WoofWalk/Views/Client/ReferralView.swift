import SwiftUI
import FirebaseFirestore
import FirebaseFunctions

// MARK: - View Model

@MainActor
class ReferralViewModel: ObservableObject {
    @Published var code: String?
    @Published var usedCount: Int = 0
    @Published var maxUses: Int = 10
    @Published var loading = true
    @Published var error: String?

    private let db = Firestore.firestore()
    private lazy var functions = Functions.functions(region: "europe-west2")

    func loadOrGenerate(orgId: String, userId: String) {
        loading = true
        error = nil

        db.collection("referral_codes")
            .whereField("userId", isEqualTo: userId)
            .whereField("orgId", isEqualTo: orgId)
            .limit(to: 1)
            .getDocuments { [weak self] snap, err in
                guard let self = self else { return }
                Task { @MainActor in
                    if let doc = snap?.documents.first {
                        self.code = doc.documentID
                        self.usedCount = doc.data()["usedCount"] as? Int ?? 0
                        self.maxUses = doc.data()["maxUses"] as? Int ?? 10
                        self.loading = false
                    } else {
                        self.generate(orgId: orgId)
                    }
                }
            }
    }

    private func generate(orgId: String) {
        functions.httpsCallable("generateReferralCode").call(["orgId": orgId]) { [weak self] result, error in
            guard let self = self else { return }
            Task { @MainActor in
                if let error = error {
                    self.error = error.localizedDescription
                    self.loading = false
                    return
                }
                if let data = result?.data as? [String: Any] {
                    self.code = data["code"] as? String
                    self.usedCount = data["usedCount"] as? Int ?? 0
                    self.maxUses = data["maxUses"] as? Int ?? 10
                }
                self.loading = false
            }
        }
    }
}

// MARK: - Referral View

struct ReferralView: View {
    let orgId: String
    let userId: String

    @StateObject private var vm = ReferralViewModel()

    var body: some View {
        Group {
            if vm.loading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = vm.error {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.red.opacity(0.6))
                    Text("Something went wrong")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        heroSection
                        codeCard
                        statsRow
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
                }
            }
        }
        .navigationTitle("Refer a Friend")
        .onAppear { vm.loadOrGenerate(orgId: orgId, userId: userId) }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "gift.fill")
                .font(.system(size: 44))
                .foregroundColor(.accentColor)
                .frame(width: 80, height: 80)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(Circle())

            Text("Share the love!")
                .font(.title2.bold())

            Text("Give your friends a discount on their first booking and earn rewards when they sign up.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }

    // MARK: - Code Card

    private var codeCard: some View {
        VStack(spacing: 16) {
            Text("Your referral code")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(vm.code ?? "------")
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .tracking(6)

            HStack(spacing: 12) {
                Button {
                    if let code = vm.code {
                        UIPasteboard.general.string = code
                    }
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.subheadline.bold())
                }
                .buttonStyle(.bordered)

                ShareLink(
                    item: "Join me on WoofWalk! Use my referral code \(vm.code ?? "") to get a discount on your first booking. https://woofwalk.app/refer/\(vm.code ?? "")"
                ) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.subheadline.bold())
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(icon: "person.2.fill", value: "\(vm.usedCount)", label: "Friends joined")
            statCard(icon: "gift.fill", value: "\(vm.maxUses - vm.usedCount)", label: "Uses remaining")
        }
    }

    private func statCard(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
            Text(value)
                .font(.title.bold())
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
