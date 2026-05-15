import SwiftUI

/// Picker sheet — tapping a charity row pushes the per-charity detail
/// screen (parity with Android). The detail screen's "Make this my chosen
/// charity" CTA is the only path that actually persists the choice; this
/// sheet just disambiguates which charity the user wants to learn about.
struct CharityPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCharityId: String

    var body: some View {
        NavigationStack {
            List(CharityOrg.supportedCharities) { charity in
                NavigationLink {
                    // Push the detail screen. Selection happens there so
                    // users can see the charity's mission + leaderboard
                    // before committing.
                    CharityDetailScreen(charityId: charity.id)
                        .onDisappear {
                            // Re-read the (now possibly updated) selected
                            // charity so the picker's checkmark reflects
                            // the user's decision on the detail screen.
                            selectedCharityId = CharityRepository.shared.getSelectedCharityId()
                        }
                } label: {
                    HStack(spacing: 12) {
                        Text(charity.logoEmoji)
                            .font(.title)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.turquoise90))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(charity.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(charity.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }

                        Spacer()

                        if charity.id == selectedCharityId {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.turquoise60)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Choose Charity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
