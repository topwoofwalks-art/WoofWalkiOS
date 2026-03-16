import SwiftUI

// MARK: - Spacing System
// Material Design spacing guidelines

enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    static let xxxl: CGFloat = 64
}

// MARK: - Corner Radius
enum CornerRadius {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let full: CGFloat = 9999
}

// MARK: - Elevation (Shadow)
enum Elevation {
    static func shadow(level: Int) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        switch level {
        case 1:
            return (Color.black.opacity(0.1), 2, 0, 1)
        case 2:
            return (Color.black.opacity(0.12), 4, 0, 2)
        case 3:
            return (Color.black.opacity(0.14), 6, 0, 3)
        case 4:
            return (Color.black.opacity(0.16), 8, 0, 4)
        case 5:
            return (Color.black.opacity(0.18), 12, 0, 6)
        default:
            return (Color.black.opacity(0.1), 2, 0, 1)
        }
    }
}

extension View {
    func elevation(_ level: Int) -> some View {
        let shadow = Elevation.shadow(level: level)
        return self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

// MARK: - Layout Helpers
extension View {
    func padding(_ edge: Edge.Set, _ spacing: CGFloat) -> some View {
        self.padding(edge, spacing)
    }

    func paddingXS() -> some View {
        self.padding(Spacing.xs)
    }

    func paddingSM() -> some View {
        self.padding(Spacing.sm)
    }

    func paddingMD() -> some View {
        self.padding(Spacing.md)
    }

    func paddingLG() -> some View {
        self.padding(Spacing.lg)
    }

    func paddingXL() -> some View {
        self.padding(Spacing.xl)
    }
}
