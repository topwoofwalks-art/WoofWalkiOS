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
            .navigationTitle(String(localized: "settings_title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(String(localized: "action_done")) {
                        dismiss()
                    }
                }
            }
            .alert(String(localized: "settings_about_dialog_title"), isPresented: $showAboutDialog) {
                Button(String(localized: "action_ok"), role: .cancel) { }
            } message: {
                Text(String(localized: "settings_about_dialog_message"))
            }
            .alert(String(localized: "settings_delete_dialog_title"), isPresented: $showDeleteDialog) {
                Button(String(localized: "action_cancel"), role: .cancel) { }
                Button(String(localized: "action_delete"), role: .destructive) {
                    handleDeleteAccountTap()
                }
            } message: {
                Text(String(localized: "settings_delete_dialog_message"))
            }
            // Password re-auth path. Apple requires recent
            // authentication for account deletion; if the last
            // sign-in is older than 5 minutes we prompt for the
            // password first, then delete on success.
            .alert(String(localized: "settings_reauth_password_title"), isPresented: $showReauthPasswordPrompt) {
                SecureField(String(localized: "password"), text: $reauthPassword)
                Button(String(localized: "action_cancel"), role: .cancel) { reauthPassword = "" }
                Button(String(localized: "action_confirm"), role: .destructive) {
                    performDeleteWithPasswordReauth()
                }
            } message: {
                Text(String(localized: "settings_reauth_password_message"))
            }
            // Apple Sign-In users — we can't reauthenticate via
            // password, so we tell them to sign out + sign in again.
            // (A future iteration can present a SignInWithAppleButton
            // sheet inline; the current flow keeps the surface area
            // minimal but still GDPR-compliant.)
            .alert(String(localized: "settings_reauth_apple_title"), isPresented: $showReauthAppleRequired) {
                Button(String(localized: "action_ok"), role: .cancel) { }
            } message: {
                Text(String(localized: "settings_reauth_apple_message"))
            }
            .alert(String(localized: "settings_delete_error_title"), isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )) {
                Button(String(localized: "action_ok"), role: .cancel) { deleteError = nil }
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
                    ProgressView(String(localized: "deleting_account"))
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
            deleteError = String(localized: "settings_delete_missing_email")
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
        Section(String(localized: "settings_section_general")) {
            Picker(String(localized: "settings_distance_unit"), selection: $viewModel.settings.distanceUnit) {
                ForEach(DistanceUnit.allCases, id: \.self) { unit in
                    Text(unit.displayName).tag(unit)
                }
            }

            Picker(String(localized: "settings_speed_unit"), selection: $viewModel.settings.speedUnit) {
                ForEach(SpeedUnit.allCases, id: \.self) { unit in
                    Text(unit.displayName).tag(unit)
                }
            }

            Picker(String(localized: "settings_theme"), selection: $viewModel.settings.theme) {
                ForEach(ThemeMode.allCases, id: \.self) { theme in
                    Text(theme.displayName).tag(theme)
                }
            }

            NavigationLink {
                LanguageSelectionView()
            } label: {
                HStack {
                    Label(String(localized: "settings_language"), systemImage: "globe")
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
        Section(String(localized: "settings_section_walk")) {
            HStack {
                Text(String(localized: "settings_default_walk_distance"))
                Spacer()
                Text("\(Int(viewModel.settings.defaultWalkDistance)) \(viewModel.settings.distanceUnit.rawValue)")
                    .foregroundColor(.secondary)
            }

            Picker(String(localized: "settings_auto_pause_sensitivity"), selection: $viewModel.settings.autoPauseSensitivity) {
                ForEach(AutoPauseSensitivity.allCases, id: \.self) { sensitivity in
                    Text(sensitivity.displayName).tag(sensitivity)
                }
            }

            Toggle(String(localized: "settings_background_tracking"), isOn: $viewModel.settings.backgroundTracking)

            NavigationLink {
                RainModeSettingsView()
            } label: {
                Label(String(localized: "settings_rain_mode"), systemImage: "cloud.rain")
            }

            NavigationLink {
                WalkStatsDisplaySettingsView()
            } label: {
                Label(String(localized: "settings_walk_stats_display"), systemImage: "speedometer")
            }

            VStack(alignment: .leading, spacing: 4) {
                Toggle(String(localized: "settings_voice_guidance"), isOn: $voiceGuidanceEnabled)
                Text(String(localized: "settings_voice_guidance_caption"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Toggle(String(localized: "settings_fog_of_war"), isOn: $fogOfWarEnabled)
                Text(String(localized: "settings_fog_of_war_caption"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var mapPreferencesSection: some View {
        Section(String(localized: "settings_section_map")) {
            Picker(String(localized: "settings_map_style"), selection: $viewModel.settings.mapStyle) {
                ForEach(MapStyleType.allCases, id: \.self) { style in
                    Text(style.displayName).tag(style)
                }
            }

            Toggle(String(localized: "settings_show_traffic"), isOn: $viewModel.settings.showTraffic)
        }
    }

    private var notificationsSection: some View {
        Section(String(localized: "settings_section_notifications")) {
            NavigationLink {
                AlertSettingsView(viewModel: viewModel)
            } label: {
                Label(String(localized: "settings_alert_settings"), systemImage: "bell.badge.fill")
            }

            Toggle(String(localized: "settings_enable_notifications"), isOn: $viewModel.settings.notificationsEnabled)

            Toggle(String(localized: "settings_hazard_alerts"), isOn: $viewModel.settings.hazardAlertsEnabled)
                .disabled(!viewModel.settings.notificationsEnabled)

            Toggle(String(localized: "settings_community_updates"), isOn: $viewModel.settings.communityAlertsEnabled)
                .disabled(!viewModel.settings.notificationsEnabled)

            Toggle(String(localized: "settings_walk_reminders"), isOn: $viewModel.settings.walkRemindersEnabled)
                .disabled(!viewModel.settings.notificationsEnabled)
        }
    }

    private var privacySection: some View {
        Section(String(localized: "settings_section_privacy")) {
            Toggle(String(localized: "settings_profile_visibility"), isOn: $viewModel.settings.profileVisible)

            Toggle(String(localized: "settings_location_sharing"), isOn: $viewModel.settings.locationSharingEnabled)

            NavigationLink {
                PermissionsView()
            } label: {
                Label(String(localized: "settings_permissions"), systemImage: "lock.shield")
            }
        }
    }

    private var givingBackSection: some View {
        Section(String(localized: "settings_section_features")) {
            NavigationLink(destination: CharitySettingsView()) {
                Label(String(localized: "settings_charity_walks"), systemImage: "heart.circle")
            }
            NavigationLink(destination: EmergencyContactsView()) {
                Label(String(localized: "settings_emergency_contacts"), systemImage: "exclamationmark.shield")
            }
            NavigationLink(destination: NotificationCenterScreen()) {
                Label(String(localized: "settings_notifications"), systemImage: "bell")
            }
            // Parity with Android `BetaFeedbackScreen` — writes to the
            // shared `beta_feedback` Firestore collection so iOS reports
            // surface in the same back-office dashboard.
            NavigationLink(destination: BetaFeedbackScreen()) {
                Label("Send beta feedback", systemImage: "ladybug")
            }
        }
    }

    private var dataStorageSection: some View {
        Section(String(localized: "settings_section_data")) {
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
                Label(String(localized: "settings_export_data"), systemImage: "square.and.arrow.up")
            }

            Button {
                viewModel.clearCache()
            } label: {
                Label(String(localized: "settings_clear_cache"), systemImage: "trash")
            }

            Button(role: .destructive) {
                viewModel.resetToDefaults()
            } label: {
                Label(String(localized: "settings_reset_defaults"), systemImage: "arrow.counterclockwise")
            }
        }
    }

    private var aboutSection: some View {
        Section(String(localized: "settings_section_about")) {
            HStack {
                Text(String(localized: "settings_version"))
                Spacer()
                Text("1.0.0 (Build 1)")
                    .foregroundColor(.secondary)
            }

            Button {
                showAboutDialog = true
            } label: {
                Label(String(localized: "settings_about_app"), systemImage: "info.circle")
            }

            Link(destination: URL(string: "https://woofwalk.app/privacy")!) {
                Label(String(localized: "settings_privacy_policy"), systemImage: "hand.raised")
            }

            Link(destination: URL(string: "https://woofwalk.app/terms")!) {
                Label(String(localized: "settings_terms_of_service"), systemImage: "doc.text")
            }

            Link(destination: URL(string: "https://woofwalk.app/support")!) {
                Label(String(localized: "settings_help_support"), systemImage: "questionmark.circle")
            }

            Button(role: .destructive) {
                showDeleteDialog = true
            } label: {
                Label(String(localized: "settings_delete_account"), systemImage: "trash")
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
