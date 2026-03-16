import SwiftUI

// MARK: - Color Palette
// Ported from Android Material3 color scheme

extension Color {
    // MARK: - Turquoise (Primary)
    static let turquoise10 = Color(hex: 0x001F24)
    static let turquoise20 = Color(hex: 0x003640)
    static let turquoise30 = Color(hex: 0x004E5C)
    static let turquoise40 = Color(hex: 0x006878)
    static let turquoise50 = Color(hex: 0x008394)
    static let turquoise60 = Color(hex: 0x00A0B0)
    static let turquoise70 = Color(hex: 0x4DC0CD)
    static let turquoise80 = Color(hex: 0x7AD5DE)
    static let turquoise90 = Color(hex: 0xB3EAEF)
    static let turquoise95 = Color(hex: 0xD9F5F7)

    // MARK: - Orange (Secondary)
    static let orange10 = Color(hex: 0x2B1000)
    static let orange20 = Color(hex: 0x4A1D00)
    static let orange30 = Color(hex: 0x6C2C00)
    static let orange40 = Color(hex: 0x8E3B00)
    static let orange50 = Color(hex: 0x9F4300)
    static let orange60 = Color(hex: 0xFF6B35)
    static let orange70 = Color(hex: 0xFF8C63)
    static let orange80 = Color(hex: 0xFFAD8F)
    static let orange90 = Color(hex: 0xFFD4C2)
    static let orange95 = Color(hex: 0xFFEAE1)

    // MARK: - Neutral
    static let neutral10 = Color(hex: 0x1A1C1E)
    static let neutral20 = Color(hex: 0x2F3033)
    static let neutral30 = Color(hex: 0x454649)
    static let neutral40 = Color(hex: 0x5D5E62)
    static let neutral50 = Color(hex: 0x76777A)
    static let neutral60 = Color(hex: 0x909094)
    static let neutral70 = Color(hex: 0xABABAF)
    static let neutral80 = Color(hex: 0xC6C6CA)
    static let neutral90 = Color(hex: 0xE3E2E6)
    static let neutral95 = Color(hex: 0xF1F0F4)
    static let neutral99 = Color(hex: 0xFDFBFF)

    // MARK: - Neutral Variant
    static let neutralVariant10 = Color(hex: 0x161D1E)
    static let neutralVariant20 = Color(hex: 0x2B3133)
    static let neutralVariant30 = Color(hex: 0x414749)
    static let neutralVariant40 = Color(hex: 0x595F61)
    static let neutralVariant50 = Color(hex: 0x72787A)
    static let neutralVariant60 = Color(hex: 0x8C9294)
    static let neutralVariant70 = Color(hex: 0xA6ACAF)
    static let neutralVariant80 = Color(hex: 0xC2C7CA)
    static let neutralVariant90 = Color(hex: 0xDEE3E6)
    static let neutralVariant95 = Color(hex: 0xECF1F4)

    // MARK: - Error
    static let error10 = Color(hex: 0x410002)
    static let error20 = Color(hex: 0x690005)
    static let error30 = Color(hex: 0x93000A)
    static let error40 = Color(hex: 0xBA1A1A)
    static let error50 = Color(hex: 0xDE3730)
    static let error60 = Color(hex: 0xFF5449)
    static let error70 = Color(hex: 0xFF897D)
    static let error80 = Color(hex: 0xFFB4AB)
    static let error90 = Color(hex: 0xFFDAD6)
    static let error95 = Color(hex: 0xFFEDEA)

    // MARK: - Success
    static let success10 = Color(hex: 0x002106)
    static let success20 = Color(hex: 0x00390F)
    static let success30 = Color(hex: 0x005319)
    static let success40 = Color(hex: 0x006E23)
    static let success50 = Color(hex: 0x008A2E)
    static let success60 = Color(hex: 0x00A73A)
    static let success70 = Color(hex: 0x4CC76A)
    static let success80 = Color(hex: 0x7ADB8F)
    static let success90 = Color(hex: 0xB3F0BB)
    static let success95 = Color(hex: 0xD9F7DD)

    // MARK: - Helper for Hex Colors
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

// MARK: - Semantic Colors
struct AppColors {
    // Light Mode
    struct Light {
        static let primary = Color.turquoise60
        static let onPrimary = Color.neutral99
        static let primaryContainer = Color.turquoise90
        static let onPrimaryContainer = Color.turquoise10

        static let secondary = Color.orange60
        static let onSecondary = Color.neutral99
        static let secondaryContainer = Color.orange90
        static let onSecondaryContainer = Color.orange10

        static let tertiary = Color.success60
        static let onTertiary = Color.neutral99
        static let tertiaryContainer = Color.success90
        static let onTertiaryContainer = Color.success10

        static let error = Color.error60
        static let onError = Color.neutral99
        static let errorContainer = Color.error90
        static let onErrorContainer = Color.error10

        static let background = Color.neutral95
        static let onBackground = Color.neutral10

        static let surface = Color.neutral95
        static let onSurface = Color.neutral10
        static let surfaceVariant = Color.neutralVariant90
        static let onSurfaceVariant = Color.neutralVariant30

        static let outline = Color.neutralVariant50
        static let outlineVariant = Color.neutralVariant80

        static let inverseSurface = Color.neutral20
        static let inverseOnSurface = Color.neutral95
        static let inversePrimary = Color.turquoise80
    }

    // Dark Mode
    struct Dark {
        static let primary = Color.turquoise80
        static let onPrimary = Color.turquoise20
        static let primaryContainer = Color.turquoise30
        static let onPrimaryContainer = Color.turquoise90

        static let secondary = Color.orange80
        static let onSecondary = Color.orange20
        static let secondaryContainer = Color.orange30
        static let onSecondaryContainer = Color.orange90

        static let tertiary = Color.success80
        static let onTertiary = Color.success20
        static let tertiaryContainer = Color.success30
        static let onTertiaryContainer = Color.success90

        static let error = Color.error80
        static let onError = Color.error20
        static let errorContainer = Color.error30
        static let onErrorContainer = Color.error90

        static let background = Color.neutral10
        static let onBackground = Color.neutral90

        static let surface = Color.neutral10
        static let onSurface = Color.neutral90
        static let surfaceVariant = Color.neutralVariant30
        static let onSurfaceVariant = Color.neutralVariant80

        static let outline = Color.neutralVariant60
        static let outlineVariant = Color.neutralVariant30

        static let inverseSurface = Color.neutral90
        static let inverseOnSurface = Color.neutral20
        static let inversePrimary = Color.turquoise40
    }
}
