# WoofWalk iOS Theme System

Complete iOS design system ported from Android Material3 design.

## Color Palette

### Primary (Turquoise)
- Primary color for key actions and branding
- Light mode: `turquoise60` (#00A0B0)
- Dark mode: `turquoise80` (#7AD5DE)
- Full palette: turquoise10-95

### Secondary (Orange)
- Accent color for secondary actions
- Light mode: `orange60` (#FF6B35)
- Dark mode: `orange80` (#FFAD8F)
- Full palette: orange10-95

### Tertiary (Success/Green)
- Success states and positive actions
- Light mode: `success60` (#00A73A)
- Dark mode: `success80` (#7ADB8F)
- Full palette: success10-95

### Neutral
- Text and surface colors
- Full palette: neutral10-99
- Variant palette: neutralVariant10-95

### Error
- Error states and destructive actions
- Light mode: `error60` (#FF5449)
- Dark mode: `error80` (#FFB4AB)
- Full palette: error10-95

## Semantic Colors

### Light Mode
```swift
primary: turquoise60
onPrimary: neutral99
primaryContainer: turquoise90
onPrimaryContainer: turquoise10

secondary: orange60
onSecondary: neutral99
secondaryContainer: orange90
onSecondaryContainer: orange10

background: neutral95
onBackground: neutral10
surface: neutral95
onSurface: neutral10
```

### Dark Mode
```swift
primary: turquoise80
onPrimary: turquoise20
primaryContainer: turquoise30
onPrimaryContainer: turquoise90

secondary: orange80
onSecondary: orange20
secondaryContainer: orange30
onSecondaryContainer: orange90

background: neutral10
onBackground: neutral90
surface: neutral10
onSurface: neutral90
```

## Typography

### Display
- **displayLarge**: 57pt, Regular
- **displayMedium**: 45pt, Regular
- **displaySmall**: 36pt, Regular

### Headline
- **headlineLarge**: 32pt, Regular
- **headlineMedium**: 28pt, Regular
- **headlineSmall**: 24pt, Regular

### Title
- **titleLarge**: 22pt, Semibold
- **titleMedium**: 16pt, Semibold
- **titleSmall**: 14pt, Medium

### Body
- **bodyLarge**: 16pt, Regular
- **bodyMedium**: 14pt, Regular
- **bodySmall**: 12pt, Regular

### Label
- **labelLarge**: 14pt, Medium
- **labelMedium**: 12pt, Medium
- **labelSmall**: 11pt, Medium

## Usage Examples

### Applying Theme
```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            HomeView()
        }
        .applyTheme()
    }
}
```

### Using Colors
```swift
struct MyView: View {
    @Environment(\.woofWalkTheme) var theme

    var body: some View {
        VStack {
            Text("Hello")
                .foregroundColor(theme.onSurface)
        }
        .background(theme.surface)
    }
}
```

### Using Typography
```swift
Text("Headline")
    .titleLarge()
    .foregroundColor(theme.onSurface)

Text("Body text")
    .bodyMedium()
    .foregroundColor(theme.onSurfaceVariant)
```

### Button Styles
```swift
Button("Primary Action") {
    // Action
}
.buttonStyle(PrimaryButtonStyle())

Button("Secondary") {
    // Action
}
.buttonStyle(SecondaryButtonStyle())

Button("Outlined") {
    // Action
}
.buttonStyle(OutlinedButtonStyle())
```

### Cards
```swift
VStack {
    Text("Card Content")
}
.padding()
.cardStyle(elevation: 2)
```

### Chips
```swift
Text("Selected")
    .chipStyle(isSelected: true)

Text("Unselected")
    .chipStyle(isSelected: false)
```

### Icons
```swift
ThemedIcon(AppIcons.map, size: 24, color: .primary)
ThemedIcon.large(AppIcons.dog, color: .secondary)
```

### FAB (Floating Action Button)
```swift
Button {
    // Action
} label: {
    ThemedIcon(AppIcons.add)
}
.fabStyle(size: .large)
```

### Spacing
```swift
VStack(spacing: Spacing.md) {
    Text("Item 1")
    Text("Item 2")
}
.paddingMD()
```

### Elevation
```swift
VStack {
    Text("Elevated")
}
.elevation(3)
```

## Component Integration

Update existing views to use the theme:

```swift
// Before
Text("Title")
    .font(.title)
    .foregroundColor(.blue)

// After
Text("Title")
    .titleLarge()
    .foregroundColor(theme.primary)

// Before
Button("Action") { }
    .padding()
    .background(Color.blue)
    .cornerRadius(8)

// After
Button("Action") { }
    .buttonStyle(PrimaryButtonStyle())
```

## Files

- **Colors.swift**: Color palette and semantic colors
- **Typography.swift**: Text styles and font system
- **Theme.swift**: Theme configuration and environment
- **ComponentStyles.swift**: Button, card, input styles
- **Spacing.swift**: Spacing, corner radius, elevation
- **Icons.swift**: SF Symbols mapping and icon helpers

## Dark Mode

Automatic support via `@Environment(\.colorScheme)`:
- Theme auto-switches based on system preference
- All semantic colors adapt automatically
- No manual color switching needed

## Accessibility

- Uses system fonts (Dynamic Type support)
- Sufficient color contrast ratios
- SF Symbols scale with text size
- Semantic color naming for clarity
