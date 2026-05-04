import SwiftUI

/// MatchFoundSheet — dedup gate for business signup.
///
/// Mirrors the portal's `MatchFoundModal` (used by the dedup branch in
/// `BusinessApplicationScreen.tsx`, lines 1238-1294).
///
/// When `createBusinessAccount` returns
/// `{ requiresConfirmation: true, matches: [...] }`, the caller
/// surfaces this sheet with the candidate businesses. The user picks
/// one of three branches:
///
///   * **Claim this one** → `onClaim(candidate)`. The caller routes
///     into the existing claim flow with the candidate's id as the
///     `claim` source. If the candidate is an already-on-platform org
///     (source: organisation), the claim path doesn't apply — caller
///     should surface a "this business is already on WoofWalk; sign in
///     as the existing owner" message.
///
///   * **No, mine is different** → `onConfirmNoMatch()`. Caller
///     resubmits `createBusinessAccount` with `confirmedNoMatch: true`
///     so the server-side dedup gate is bypassed.
///
///   * **Cancel / dismiss** → `onCancel()`. Caller stays on the signup
///     flow with the form pristine.
///
/// Brand-locked dark mode (Info.plist single-mode); turquoise60 for
/// the primary CTA, neutral20 surface, error/amber for the dismiss
/// path.
struct MatchFoundSheet: View {
    /// Plain-data shape — kept independent of the Firestore decode so
    /// the caller can adapt the CF response without owning a model
    /// type. Fields mirror the `BusinessMatchCandidate.preview` from
    /// `findExistingBusinessInternal`.
    struct Candidate: Identifiable, Equatable {
        let id: String
        let name: String
        let address: String?
        let postcode: String?
        let phone: String?
        /// "organizations" if already on WoofWalk, "unclaimed" if from
        /// the scrape pool. Drives the claim CTA labelling.
        let source: String
        let isClaimed: Bool
        let confidence: Double
    }

    let candidates: [Candidate]
    var onClaim: (Candidate) -> Void
    var onConfirmNoMatch: () -> Void
    var onCancel: () -> Void

    @State private var selectedId: String?

    private var selected: Candidate? {
        guard let id = selectedId else { return candidates.first }
        return candidates.first { $0.id == id } ?? candidates.first
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.neutral10.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        header

                        if candidates.isEmpty {
                            Text("No matches")
                                .foregroundColor(.neutral80)
                                .padding()
                        } else {
                            ForEach(candidates) { candidate in
                                candidateCard(candidate)
                            }
                        }

                        if let s = selected {
                            actions(for: s)
                                .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("Is this you?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { onCancel() }
                        .foregroundColor(.turquoise60)
                }
            }
        }
        .onAppear {
            if selectedId == nil {
                selectedId = candidates.first?.id
            }
        }
    }

    // MARK: - Sub-views

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundColor(.turquoise60)
            Text(candidates.count > 1 ? "We found \(candidates.count) businesses that might be yours" : "We may have found your listing")
                .font(.headline)
                .foregroundColor(.neutral90)
                .multilineTextAlignment(.center)
            Text("Claim it to take control of your existing profile, or confirm that yours is different.")
                .font(.caption)
                .foregroundColor(.neutral70)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private func candidateCard(_ c: Candidate) -> some View {
        let isSelected = (selectedId ?? candidates.first?.id) == c.id
        return Button {
            selectedId = c.id
        } label: {
            HStack(spacing: 12) {
                Image(systemName: c.isClaimed ? "checkmark.seal.fill" : "building.2.fill")
                    .foregroundColor(c.isClaimed ? .turquoise60 : Color(hex: 0xFFB74D))
                    .font(.system(size: 22))

                VStack(alignment: .leading, spacing: 4) {
                    Text(c.name)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.neutral90)
                    if let line = formattedAddress(c) {
                        Text(line)
                            .font(.caption)
                            .foregroundColor(.neutral70)
                    }
                    if let phone = c.phone, !phone.isEmpty {
                        Text(phone)
                            .font(.caption)
                            .foregroundColor(.neutral70)
                    }
                    Text(c.source == "organizations" ? "Already on WoofWalk" : "Unclaimed listing")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(c.source == "organizations" ? Color.turquoise60.opacity(0.2) : Color(hex: 0xFFB74D).opacity(0.2))
                        .foregroundColor(c.source == "organizations" ? .turquoise60 : Color(hex: 0xFFB74D))
                        .cornerRadius(4)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.turquoise60)
                }
            }
            .padding(12)
            .background(Color.neutral20)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.turquoise60 : Color.neutral40, lineWidth: isSelected ? 2 : 1)
            )
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    private func actions(for c: Candidate) -> some View {
        VStack(spacing: 10) {
            Button {
                onClaim(c)
            } label: {
                Text(c.source == "organizations" ? "This is already mine — sign in instead" : "Yes, claim this listing")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.turquoise60)
                    .foregroundColor(.neutral10)
                    .cornerRadius(10)
            }

            Button {
                onConfirmNoMatch()
            } label: {
                Text("No, mine is different")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.clear)
                    .foregroundColor(.neutral90)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.neutral40, lineWidth: 1)
                    )
            }
        }
    }

    private func formattedAddress(_ c: Candidate) -> String? {
        let parts = [c.address, c.postcode].compactMap { $0?.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}
