import SwiftUI

struct AlertSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showStartTimePicker = false
    @State private var showEndTimePicker = false

    var body: some View {
        List {
            alertRadiusSection
            notificationPreferencesSection
            alertTypesSection
            quietHoursSection
        }
        .navigationTitle("Alert Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var alertRadiusSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Alert Radius")
                        .font(.headline)
                    Spacer()
                    Text(formatDistance(viewModel.settings.alertRadiusMeters))
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                }

                Text("You'll receive alerts for hazards within this distance")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Slider(
                    value: Binding(
                        get: { Double(viewModel.settings.alertRadiusMeters) },
                        set: { viewModel.updateAlertRadius(Int($0)) }
                    ),
                    in: 500...5000,
                    step: 500
                )

                HStack {
                    Text("500m")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("5km")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var notificationPreferencesSection: some View {
        Section("Notification Preferences") {
            Toggle(isOn: $viewModel.settings.soundEnabled) {
                HStack {
                    Image(systemName: "speaker.wave.2")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    VStack(alignment: .leading) {
                        Text("Sound")
                        Text("Play notification sound for alerts")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Toggle(isOn: $viewModel.settings.vibrationEnabled) {
                HStack {
                    Image(systemName: "vibration")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    VStack(alignment: .leading) {
                        Text("Vibration")
                        Text("Vibrate when alert is received")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Toggle(isOn: $viewModel.settings.headsUpEnabled) {
                HStack {
                    Image(systemName: "bell.badge")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    VStack(alignment: .leading) {
                        Text("Heads-up Notifications")
                        Text("Show alerts as banner notification")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var alertTypesSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Alert Types")
                    .font(.headline)
                Text("Select which types of hazards trigger alerts")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)

            AlertTypeRow(
                type: "hazard",
                icon: "exclamationmark.triangle.fill",
                title: "Hazards",
                description: "Dangerous areas, broken glass, etc.",
                isEnabled: viewModel.settings.enabledAlertTypes.contains("hazard"),
                onToggle: { viewModel.toggleAlertType("hazard") }
            )

            AlertTypeRow(
                type: "wildlife",
                icon: "pawprint.fill",
                title: "Wildlife",
                description: "Wild animal sightings",
                isEnabled: viewModel.settings.enabledAlertTypes.contains("wildlife"),
                onToggle: { viewModel.toggleAlertType("wildlife") }
            )

            AlertTypeRow(
                type: "livestock",
                icon: "leaf.fill",
                title: "Livestock",
                description: "Cattle, horses, sheep, etc.",
                isEnabled: viewModel.settings.enabledAlertTypes.contains("livestock"),
                onToggle: { viewModel.toggleAlertType("livestock") }
            )
        }
    }

    private var quietHoursSection: some View {
        Section {
            Toggle(isOn: $viewModel.settings.quietHoursEnabled) {
                VStack(alignment: .leading) {
                    Text("Quiet Hours")
                        .font(.headline)
                    Text("Silence alerts during specific hours")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if viewModel.settings.quietHoursEnabled {
                HStack {
                    Button {
                        showStartTimePicker = true
                    } label: {
                        Text(formatHour(viewModel.settings.quietHoursStart))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }

                    Image(systemName: "arrow.right")
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    Button {
                        showEndTimePicker = true
                    } label: {
                        Text(formatHour(viewModel.settings.quietHoursEnd))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }

                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showStartTimePicker) {
            TimePickerView(
                selectedHour: $viewModel.settings.quietHoursStart,
                title: "Start Time"
            )
        }
        .sheet(isPresented: $showEndTimePicker) {
            TimePickerView(
                selectedHour: $viewModel.settings.quietHoursEnd,
                title: "End Time"
            )
        }
    }

    private func formatDistance(_ meters: Int) -> String {
        if meters >= 1000 {
            return "\(meters / 1000)km"
        } else {
            return "\(meters)m"
        }
    }

    private func formatHour(_ hour: Int) -> String {
        let period = hour < 12 ? "AM" : "PM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(displayHour):00 \(period)"
    }
}

struct AlertTypeRow: View {
    let type: String
    let icon: String
    let title: String
    let description: String
    let isEnabled: Bool
    let onToggle: () -> Void

    var body: some View {
        Toggle(isOn: Binding(
            get: { isEnabled },
            set: { _ in onToggle() }
        )) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                VStack(alignment: .leading) {
                    Text(title)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct TimePickerView: View {
    @Binding var selectedHour: Int
    let title: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack {
                Picker("Hour", selection: $selectedHour) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text(formatHour(hour)).tag(hour)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()

                Spacer()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func formatHour(_ hour: Int) -> String {
        let period = hour < 12 ? "AM" : "PM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(displayHour):00 \(period)"
    }
}
