import SwiftUI

// MARK: - Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.woofWalkTheme) var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.labelLarge)
            .foregroundColor(theme.onPrimary)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(theme.primary)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.woofWalkTheme) var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.labelLarge)
            .foregroundColor(theme.onSecondary)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(theme.secondary)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct OutlinedButtonStyle: ButtonStyle {
    @Environment(\.woofWalkTheme) var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.labelLarge)
            .foregroundColor(theme.primary)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(theme.outline, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct TextButtonStyle: ButtonStyle {
    @Environment(\.woofWalkTheme) var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.labelLarge)
            .foregroundColor(theme.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

// MARK: - Card Styles
struct CardModifier: ViewModifier {
    @Environment(\.woofWalkTheme) var theme
    let elevation: CGFloat

    func body(content: Content) -> some View {
        content
            .background(theme.surface)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: elevation, x: 0, y: elevation / 2)
    }
}

extension View {
    func cardStyle(elevation: CGFloat = 2) -> some View {
        self.modifier(CardModifier(elevation: elevation))
    }
}

// MARK: - Surface Styles
struct SurfaceModifier: ViewModifier {
    @Environment(\.woofWalkTheme) var theme
    let variant: Bool

    func body(content: Content) -> some View {
        content
            .background(variant ? theme.surfaceVariant : theme.surface)
    }
}

extension View {
    func surface(variant: Bool = false) -> some View {
        self.modifier(SurfaceModifier(variant: variant))
    }
}

// MARK: - Input Field Styles
struct TextFieldModifier: ViewModifier {
    @Environment(\.woofWalkTheme) var theme
    let label: String
    @Binding var text: String
    @FocusState var isFocused: Bool

    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(AppTypography.bodySmall)
                .foregroundColor(isFocused ? theme.primary : theme.onSurfaceVariant)

            content
                .font(AppTypography.bodyLarge)
                .foregroundColor(theme.onSurface)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.surfaceVariant)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isFocused ? theme.primary : theme.outline, lineWidth: isFocused ? 2 : 1)
                )
                .focused($isFocused)
        }
    }
}

// MARK: - Divider
struct ThemeDivider: View {
    @Environment(\.woofWalkTheme) var theme

    var body: some View {
        Rectangle()
            .fill(theme.outlineVariant)
            .frame(height: 1)
    }
}

// MARK: - Chip Styles
struct ChipModifier: ViewModifier {
    @Environment(\.woofWalkTheme) var theme
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .font(AppTypography.labelMedium)
            .foregroundColor(isSelected ? theme.onSecondaryContainer : theme.onSurfaceVariant)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? theme.secondaryContainer : theme.surfaceVariant)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.clear : theme.outline, lineWidth: 1)
            )
    }
}

extension View {
    func chipStyle(isSelected: Bool = false) -> some View {
        self.modifier(ChipModifier(isSelected: isSelected))
    }
}

// MARK: - FAB (Floating Action Button)
struct FABStyle: ButtonStyle {
    @Environment(\.woofWalkTheme) var theme
    let size: FABSize

    enum FABSize {
        case small, medium, large

        var padding: CGFloat {
            switch self {
            case .small: return 12
            case .medium: return 16
            case .large: return 20
            }
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(theme.onPrimaryContainer)
            .padding(size.padding)
            .background(
                Circle()
                    .fill(theme.primaryContainer)
                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

extension View {
    func fabStyle(size: FABStyle.FABSize = .medium) -> some View {
        self.buttonStyle(FABStyle(size: size))
    }
}

// MARK: - Badge (renamed to avoid conflict with Models/Badge.swift)
struct CountBadge: View {
    @Environment(\.woofWalkTheme) var theme
    let count: Int

    var body: some View {
        if count > 0 {
            Text("\(min(count, 99))\(count > 99 ? "+" : "")")
                .font(AppTypography.labelSmall)
                .foregroundColor(theme.onError)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(theme.error)
                )
        }
    }
}

// MARK: - Snackbar
struct Snackbar: View {
    @Environment(\.woofWalkTheme) var theme
    let message: String
    let action: (() -> Void)?
    let actionLabel: String?

    init(message: String, action: (() -> Void)? = nil, actionLabel: String? = nil) {
        self.message = message
        self.action = action
        self.actionLabel = actionLabel
    }

    var body: some View {
        HStack {
            Text(message)
                .font(AppTypography.bodyMedium)
                .foregroundColor(theme.inverseOnSurface)

            Spacer()

            if let action = action, let label = actionLabel {
                Button(action: action) {
                    Text(label)
                        .font(AppTypography.labelLarge)
                        .foregroundColor(theme.inversePrimary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.inverseSurface)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}
