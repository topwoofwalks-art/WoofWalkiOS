import SwiftUI

/// Picker sheet that lets a walker pick a WoofWalk friend as a Watch Me
/// guardian. Friends get the in-app push + alarm experience (vs the SMS
/// fallback for phone contacts), so this is the preferred guardian path.
///
/// Reuses `FriendsListViewModel` from FriendsListScreen so the friend list
/// stays consistent with the rest of the app and we don't double-listen on
/// the `friendships` collection. The sheet does its own local search over
/// the loaded list — no Firestore round-trip on every keystroke.
///
/// Mirrors Android `FriendPickerBottomSheet.kt`.
struct FriendPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = FriendsListViewModel()
    @State private var searchText: String = ""

    /// Friend UIDs that are already queued as guardians for the current
    /// Watch Me session. Used to dim and disable rows so the walker can't
    /// add the same friend twice.
    let alreadySelectedUids: Set<String>

    /// Tapped friend hand-off. The sheet dismisses automatically after the
    /// closure fires; parent is responsible for appending the guardian.
    let onSelect: (_ friend: FriendInfo) -> Void

    private var filteredFriends: [FriendInfo] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return viewModel.friends }
        return viewModel.friends.filter {
            $0.displayName.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField

                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if viewModel.friends.isEmpty {
                    emptyState
                } else if filteredFriends.isEmpty {
                    noMatchState
                } else {
                    List(filteredFriends) { friend in
                        FriendPickerRow(
                            friend: friend,
                            isAlreadySelected: alreadySelectedUids.contains(friend.id)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard !alreadySelectedUids.contains(friend.id) else { return }
                            onSelect(friend)
                            dismiss()
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Pick a friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search by name…", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "person.2.slash")
                .font(.system(size: 44))
                .foregroundColor(.secondary.opacity(0.4))
            Text("No friends yet")
                .font(.headline)
            Text("Add WoofWalk friends to pick them as guardians. You can still pick a phone contact instead.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    private var noMatchState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.4))
            Text("No friends match \u{201C}\(searchText)\u{201D}")
                .font(.footnote)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

private struct FriendPickerRow: View {
    let friend: FriendInfo
    let isAlreadySelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            UserAvatarView(
                photoUrl: friend.photoUrl,
                displayName: friend.displayName,
                size: 40
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                if isAlreadySelected {
                    Text("Already added")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if isAlreadySelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
        .opacity(isAlreadySelected ? 0.55 : 1.0)
    }
}
