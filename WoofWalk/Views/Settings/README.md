# Settings & Preferences Implementation

## Overview
Comprehensive settings system for WoofWalk iOS app, mirroring Android functionality with iOS-native implementation.

## File Structure

```
WoofWalkiOS/WoofWalk/
├── Models/
│   └── UserSettings.swift              # Settings data model with all preference types
├── ViewModels/
│   └── SettingsViewModel.swift         # Settings state management and persistence
└── Views/Settings/
    ├── SettingsView.swift              # Main settings screen
    ├── AlertSettingsView.swift         # Alert preferences configuration
    ├── PermissionsView.swift           # Permission status and management
    └── DataManagementView.swift        # Storage and data export

```

## Settings Categories

### 1. General Settings
**Location:** SettingsView.swift - `generalSection`

- **Distance Unit**: Kilometers or Miles
- **Speed Unit**: km/h, mph, min/km, min/mi
- **Theme**: Light, Dark, or Auto (follows system)

**Implementation:**
```swift
Picker("Distance Unit", selection: $viewModel.settings.distanceUnit) {
    ForEach(DistanceUnit.allCases, id: \.self) { unit in
        Text(unit.displayName).tag(unit)
    }
}
```

### 2. Walk Settings
**Location:** SettingsView.swift - `walkSettingsSection`

- **Default Walk Distance**: Target distance for walks (1-20 km/mi)
- **Auto-Pause Sensitivity**: Low, Medium, High, or Off
  - Low: 0.3 m/s threshold
  - Medium: 0.5 m/s threshold
  - High: 0.8 m/s threshold
  - Off: No auto-pause
- **Background Tracking**: Enable/disable GPS tracking in background

**Usage:**
```swift
settings.autoPauseSensitivity.threshold  // Get threshold in m/s
```

### 3. Map Preferences
**Location:** SettingsView.swift - `mapPreferencesSection`

- **Map Style**: Standard, Hybrid, or Satellite
- **Show Traffic**: Toggle traffic overlay on map

**Integration:**
```swift
mapView.mapType = viewModel.settings.mapStyle.mapType
mapView.showsTraffic = viewModel.settings.showTraffic
```

### 4. Notifications
**Location:** SettingsView.swift - `notificationsSection`

- **Enable Notifications**: Master switch for all notifications
- **Hazard Alerts**: Alerts for nearby hazards
- **Community Updates**: New POIs and comments
- **Walk Reminders**: Daily walk reminders
- **Alert Settings**: Link to detailed alert configuration

### 5. Alert Settings (Detailed)
**Location:** AlertSettingsView.swift

#### Alert Radius
- Range: 500m to 5km
- Step: 500m intervals
- Controls geofence radius for hazard alerts

#### Notification Preferences
- **Sound**: Play notification sound
- **Vibration**: Vibrate on alert
- **Heads-up**: Show as banner notification

#### Alert Types
Enable/disable specific hazard types:
- **Hazards**: Dangerous areas, broken glass, etc.
- **Wildlife**: Wild animal sightings
- **Livestock**: Cattle, horses, sheep, etc.

#### Quiet Hours
- **Enable Quiet Hours**: Toggle to silence alerts during specific times
- **Start Time**: Beginning of quiet period (12-hour format)
- **End Time**: End of quiet period (12-hour format)

**Implementation:**
```swift
if settings.quietHoursEnabled {
    let currentHour = Calendar.current.component(.hour, from: Date())
    let isQuietTime = // Check if current hour is in quiet range
    if isQuietTime { return } // Skip alert
}
```

### 6. Privacy & Security
**Location:** SettingsView.swift - `privacySection`

- **Profile Visibility**: Show/hide profile to other users
- **Location Sharing**: Share location with friends
- **Permissions**: Link to permissions management screen

### 7. Permissions Management
**Location:** PermissionsView.swift

Displays current status for:
- **Location Services**:
  - Not Set / Denied / While Using App / Always / Restricted
  - Required for walk tracking and hazard alerts
- **Photo Library**:
  - Not Set / Denied / Authorized / Restricted
  - Required for hazard reports and POI images
- **Notifications**:
  - Not Set / Denied / Authorized
  - Required for alerts and reminders

**Features:**
- Color-coded status indicators (green/orange/red)
- Direct link to iOS Settings app
- Explanatory text for each permission

### 8. Data & Storage
**Location:** DataManagementView.swift

#### Storage Usage Display
- Total Storage Used
- Walk Data size
- Photos size
- Cache size

#### Cache Management
- **Clear Cache**: Remove all cached map tiles and images
- **Auto-Clear Cache**: Automatically clear when exceeds 500 MB
- **Offline Maps**: Download and cache map tiles for offline use

#### Data Export
Export options in JSON format:
- **Export All Data**: Complete data dump
- **Export Walk History**: Just walks and routes
- **Export Settings**: User preferences only

**Export Implementation:**
```swift
viewModel.exportAllData { result in
    switch result {
    case .success(let url):
        // Show share sheet with file
    case .failure(let error):
        // Handle error
    }
}
```

#### Danger Zone
- **Delete All Local Data**: Remove walks, photos, and local data
- Cloud data remains intact

### 9. About & Help
**Location:** SettingsView.swift - `aboutSection`

- **Version**: Display app version and build number
- **About WoofWalk**: App description dialog
- **Privacy Policy**: Link to privacy policy
- **Terms of Service**: Link to terms
- **Help & Support**: Link to support resources
- **Delete Account**: Permanently delete account (requires confirmation)

## Data Model

### UserSettings Structure
```swift
struct UserSettings: Codable {
    // General
    var distanceUnit: DistanceUnit = .kilometers
    var speedUnit: SpeedUnit = .kilometersPerHour
    var theme: ThemeMode = .auto

    // Map
    var mapStyle: MapStyleType = .standard
    var showTraffic: Bool = false

    // Walk
    var defaultWalkDistance: Double = 5.0
    var autoPauseSensitivity: AutoPauseSensitivity = .medium
    var backgroundTracking: Bool = true

    // Notifications
    var notificationsEnabled: Bool = true
    var hazardAlertsEnabled: Bool = true
    var communityAlertsEnabled: Bool = false
    var walkRemindersEnabled: Bool = true

    // Privacy
    var profileVisible: Bool = true
    var locationSharingEnabled: Bool = false

    // Alerts
    var alertRadiusMeters: Int = 2000
    var soundEnabled: Bool = true
    var vibrationEnabled: Bool = true
    var headsUpEnabled: Bool = true
    var quietHoursEnabled: Bool = false
    var quietHoursStart: Int = 22
    var quietHoursEnd: Int = 7
    var enabledAlertTypes: Set<String> = ["hazard", "wildlife", "livestock"]
}
```

## Persistence

### UserDefaults Storage
Settings are automatically saved to UserDefaults with 0.5 second debounce:

```swift
$settings
    .debounce(for: 0.5, scheduler: DispatchQueue.main)
    .sink { [weak self] settings in
        self?.saveSettings(settings)
    }
    .store(in: &cancellables)
```

### Storage Key
- Key: `"userSettings"`
- Format: JSON-encoded UserSettings struct

### Loading Settings
```swift
if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
   let decoded = try? JSONDecoder().decode(UserSettings.self, from: data) {
    self.settings = decoded
} else {
    self.settings = UserSettings() // Use defaults
}
```

## Unit Conversion Utilities

### Distance Conversion
```swift
// Meters to user's preferred unit
let distance = settings.distanceUnit.convert(meters)

// User unit to meters
let meters = settings.distanceUnit.toMeters(value)
```

### Speed Conversion
```swift
// Meters per second to user's preferred unit
let speed = settings.speedUnit.convert(metersPerSecond: mps)
```

## Integration Examples

### Using Settings in Walk Tracking
```swift
@StateObject private var settingsVM = SettingsViewModel()

// Check auto-pause threshold
if currentSpeed < settingsVM.settings.autoPauseSensitivity.threshold {
    pauseTracking()
}

// Display distance in user's preferred unit
let displayDistance = settingsVM.settings.distanceUnit.convert(distanceMeters)
Text("\(displayDistance, specifier: "%.2f") \(settingsVM.settings.distanceUnit.rawValue)")
```

### Using Alert Settings
```swift
// Check if should show alert
if !settingsVM.settings.notificationsEnabled { return }
if !settingsVM.settings.hazardAlertsEnabled { return }
if !settingsVM.settings.enabledAlertTypes.contains(poiType) { return }

// Check quiet hours
if settingsVM.settings.quietHoursEnabled {
    let hour = Calendar.current.component(.hour, from: Date())
    let start = settingsVM.settings.quietHoursStart
    let end = settingsVM.settings.quietHoursEnd

    if isInQuietHours(hour, start: start, end: end) {
        return // Skip alert
    }
}

// Show alert with user preferences
showAlert(
    sound: settingsVM.settings.soundEnabled,
    vibrate: settingsVM.settings.vibrationEnabled,
    headsUp: settingsVM.settings.headsUpEnabled
)
```

### Using Map Settings
```swift
@StateObject private var settingsVM = SettingsViewModel()

MapView(...)
    .mapStyle(settingsVM.settings.mapStyle.mapType)
    .showsTraffic(settingsVM.settings.showTraffic)
```

## iOS-Specific Considerations

### Permission Management
- Uses `CLLocationManager` for location authorization
- Uses `PHPhotoLibrary` for photo authorization
- Uses `UNUserNotificationCenter` for notification authorization
- Opens iOS Settings app for permission changes

### UI Components
- Native SwiftUI List and Form components
- iOS-style toggles and pickers
- Navigation links for sub-screens
- Share sheet for data export

### Data Storage
- UserDefaults for settings persistence
- Automatic JSON encoding/decoding
- Debounced saves to prevent excessive writes

## Testing Checklist

- [ ] Settings persist across app restarts
- [ ] Unit conversions work correctly
- [ ] Alert radius slider updates correctly
- [ ] Quiet hours time picker works
- [ ] Alert types can be toggled on/off
- [ ] Permission status displays correctly
- [ ] Storage usage calculates correctly
- [ ] Cache clearing works
- [ ] Data export generates valid JSON
- [ ] Delete account shows confirmation
- [ ] Theme changes apply correctly
- [ ] Map style changes apply to map
- [ ] Links to external URLs work

## Android Parity

All features from Android SettingsScreen.kt have been implemented:
- ✅ Notifications settings
- ✅ Map preferences (theme, traffic, satellite)
- ✅ Privacy settings (profile visibility, location sharing)
- ✅ About section with version and links
- ✅ Delete account with confirmation
- ✅ Alert history and settings navigation
- ✅ Alert radius configuration
- ✅ Notification preferences (sound, vibration, heads-up)
- ✅ Alert type filters
- ✅ Quiet hours with time picker

Additional iOS-specific enhancements:
- Unit preferences (distance and speed)
- Auto-pause sensitivity configuration
- Background tracking toggle
- GPS accuracy settings (future)
- Comprehensive permission management screen
- Data export functionality
- Storage usage display and cache management
