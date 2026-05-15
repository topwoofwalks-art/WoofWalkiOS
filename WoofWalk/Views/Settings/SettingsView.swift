import SwiftUI
import AuthenticationServices

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @ObservedObject private var authService = AuthService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showAboutDialog = false
    @State private var showDeleteDialog = false
    @State private var showReauthPasswordPrompt = false
    @State private var showReauthAppleRequired = false
    @State private var reauthPassword: String = ""
    @State private var deleteError: String?
    @State private var isDeleting = false
    @State private var showExportDialog = false
    @State private var exportURL: URL?

    @AppStorage("voiceGuidanceEnabled") private var voiceGuidanceEnabled = false
    @AppStorage("fogOfWarEnabled") private var fogOfWarEnabled = false

    var body: some View {
        NavigationView {
            List {
                generalSection
                walkSettingsSection
                mapPreferencesSection
                notificationsSection
                privacySection
                givingBackSection
                dataStorageSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("About WoofWalk", isPresented: $showAboutDialog) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("WoofWalk v1.0.0\n\nA community-driven app for safe and enjoyable dog walking.")
            }
            .alert("Delete Account?", isPresented: $showDeleteDialog) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    handleDeleteAccountTap()
                }
            } message: {
                Text("This will permanently delete your account and all WoofWalk data — dogs, walks, posts, friendships, messages, reviews, bookings, and consent records. This action cannot be undone.")
            }
            // Password re-auth path. Apple requires recent
            // authentication for account deletion; if the last
            // sign-in is older than 5 minutes we prompt for the
            // password first, then delete on success.
            .alert("Confirm Your Password", isPresented: $showReauthPasswordPrompt) {
                SecureField("Password", text: $reauthPassword)
                Button("Cancel", role: .cancel) { reauthPassword = "" }
                Button("Confirm", role: .destructive) {
                    performDeleteWithPasswordReauth()
                }
            } message: {
                Text("For security, please enter your password to confirm account deletion.")
            }
            // Apple Sign-In users — we can't reauthenticate via
            // password, so we tell them to sign out + sign in again.
            // (A future iteration can present a SignInWithAppleButton
            // sheet inline; the current flow keeps the surface area
            // minimal but still GDPR-compliant.)
            .alert("Sign In Again", isPresented: $showReauthAppleRequired) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("For your security, please sign out and sign back in with Apple before deleting your account.")
            }
            .alert("Couldn't Delete Account", isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )) {
                Button("OK", role: .cancel) { deleteError = nil }
            } message: {
                Text(deleteError ?? "")
            }
            .sheet(isPresented: $showExportDialog) {
                if let url = exportURL {
                    SettingsShareSheet(items: [url])
                }
            }
            .overlay {
                if isDeleting {
                    ProgressView("Deleting account…")
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(12)
                }
            }
        }
    }

    private func handleDeleteAccountTap() {
        // Recent-login gate — Apple's account-deletion guidance and
        // Firebase's `requiresRecentLogin` both demand a fresh
        // credential before deleting. If the user just signed in,
        // skip straight to the CF call; otherwise route them through
        // the matching provider's re-auth.
        guard authService.needsReauthForDeletion else {
            performDelete()
            return
        }
        let providers = authService.providerIds
        if providers.contains("password") {
            showReauthPasswordPrompt = true
        } else if providers.contains("apple.com") || providers.contains("google.com") {
            // Google + Apple users — easiest path is "sign out and
            // back in" since we don't keep their refresh token.
            showReauthAppleRequired = true
        } else {
            // Anonymous or unusual provider — try the CF directly;
            // the server will reject with `unauthenticated` if needed
            // and we'll surface that as the standard error message.
            performDelete()
        }
    }

    private func performDeleteWithPasswordReauth() {
        let password = reauthPassword
        reauthPassword = ""
        guard let email = authService.currentUserEmail, !email.isEmpty else {
            deleteError = "Your account is missing an email address. Please contact support."
            return
        }
        isDeleting = true
        Task {
            do {
                try await authService.reauthenticate(email: email, password: password)
                try await authService.deleteAccount()
                await MainActor.run { isDeleting = false }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    deleteError = error.localizedDescription
                }
            }
        }
    }

    private func performDelete() {
        isDeleting = true
        Task {
            do {
                try await authService.deleteAccount()
                await MainActor.run { isDeleting = false }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    deleteError = error.localizedDescription
                }
            }
        }
    }

    private var generalSection: some View {
        Section("General") {
            Picker("Distance Unit", selection: $viewModel.settings.distanceUnit) {
                ForEach(DistanceUnit.allCases, id: \.self) { unit in
                    Text(unit.displayName).tag(unit)
                }
            }

            Picker("Speed Unit", selection: $viewModel.settings.speedUnit) {
                ForEach(SpeedUnit.allCases, id: \.self) { unit in
                    Text(unit.displayName).tag(unit)
                }
            }

            Picker("Theme", selection: $viewModel.settings.theme) {
                ForEach(ThemeMode.allCases, id: \.self) { theme in
                    Text(theme.displayName).tag(theme)
                }
            }

            NavigationLink {
                LanguageSelectionView()
            } label: {
                HStack {
                    Label("Language", systemImage: "globe")
                    Spacer()
                    Text(languageDisplayName)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var languageDisplayName: String {
        let code = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
        let names = ["en": "English", "es": "Spanish", "fr": "French", "de": "German",
                     "it": "Italian", "pt": "Portuguese", "nl": "Dutch", "cy": "Welsh"]
        return names[code] ?? "English"
    }

    private var walkSettingsSection: some View {
        Section("Walk Settings") {
            HStack {
                Text("Default Walk Distance")
                Spacer()
                Text("\(Int(viewModel.settings.defaultWalkDistance)) \(viewModel.settings.distanceUnit.rawValue)")
                    .foregroundColor(.secondary)
            }

            Picker("Auto-Pause Sensitivity", selection: $viewModel.settings.autoPauseSensitivity) {
                ForEach(AutoPauseSensitivity.allCases, id: \.self) { sensitivity in
                    Text(sensitivity.displayName).tag(sensitivity)
                }
            }

            Toggle("Background Tracking", isOn: $viewModel.settings.backgroundTracking)

            NavigationLink {
                RainModeSettingsView()
            } label: {
                Label("Rain Mode", systemImage: "cloud.rain")
            }

            NavigationLink {
                WalkStatsDisplaySettingsView()
            } label: {
                Label("Walk Stats Display", systemImage: "speedometer")
            }

            VStack(alignment: .leading, spacing: 4) {
                Toggle("Voice Guidance", isOn: $voiceGuidanceEnabled)
                Text("Spoken turn-by-turn directions during guided walks")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Toggle("Fog of War Mode", isOn: $fogOfWarEnabled)
                Text("Reveals map areas as you walk through them")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var mapPreferencesSection: some View {
        Section("Map Preferences") {
            Picker("Map Style", selection: $viewModel.settings.mapStyle) {
                ForEach(MapStyleType.allCases, id: \.self) { style in
                    Text(style.displayName).tag(style)
                }
            }

            Toggle("Show Traffic", isOn: $viewModel.settings.showTraffic)
        }
    }

    private var notificationsSection: some View {
        Section("Notifications") {
            NavigationLink {
                AlertSettingsView(viewModel: viewModel)
            } label: {
                Label("Alert Settings", systemImage: "bell.badge.fill")
            }

            Toggle("Enable Notifications", isOn: $viewModel.settings.notificationsEnabled)

            Toggle("Hazard Alerts", isOn: $viewModel.settings.hazardAlertsEnabled)
                .disabled(!viewModel.settings.notificationsEnabled)

            Toggle("Community Updates", isOn: $viewModel.settings.communityAlertsEnabled)
                .disabled(!viewModel.settings.notificationsEnabled)

            Toggle("Walk Reminders", isOn: $viewModel.settings.walkRemindersEnabled)
                .disabled(!viewModel.settings.notificationsEnabled)
        }
    }

    private var privacySection: some View {
        Section("Privacy & Security") {
            Toggle("Profile Visibility", isOn: $viewModel.settings.profileVisible)

            Toggle("Location Sharing", isOn: $viewModel.settings.locationSharingEnabled)

            NavigationLink {
                PermissionsView()
            } label: {
                Label("Permissions", systemImage: "lock.shield")
            }
        }
    }

    private var givingBackSection: some View {
        Section("Features") {
            NavigationLink(destination: CharitySettingsView()) {
                Label("Charity Walks", systemImage: "heart.circle")
            }
            NavigationLink(destination: EmergencyContactsView()) {
                Label("Emergency Contacts", systemImage: "exclamationmark.shield")
            }
            NavigationLink(destination: NotificationCenterScreen()) {
                Label("Notifications", systemImage: "bell")
            }
        }
    }

    private var dataStorageSection: some View {
        Section("Data & Storage") {
            Button {
                viewModel.exportData { result in
                    switch result {
                    case .success(let url):
                        exportURL = url
                        showExportDialog = true
                    case .failure:
                        break
                    }
                }
            } label: {
                Label("Export Data", systemImage: "square.and.arrow.up")
            }

            Button {
                viewModel.clearCache()
            } label: {
                Label("Clear Cache", systemImage: "trash")
            }

            Button(role: .destructive) {
                viewModel.resetToDefaults()
            } label: {
                Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
            }
        }
    }

    private var aboutSection: some View {
        Section("About & Help") {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0 (Build 1)")
                    .foregroundColor(.secondary)
            }

            Button {
                showAboutDialog = true
            } label: {
                Label("About WoofWalk", systemImage: "info.circle")
            }

            Link(destination: URL(string: "https://woofwalk.app/privacy")!) {
                Label("Privacy Policy", systemImage: "hand.raised")
            }

            Link(destination: URL(string: "https://woofwalk.app/terms")!) {
                Label("Terms of Service", systemImage: "doc.text")
            }

            Link(destination: URL(string: "https://woofwalk.app/support")!) {
                Label("Help & Support", systemImage: "questionmark.circle")
            }

            Button(role: .destructive) {
                showDeleteDialog = true
            } label: {
                Label("Delete Account", systemImage: "trash")
            }
        }
    }
}

struct SettingsShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    }
}
