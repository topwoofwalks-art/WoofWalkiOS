import SwiftUI

// MARK: - Wiggle Modifier
/// Rotates content ±5 degrees with spring damping for playful emphasis
struct WiggleModifier: ViewModifier {
    @State private var isWiggling = false

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isWiggling ? 5 : 0))
            .animation(
                .interpolatingSpring(stiffness: 300, damping: 5),
                value: isWiggling
            )
            .onAppear {
                isWiggling = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isWiggling = false
                }
            }
    }
}

// MARK: - Shimmer Border Modifier
/// Animated gradient stroke that sweeps across the border
struct ShimmerBorderModifier: ViewModifier {
    let cornerRadius: CGFloat
    let lineWidth: CGFloat
    let colors: [Color]

    @State private var phase: CGFloat = 0

    init(
        cornerRadius: CGFloat = 16,
        lineWidth: CGFloat = 2,
        colors: [Color] = [.white.opacity(0.2), .white.opacity(0.8), .white.opacity(0.2)]
    ) {
        self.cornerRadius = cornerRadius
        self.lineWidth = lineWidth
        self.colors = colors
    }

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: colors,
                            startPoint: UnitPoint(x: phase - 0.5, y: 0),
                            endPoint: UnitPoint(x: phase + 0.5, y: 1)
                        ),
                        lineWidth: lineWidth
                    )
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 2.0)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1.5
                }
            }
    }
}

// MARK: - Gold Gradient Border Modifier
/// Static gold border for personal best cards and achievements
struct GoldGradientBorderModifier: ViewModifier {
    let cornerRadius: CGFloat
    let lineWidth: CGFloat

    init(cornerRadius: CGFloat = 16, lineWidth: CGFloat = 3) {
        self.cornerRadius = cornerRadius
        self.lineWidth = lineWidth
    }

    private let goldColors: [Color] = [
        Color(red: 1.0, green: 0.84, blue: 0.0),
        Color(red: 0.85, green: 0.65, blue: 0.13),
        Color(red: 1.0, green: 0.84, blue: 0.0),
        Color(red: 0.72, green: 0.53, blue: 0.04),
        Color(red: 1.0, green: 0.84, blue: 0.0),
    ]

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: goldColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: lineWidth
                    )
            )
    }
}

// MARK: - Scale Reveal Modifier
/// Scales content from 0.3 to 1.0 with a spring bounce on appear
struct ScaleRevealModifier: ViewModifier {
    let delay: Double
    @State private var revealed = false

    init(delay: Double = 0) {
        self.delay = delay
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(revealed ? 1.0 : 0.3)
            .opacity(revealed ? 1.0 : 0.0)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.6)
                .delay(delay),
                value: revealed
            )
            .onAppear {
                revealed = true
            }
    }
}

// MARK: - Animated Count Up
/// A number that counts from 0 to the target value over a duration
struct AnimatedCountUp: View {
    let target: Int
    let duration: Double
    let font: Font
    let color: Color

    @State private var current: Double = 0
    @State private var timer: Timer?

    init(
        target: Int,
        duration: Double = 1.0,
        font: Font = .title.bold(),
        color: Color = .primary
    ) {
        self.target = target
        self.duration = duration
        self.font = font
        self.color = color
    }

    var body: some View {
        Text("\(Int(current))")
            .font(font)
            .foregroundColor(color)
            .monospacedDigit()
            .onAppear { startCounting() }
            .onDisappear { timer?.invalidate() }
    }

    private func startCounting() {
        guard target > 0 else { return }
        let steps = 30.0
        let interval = duration / steps
        let increment = Double(target) / steps

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { t in
            current += increment
            if current >= Double(target) {
                current = Double(target)
                t.invalidate()
            }
        }
    }
}

// MARK: - View Extensions
extension View {
    func wiggle() -> some View {
        modifier(WiggleModifier())
    }

    func shimmerBorder(
        cornerRadius: CGFloat = 16,
        lineWidth: CGFloat = 2,
        colors: [Color] = [.white.opacity(0.2), .white.opacity(0.8), .white.opacity(0.2)]
    ) -> some View {
        modifier(ShimmerBorderModifier(cornerRadius: cornerRadius, lineWidth: lineWidth, colors: colors))
    }

    func goldBorder(cornerRadius: CGFloat = 16, lineWidth: CGFloat = 3) -> some View {
        modifier(GoldGradientBorderModifier(cornerRadius: cornerRadius, lineWidth: lineWidth))
    }

    func scaleReveal(delay: Double = 0) -> some View {
        modifier(ScaleRevealModifier(delay: delay))
    }
}
