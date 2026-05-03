import SwiftUI

/// User preferences for which numbers + units to show on the active walk
/// screen. Mirrors the Android `WalkStatsPreferences` DataStore added
/// in v7.6.x. Backed by UserDefaults via `@AppStorage` so reads are cheap and
/// SwiftUI views observe changes automatically.
///
/// Default `kmh` matches Android's `WalkPaceUnit.KMH` — what most walkers
/// recognise without mental conversion.
enum WalkPaceDisplay: String, CaseIterable, Identifiable {
    case kmh = "kmh"
    case mph = "mph"
    case minPerKm = "min_per_km"
    case minPerMile = "min_per_mile"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kmh: return "km/h"
        case .mph: return "mph"
        case .minPerKm: return "min/km"
        case .minPerMile: return "min/mi"
        }
    }
}

/// Lightweight wrapper around AppStorage keys for the prefs. Kept as static
/// constants so other views (ActiveWalkBanner, WalkControlPanel) can read the
/// same flags via `@AppStorage(WalkStatsPrefsKeys.…)` without duplicating
/// string literals.
enum WalkStatsPrefsKeys {
    static let paceDisplay = "walkStats.paceDisplay"
    static let showSteps = "walkStats.showSteps"
    static let showDogSteps = "walkStats.showDogSteps"
    static let showCalories = "walkStats.showCalories"
    static let showElevation = "walkStats.showElevation"
}

struct WalkStatsDisplaySettingsView: View {
    @AppStorage(WalkStatsPrefsKeys.paceDisplay) private var paceDisplayRaw: String = WalkPaceDisplay.kmh.rawValue
    @AppStorage(WalkStatsPrefsKeys.showSteps) private var showSteps: Bool = true
    @AppStorage(WalkStatsPrefsKeys.showDogSteps) private var showDogSteps: Bool = true
    @AppStorage(WalkStatsPrefsKeys.showCalories) private var showCalories: Bool = true
    @AppStorage(WalkStatsPrefsKeys.showElevation) private var showElevation: Bool = false

    private var paceBinding: Binding<WalkPaceDisplay> {
        Binding(
            get: { WalkPaceDisplay(rawValue: paceDisplayRaw) ?? .kmh },
            set: { paceDisplayRaw = $0.rawValue }
        )
    }

    var body: some View {
        Form {
            Section("Pace") {
                // Menu picker fits all 4 unit options without truncating; the
                // segmented style starts to clip at 4 choices on iPhone Mini.
                Picker("Pace display", selection: paceBinding) {
                    ForEach(WalkPaceDisplay.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("Steps") {
                Toggle("Show step count", isOn: $showSteps)
                Toggle("Show dog steps (×2.5)", isOn: $showDogSteps)
                    .disabled(!showSteps)
            }

            Section("Other stats") {
                Toggle("Show calories", isOn: $showCalories)
                Toggle("Show elevation gain", isOn: $showElevation)
            }
        }
        .navigationTitle("Walk Stats Display")
        .navigationBarTitleDisplayMode(.inline)
    }
}
