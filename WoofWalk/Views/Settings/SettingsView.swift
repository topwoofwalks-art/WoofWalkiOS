import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var showAboutDialog = false
    @State private var showDeleteDialog = false
    @State private var showExportDialog = false
    @State private var exportURL: URL?

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
                }
            } message: {
                Text("This will permanently delete your account and all associated data. This action cannot be undone.")
            }
            .sheet(isPresented: $showExportDialog) {
                if let url = exportURL {
                    SettingsShareSheet(items: [url])
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
