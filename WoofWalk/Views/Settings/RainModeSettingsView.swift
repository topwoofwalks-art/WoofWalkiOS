import SwiftUI

struct RainModeSettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        List {
            rainDetectionSection
            filterStrengthSection
            touchFilteringSection
        }
        .navigationTitle("Rain Mode")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Rain Detection

    private var rainDetectionSection: some View {
        Section("Rain Detection") {
            Toggle("Auto-detect rain", isOn: $viewModel.settings.rainAutoDetection)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Sensitivity")
                    Spacer()
                    Text(sensitivityLabel)
                        .foregroundColor(.secondary)
                }

                Slider(
                    value: Binding(
                        get: { Double(viewModel.settings.rainDetectionSensitivity) },
                        set: { viewModel.settings.rainDetectionSensitivity = Int($0) }
                    ),
                    in: 1...5,
                    step: 1
                )

                HStack {
                    Text("Conservative")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Aggressive")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .disabled(!viewModel.settings.rainAutoDetection)
        }
    }

    private var sensitivityLabel: String {
        switch viewModel.settings.rainDetectionSensitivity {
        case 1: return "Very Conservative"
        case 2: return "Conservative"
        case 3: return "Balanced"
        case 4: return "Aggressive"
        case 5: return "Very Aggressive"
        default: return "Balanced"
        }
    }

    // MARK: - Filter Strength

    private var filterStrengthSection: some View {
        Section {
            Picker("Filter Preset", selection: $viewModel.settings.rainFilterPreset) {
                Text("Light Rain").tag("light")
                Text("Heavy Rain").tag("heavy")
                Text("Gloves Mode").tag("gloves")
            }
            .pickerStyle(.segmented)

            Text(filterPresetDescription)
                .font(.caption)
                .foregroundColor(.secondary)
        } header: {
            Text("Filter Strength")
        }
    }

    private var filterPresetDescription: String {
        switch viewModel.settings.rainFilterPreset {
        case "light":
            return "Minimal filtering for light drizzle. Small touch target increase with basic debouncing."
        case "heavy":
            return "Stronger filtering for heavy rain. Larger touch targets and aggressive debouncing to reject water drops."
        case "gloves":
            return "Maximum filtering for gloved use. Extra-large touch targets, simplified UI elements, and extended tap durations."
        default:
            return "Select a preset above."
        }
    }

    // MARK: - Touch Filtering

    private var touchFilteringSection: some View {
        Section {
            Toggle("Enable touch filtering during rain", isOn: $viewModel.settings.rainTouchFiltering)

            Text("Increases touch targets to prevent accidental taps from rain drops or wet fingers.")
                .font(.caption)
                .foregroundColor(.secondary)
        } header: {
            Text("Touch Filtering")
        }
    }
}

#Preview {
    NavigationView {
        RainModeSettingsView()
    }
}
