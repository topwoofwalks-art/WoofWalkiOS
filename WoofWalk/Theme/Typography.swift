import SwiftUI

// MARK: - Typography System
// Ported from Android Material3 typography

struct AppTypography {
    // MARK: - Display
    static let displayLarge = Font.system(size: 57, weight: .regular)
    static let displayMedium = Font.system(size: 45, weight: .regular)
    static let displaySmall = Font.system(size: 36, weight: .regular)

    // MARK: - Headline
    static let headlineLarge = Font.system(size: 32, weight: .regular)
    static let headlineMedium = Font.system(size: 28, weight: .regular)
    static let headlineSmall = Font.system(size: 24, weight: .regular)

    // MARK: - Title
    static let titleLarge = Font.system(size: 22, weight: .semibold)
    static let titleMedium = Font.system(size: 16, weight: .semibold)
    static let titleSmall = Font.system(size: 14, weight: .medium)

    // MARK: - Body
    static let bodyLarge = Font.system(size: 16, weight: .regular)
    static let bodyMedium = Font.system(size: 14, weight: .regular)
    static let bodySmall = Font.system(size: 12, weight: .regular)

    // MARK: - Label
    static let labelLarge = Font.system(size: 14, weight: .medium)
    static let labelMedium = Font.system(size: 12, weight: .medium)
    static let labelSmall = Font.system(size: 11, weight: .medium)
}

// MARK: - Text Styles
extension Text {
    func displayLarge() -> Text {
        self.font(AppTypography.displayLarge)
    }

    func displayMedium() -> Text {
        self.font(AppTypography.displayMedium)
    }

    func displaySmall() -> Text {
        self.font(AppTypography.displaySmall)
    }

    func headlineLarge() -> Text {
        self.font(AppTypography.headlineLarge)
    }

    func headlineMedium() -> Text {
        self.font(AppTypography.headlineMedium)
    }

    func headlineSmall() -> Text {
        self.font(AppTypography.headlineSmall)
    }

    func titleLarge() -> Text {
        self.font(AppTypography.titleLarge)
    }

    func titleMedium() -> Text {
        self.font(AppTypography.titleMedium)
    }

    func titleSmall() -> Text {
        self.font(AppTypography.titleSmall)
    }

    func bodyLarge() -> Text {
        self.font(AppTypography.bodyLarge)
    }

    func bodyMedium() -> Text {
        self.font(AppTypography.bodyMedium)
    }

    func bodySmall() -> Text {
        self.font(AppTypography.bodySmall)
    }

    func labelLarge() -> Text {
        self.font(AppTypography.labelLarge)
    }

    func labelMedium() -> Text {
        self.font(AppTypography.labelMedium)
    }

    func labelSmall() -> Text {
        self.font(AppTypography.labelSmall)
    }
}

// MARK: - Line Heights
extension View {
    func lineSpacing(_ spacing: CGFloat) -> some View {
        self.modifier(LineSpacingModifier(spacing: spacing))
    }
}

struct LineSpacingModifier: ViewModifier {
    let spacing: CGFloat

    func body(content: Content) -> some View {
        content.lineSpacing(spacing)
    }
}
