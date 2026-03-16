import SwiftUI

struct ResponsiveLayout<Content: View>: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    let content: (Bool) -> Content

    init(@ViewBuilder content: @escaping (Bool) -> Content) {
        self.content = content
    }

    var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        content(isCompact)
    }
}

struct AdaptiveStack<Content: View>: View {
    let isVertical: Bool
    let spacing: CGFloat
    let content: () -> Content

    init(isVertical: Bool = true, spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.isVertical = isVertical; self.spacing = spacing; self.content = content
    }

    var body: some View {
        if isVertical {
            VStack(spacing: spacing, content: content)
        } else {
            HStack(spacing: spacing, content: content)
        }
    }
}

struct CompactCard: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding()
            .background(RoundedRectangle(cornerRadius: cornerRadius).fill(Color(.systemBackground)).shadow(radius: 1))
    }
}

extension View {
    func compactCard(cornerRadius: CGFloat = 12) -> some View {
        modifier(CompactCard(cornerRadius: cornerRadius))
    }
}
