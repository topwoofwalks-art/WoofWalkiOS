import SwiftUI

// MARK: - Theme Configuration
struct WoofWalkTheme {
    let colorScheme: ColorScheme

    var primary: Color {
        colorScheme == .dark ? AppColors.Dark.primary : AppColors.Light.primary
    }

    var onPrimary: Color {
        colorScheme == .dark ? AppColors.Dark.onPrimary : AppColors.Light.onPrimary
    }

    var primaryContainer: Color {
        colorScheme == .dark ? AppColors.Dark.primaryContainer : AppColors.Light.primaryContainer
    }

    var onPrimaryContainer: Color {
        colorScheme == .dark ? AppColors.Dark.onPrimaryContainer : AppColors.Light.onPrimaryContainer
    }

    var secondary: Color {
        colorScheme == .dark ? AppColors.Dark.secondary : AppColors.Light.secondary
    }

    var onSecondary: Color {
        colorScheme == .dark ? AppColors.Dark.onSecondary : AppColors.Light.onSecondary
    }

    var secondaryContainer: Color {
        colorScheme == .dark ? AppColors.Dark.secondaryContainer : AppColors.Light.secondaryContainer
    }

    var onSecondaryContainer: Color {
        colorScheme == .dark ? AppColors.Dark.onSecondaryContainer : AppColors.Light.onSecondaryContainer
    }

    var tertiary: Color {
        colorScheme == .dark ? AppColors.Dark.tertiary : AppColors.Light.tertiary
    }

    var onTertiary: Color {
        colorScheme == .dark ? AppColors.Dark.onTertiary : AppColors.Light.onTertiary
    }

    var tertiaryContainer: Color {
        colorScheme == .dark ? AppColors.Dark.tertiaryContainer : AppColors.Light.tertiaryContainer
    }

    var onTertiaryContainer: Color {
        colorScheme == .dark ? AppColors.Dark.onTertiaryContainer : AppColors.Light.onTertiaryContainer
    }

    var error: Color {
        colorScheme == .dark ? AppColors.Dark.error : AppColors.Light.error
    }

    var onError: Color {
        colorScheme == .dark ? AppColors.Dark.onError : AppColors.Light.onError
    }

    var errorContainer: Color {
        colorScheme == .dark ? AppColors.Dark.errorContainer : AppColors.Light.errorContainer
    }

    var onErrorContainer: Color {
        colorScheme == .dark ? AppColors.Dark.onErrorContainer : AppColors.Light.onErrorContainer
    }

    var background: Color {
        colorScheme == .dark ? AppColors.Dark.background : AppColors.Light.background
    }

    var onBackground: Color {
        colorScheme == .dark ? AppColors.Dark.onBackground : AppColors.Light.onBackground
    }

    var surface: Color {
        colorScheme == .dark ? AppColors.Dark.surface : AppColors.Light.surface
    }

    var onSurface: Color {
        colorScheme == .dark ? AppColors.Dark.onSurface : AppColors.Light.onSurface
    }

    var surfaceVariant: Color {
        colorScheme == .dark ? AppColors.Dark.surfaceVariant : AppColors.Light.surfaceVariant
    }

    var onSurfaceVariant: Color {
        colorScheme == .dark ? AppColors.Dark.onSurfaceVariant : AppColors.Light.onSurfaceVariant
    }

    var outline: Color {
        colorScheme == .dark ? AppColors.Dark.outline : AppColors.Light.outline
    }

    var outlineVariant: Color {
        colorScheme == .dark ? AppColors.Dark.outlineVariant : AppColors.Light.outlineVariant
    }

    var inverseSurface: Color {
        colorScheme == .dark ? AppColors.Dark.inverseSurface : AppColors.Light.inverseSurface
    }

    var inverseOnSurface: Color {
        colorScheme == .dark ? AppColors.Dark.inverseOnSurface : AppColors.Light.inverseOnSurface
    }

    var inversePrimary: Color {
        colorScheme == .dark ? AppColors.Dark.inversePrimary : AppColors.Light.inversePrimary
    }
}

// MARK: - Environment Key
struct ThemeKey: EnvironmentKey {
    static let defaultValue: WoofWalkTheme = WoofWalkTheme(colorScheme: .light)
}

extension EnvironmentValues {
    var woofWalkTheme: WoofWalkTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// MARK: - Theme Modifier
struct ThemedView<Content: View>: View {
    @Environment(\.colorScheme) var systemColorScheme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .environment(\.woofWalkTheme, WoofWalkTheme(colorScheme: systemColorScheme))
    }
}

extension View {
    func applyTheme() -> some View {
        ThemedView {
            self
        }
    }
}
