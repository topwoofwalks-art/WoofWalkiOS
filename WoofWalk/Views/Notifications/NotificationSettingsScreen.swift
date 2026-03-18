import SwiftUI

struct NotificationSettingsScreen: View {
    @AppStorage("notifMasterToggle") private var masterEnabled = true
    @AppStorage("notifWalkReminders") private var walkReminders = true
    @AppStorage("notifHazardAlerts") private var hazardAlerts = true
    @AppStorage("notifWalkComplete") private var walkComplete = true
    @AppStorage("notifNewFollower") private var newFollower = true
    @AppStorage("notifLikes") private var likes = true
    @AppStorage("notifComments") private var comments = true
    @AppStorage("notifMessages") private var messages = true
    @AppStorage("notifMessagePreview") private var messagePreview = true
    @AppStorage("notifChallenges") private var challenges = true
    @AppStorage("notifLeagueUpdates") private var leagueUpdates = true
    @AppStorage("notifAppUpdates") private var appUpdates = true
    @AppStorage("notifCommunityNews") private var communityNews = false
    @AppStorage("notifQuietHoursEnabled") private var quietHoursEnabled = false
    @State private var quietStart = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
    @State private var quietEnd = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()

    var body: some View {
        List {
            masterSection
            walkAlertsSection
            socialSection
            messagesSection
            challengesSection
            systemSection
            quietHoursSection
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Master Toggle

    private var masterSection: some View {
        Section {
            Toggle(isOn: $masterEnabled) {
                Label("Enable Notifications", systemImage: "bell.fill")
            }
            .tint(Color.turquoise60)
        } footer: {
            Text("Turn off to disable all push notifications from WoofWalk.")
        }
    }

    // MARK: - Walk Alerts

    private var walkAlertsSection: some View {
        Section("Walk Alerts") {
            settingsToggle(
                "Walk Reminders",
                icon: "figure.walk",
                isOn: $walkReminders,
                description: "Daily reminders to walk your dog"
            )
            settingsToggle(
                "Hazard Alerts",
                icon: "exclamationmark.triangle.fill",
                isOn: $hazardAlerts,
                description: "Nearby hazards reported by the community"
            )
            settingsToggle(
                "Walk Complete",
                icon: "checkmark.circle.fill",
                isOn: $walkComplete,
                description: "Summary when you finish a walk"
            )
        }
        .disabled(!masterEnabled)
    }

    // MARK: - Social

    private var socialSection: some View {
        Section("Social") {
            settingsToggle(
                "New Followers",
                icon: "person.badge.plus",
                isOn: $newFollower,
                description: "When someone starts following you"
            )
            settingsToggle(
                "Likes",
                icon: "heart.fill",
                isOn: $likes,
                description: "When someone likes your post or walk"
            )
            settingsToggle(
                "Comments",
                icon: "bubble.left.fill",
                isOn: $comments,
                description: "When someone comments on your post"
            )
        }
        .disabled(!masterEnabled)
    }

    // MARK: - Messages

    private var messagesSection: some View {
        Section("Messages") {
            settingsToggle(
                "New Messages",
                icon: "envelope.fill",
                isOn: $messages,
                description: "When you receive a new message"
            )
            settingsToggle(
                "Message Previews",
                icon: "text.bubble",
                isOn: $messagePreview,
                description: "Show message content in notifications"
            )
        }
        .disabled(!masterEnabled)
    }

    // MARK: - Challenges

    private var challengesSection: some View {
        Section("Challenges & Leagues") {
            settingsToggle(
                "Challenge Updates",
                icon: "flag.checkered",
                isOn: $challenges,
                description: "Progress and completion alerts"
            )
            settingsToggle(
                "League Updates",
                icon: "trophy.fill",
                isOn: $leagueUpdates,
                description: "Weekly league position changes"
            )
        }
        .disabled(!masterEnabled)
    }

    // MARK: - System

    private var systemSection: some View {
        Section("System") {
            settingsToggle(
                "App Updates",
                icon: "arrow.down.circle.fill",
                isOn: $appUpdates,
                description: "New features and improvements"
            )
            settingsToggle(
                "Community News",
                icon: "newspaper.fill",
                isOn: $communityNews,
                description: "News and tips from the WoofWalk team"
            )
        }
        .disabled(!masterEnabled)
    }

    // MARK: - Quiet Hours

    private var quietHoursSection: some View {
        Section {
            Toggle(isOn: $quietHoursEnabled) {
                Label("Quiet Hours", systemImage: "moon.fill")
            }
            .tint(Color.turquoise60)

            if quietHoursEnabled {
                DatePicker("Start", selection: $quietStart, displayedComponents: .hourAndMinute)
                DatePicker("End", selection: $quietEnd, displayedComponents: .hourAndMinute)
            }
        } footer: {
            Text("Notifications will be silenced during quiet hours. You'll still see them when you open the app.")
        }
        .disabled(!masterEnabled)
    }

    // MARK: - Reusable Toggle Row

    private func settingsToggle(_ title: String, icon: String, isOn: Binding<Bool>, description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: isOn) {
                Label(title, systemImage: icon)
            }
            .tint(Color.turquoise60)
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct NotificationSettingsScreen_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            NotificationSettingsScreen()
        }
    }
}
