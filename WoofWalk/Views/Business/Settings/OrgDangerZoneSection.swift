import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

/// OrgDangerZoneSection — owner-only delete + unclaim controls.
///
/// Mirror of the portal's `OrgDangerZone.tsx`. Two distinct CFs:
///
///   * `deleteOrganization` — full cascade. Removes the org, services,
///     listings, members, custom claims; soft-flags bookings/invoices/
///     payouts so financial history stays queryable.
///   * `unclaimBusiness` — ONLY available when the org was created
///     from a scrape (i.e. `claimedFromBusinessId` is set). Reverts to
///     the unclaimed pool, lets the rightful owner re-claim. CF
///     refuses if there are active bookings.
///
/// Type-name confirmation gate: a `TextField` that must equal the
/// business name (case-insensitive, trimmed) before the destructive
/// button activates.
///
/// Optional `restoreUnclaimed` checkbox for the delete action when
/// `claimedFromBusinessId` is set; passes through to the CF so the
/// public listing returns to the discovery pool.
///
/// On success: sign the user out and pop to root so stale Firestore
/// listeners don't generate permission-denied noise.
struct OrgDangerZoneSection: View {
    /// Slot this Section into a parent Form. Caller passes the org id +
    /// name + claim status (claim status is `claimedFromBusinessId`
    /// being non-nil on the org doc — same convention as the portal's
    /// `OrganizationTab.tsx` line 344).
    let orgId: String
    let orgName: String
    let isClaim: Bool

    @StateObject private var navigator = AppNavigator.shared
    @State private var activeAction: ActiveAction?
    @State private var confirmText: String = ""
    @State private var restoreUnclaimed: Bool = false
    @State private var submitting: Bool = false
    @State private var errorMessage: String?

    private let functions = Functions.functions(region: "europe-west2")

    enum ActiveAction { case delete, unclaim }

    private var canConfirm: Bool {
        let expected = orgName.trimmingCharacters(in: .whitespaces)
        let typed = confirmText.trimmingCharacters(in: .whitespaces)
        return !expected.isEmpty &&
               typed.lowercased() == expected.lowercased()
    }

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.error60)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Danger Zone")
                            .font(.headline)
                            .foregroundColor(.error80)
                        Text("These actions are irreversible. Settle active bookings before deleting.")
                            .font(.caption)
                            .foregroundColor(.neutral70)
                    }
                }

                if isClaim {
                    actionButton(
                        title: "Unclaim this business",
                        subtitle: "Revert to public listing. The rightful owner can re-claim it.",
                        icon: "arrow.uturn.left",
                        tint: Color(hex: 0xFFB74D),
                        action: .unclaim
                    )
                }

                actionButton(
                    title: "Delete this business permanently",
                    subtitle: "Removes the organisation, services, and team. Bookings and invoices stay archived.",
                    icon: "trash",
                    tint: .error60,
                    action: .delete
                )

                if let active = activeAction {
                    confirmationGate(active)
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Owner controls")
        }
        .listRowBackground(Color.neutral20)
    }

    // MARK: - Sub-views

    private func actionButton(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        action: ActiveAction
    ) -> some View {
        Button {
            // Toggle: tapping the same button again hides the gate.
            if activeAction == action {
                activeAction = nil
                confirmText = ""
                errorMessage = nil
            } else {
                activeAction = action
                confirmText = ""
                restoreUnclaimed = false
                errorMessage = nil
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(tint)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(.neutral90)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.neutral70)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private func confirmationGate(_ action: ActiveAction) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
                .background(Color.neutral40)

            Text("Type the business name **\(orgName)** to confirm:")
                .font(.subheadline)
                .foregroundColor(.neutral80)

            TextField(orgName, text: $confirmText)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)

            if action == .delete && isClaim {
                Toggle(isOn: $restoreUnclaimed) {
                    Text("Also restore the original public listing")
                        .font(.caption)
                        .foregroundColor(.neutral80)
                }
                .tint(.turquoise60)
            }

            if let err = errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.error60)
            }

            HStack {
                Button("Cancel") {
                    activeAction = nil
                    confirmText = ""
                    errorMessage = nil
                }
                .foregroundColor(.neutral80)

                Spacer()

                Button {
                    Task {
                        await runAction(action)
                    }
                } label: {
                    HStack(spacing: 6) {
                        if submitting {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.neutral10)
                        }
                        Text(submitting
                             ? "Working…"
                             : (action == .delete ? "Delete permanently" : "Unclaim and restore"))
                            .font(.body.weight(.semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(canConfirm && !submitting ? Color.error60 : Color.neutral40)
                    .foregroundColor(.neutral10)
                    .cornerRadius(8)
                }
                .disabled(!canConfirm || submitting)
            }
        }
    }

    // MARK: - Actions

    private func runAction(_ action: ActiveAction) async {
        guard canConfirm else { return }
        submitting = true
        errorMessage = nil
        defer { submitting = false }

        do {
            switch action {
            case .delete:
                var payload: [String: Any] = ["orgId": orgId]
                if isClaim {
                    payload["restoreUnclaimed"] = restoreUnclaimed
                }
                _ = try await functions
                    .httpsCallable("deleteOrganization")
                    .call(payload)
            case .unclaim:
                _ = try await functions
                    .httpsCallable("unclaimBusiness")
                    .call(["orgId": orgId])
            }

            // Sign out + pop to root so stale Firestore listeners don't
            // generate permission-denied noise on now-deleted org.
            try? Auth.auth().signOut()
            navigator.popToRoot()
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
    }
}
