import SwiftUI

struct PrivacySettingsScreen: View {
    @AppStorage("profileVisibility") private var profileVisibility = "public"
    @AppStorage("locationSharing") private var locationSharing = true
    @AppStorage("walkHistoryVisible") private var walkHistoryVisible = true
    @AppStorage("showOnLeaderboard") private var showOnLeaderboard = true
    @AppStorage("allowTagging") private var allowTagging = true

    @State private var showExportConfirmation = false
    @State private var isExporting = false

    private let visibilityOptions = ["public", "friends", "private"]

    var body: some View {
        List {
            profileVisibilitySection
            locationSection
            activitySection
            blockListSection
            dataSection
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Profile Visibility

    private var profileVisibilitySection: some View {
        Section {
            Picker(selection: $profileVisibility) {
                Text("Public").tag("public")
                Text("Friends Only").tag("friends")
                Text("Private").tag("private")
            } label: {
                Label("Profile Visibility", systemImage: "eye")
            }
            .pickerStyle(.menu)
        } footer: {
            switch profileVisibility {
            case "public":
                Text("Anyone can view your profile, dogs, and walk stats.")
            case "friends":
                Text("Only people you follow back can see your full profile.")
            case "private":
                Text("Your profile is hidden from search. Only you can see your stats.")
            default:
                EmptyView()
            }
        }
    }

    // MARK: - Location

    private var locationSection: some View {
        Section("Location") {
            VStack(alignment: .leading, spacing: 4) {
                Toggle(isOn: $locationSharing) {
                    Label("Live Location Sharing", systemImage: "location.fill")
                }
                .tint(Color.turquoise60)
                Text("Allow friends to see your location during walks via Live Share.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Activity

    private var activitySection: some View {
        Section("Activity") {
            VStack(alignment: .leading, spacing: 4) {
                Toggle(isOn: $walkHistoryVisible) {
                    Label("Walk History", systemImage: "clock.arrow.circlepath")
                }
                .tint(Color.turquoise60)
                Text("Show your recent walks on your public profile.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Toggle(isOn: $showOnLeaderboard) {
                    Label("Leaderboard", systemImage: "trophy")
                }
                .tint(Color.turquoise60)
                Text("Appear on weekly and regional leaderboards.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Toggle(isOn: $allowTagging) {
                    Label("Allow Tagging", systemImage: "at")
                }
                .tint(Color.turquoise60)
                Text("Let other users tag you in posts and walk shares.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Block List

    private var blockListSection: some View {
        Section("Blocked Users") {
            NavigationLink {
                BlockedUsersListView()
            } label: {
                Label("Manage Blocked Users", systemImage: "hand.raised.fill")
            }
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        Section {
            Button {
                showExportConfirmation = true
            } label: {
                HStack {
                    Label("Export My Data", systemImage: "square.and.arrow.down")
                    Spacer()
                    if isExporting {
                        ProgressView()
                    }
                }
            }
            .disabled(isExporting)
            .alert("Export Data", isPresented: $showExportConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Export") { startExport() }
            } message: {
                Text("We'll prepare a copy of your data including walks, profile info, and photos. You'll receive a notification when it's ready.")
            }
        } footer: {
            Text("Request a full export of your personal data in accordance with GDPR.")
        }
    }

    private func startExport() {
        isExporting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isExporting = false
        }
    }
}

// MARK: - Blocked Users List

private struct BlockedUsersListView: View {
    @State private var blockedUsers: [String] = []

    var body: some View {
        List {
            if blockedUsers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "hand.raised.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No Blocked Users")
                        .font(.headline)
                    Text("Users you block won't be able to see your profile or message you.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacySettingsScreen_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            PrivacySettingsScreen()
        }
    }
}
