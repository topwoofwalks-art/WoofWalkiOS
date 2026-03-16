# Theme Quick Reference Guide

## Setup (One-time)

```swift
// WoofWalkApp.swift
import SwiftUI

@main
struct WoofWalkApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .applyTheme()  // ← Add this
        }
    }
}
```

## Basic Usage

```swift
import SwiftUI

struct MyView: View {
    @Environment(\.woofWalkTheme) var theme  // ← Add this

    var body: some View {
        VStack {
            Text("Hello")
                .foregroundColor(theme.onSurface)  // ← Use theme colors
        }
        .background(theme.surface)
    }
}
```

## Color Cheat Sheet

```swift
// Most Common Colors
theme.primary              // Brand color (turquoise)
theme.onPrimary           // Text on primary (white)
theme.secondary           // Accent (orange)
theme.background          // App background
theme.surface             // Card/component background
theme.onSurface           // Text on surface (black/white)
theme.onSurfaceVariant    // Secondary text (gray)
theme.error               // Error states (red)
theme.outline             // Borders

// Use Cases
.foregroundColor(theme.onSurface)        // Primary text
.foregroundColor(theme.onSurfaceVariant) // Secondary text
.background(theme.surface)                // Card background
.background(theme.primaryContainer)       // Highlighted area
.stroke(theme.outline)                    // Border color
```

## Typography Cheat Sheet

```swift
// Headers
Text("Screen Title").titleLarge()
Text("Section").titleMedium()
Text("Subsection").titleSmall()

// Body Text
Text("Main content").bodyLarge()
Text("Details").bodyMedium()
Text("Fine print").bodySmall()

// Buttons & Labels
Text("BUTTON").labelLarge()
Text("Tab").labelMedium()
Text("Tag").labelSmall()
```

## Button Styles

```swift
// Primary (filled turquoise)
Button("Start Walk") { }
    .buttonStyle(PrimaryButtonStyle())

// Secondary (filled orange)
Button("Cancel") { }
    .buttonStyle(SecondaryButtonStyle())

// Outlined (border only)
Button("Options") { }
    .buttonStyle(OutlinedButtonStyle())

// Text only
Button("Skip") { }
    .buttonStyle(TextButtonStyle())

// Floating Action Button
Button { } label: {
    Image(systemName: "plus")
}
.fabStyle(size: .large)
```

## Cards & Surfaces

```swift
// Card with shadow
VStack {
    Text("Card Content")
}
.padding()
.cardStyle(elevation: 2)

// Surface background
VStack {
    Text("Content")
}
.surface()  // standard
.surface(variant: true)  // variant
```

## Icons

```swift
// Basic
Image(systemName: AppIcons.map)
    .foregroundColor(theme.primary)

// Themed (recommended)
ThemedIcon(AppIcons.map, size: 24, color: .primary)
ThemedIcon.large(AppIcons.dog, color: .secondary)

// Common Icons
AppIcons.startWalk    // play.circle.fill
AppIcons.map          // map.fill
AppIcons.dog          // pawprint.fill
AppIcons.location     // location.fill
AppIcons.park         // leaf.fill
AppIcons.close        // xmark
AppIcons.add          // plus
```

## Spacing

```swift
// Padding
.paddingXS()    // 8pt
.paddingSM()    // 12pt
.paddingMD()    // 16pt (standard)
.paddingLG()    // 24pt
.paddingXL()    // 32pt

// Custom spacing
.padding(Spacing.md)
VStack(spacing: Spacing.lg) { }

// Elevation
.elevation(1)   // subtle
.elevation(3)   // standard
.elevation(5)   // prominent
```

## Chips

```swift
HStack {
    Text("Selected")
        .chipStyle(isSelected: true)

    Text("Unselected")
        .chipStyle(isSelected: false)
}
```

## Common Patterns

### Screen Layout
```swift
struct MyScreen: View {
    @Environment(\.woofWalkTheme) var theme

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    headerSection
                    contentSection
                }
                .paddingMD()
            }
            .background(theme.background)
            .navigationTitle("Screen Title")
        }
    }
}
```

### List Item
```swift
HStack(spacing: Spacing.md) {
    ThemedIcon(AppIcons.dog, color: .primary)

    VStack(alignment: .leading, spacing: Spacing.xs) {
        Text("Dog Name")
            .titleMedium()
            .foregroundColor(theme.onSurface)

        Text("Breed")
            .bodySmall()
            .foregroundColor(theme.onSurfaceVariant)
    }

    Spacer()

    Image(systemName: "chevron.right")
        .foregroundColor(theme.onSurfaceVariant)
}
.padding()
.cardStyle()
```

### Form Input
```swift
VStack(alignment: .leading, spacing: Spacing.xs) {
    Text("Email")
        .bodySmall()
        .foregroundColor(theme.onSurfaceVariant)

    TextField("", text: $email)
        .font(AppTypography.bodyLarge)
        .foregroundColor(theme.onSurface)
        .padding()
        .background(theme.surfaceVariant)
        .cornerRadius(CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .stroke(theme.outline, lineWidth: 1)
        )
}
```

### Action Bar
```swift
HStack(spacing: Spacing.md) {
    Button("Cancel") { }
        .buttonStyle(OutlinedButtonStyle())

    Button("Start Walk") { }
        .buttonStyle(PrimaryButtonStyle())
}
.paddingMD()
.background(theme.surface)
.elevation(3)
```

## Color Migration Examples

```swift
// Before
.foregroundColor(.blue)
.background(Color.gray.opacity(0.1))

// After
.foregroundColor(theme.primary)
.background(theme.surfaceVariant)

// Before
.foregroundColor(.black)
.background(.white)

// After
.foregroundColor(theme.onSurface)
.background(theme.surface)
```

## Tips

1. **Always use semantic colors** (primary, surface) not raw colors (turquoise60)
2. **Dark mode is automatic** - don't check colorScheme manually
3. **Use theme environment** - `@Environment(\.woofWalkTheme) var theme`
4. **Prefer component styles** - PrimaryButtonStyle over custom styling
5. **Use spacing constants** - Spacing.md over hardcoded numbers
6. **Leverage ThemedIcon** - handles sizing and coloring
7. **Test in both modes** - Preview with `.preferredColorScheme(.dark)`

## Preview with Theme

```swift
struct MyView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MyView()
                .applyTheme()
                .preferredColorScheme(.light)

            MyView()
                .applyTheme()
                .preferredColorScheme(.dark)
        }
    }
}
```
