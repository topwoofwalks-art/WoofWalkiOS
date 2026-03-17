import SwiftUI

// MARK: - Confetti Variant
enum ConfettiVariant {
    case standard
    case gold
    case mini

    var particleCount: Int {
        switch self {
        case .standard: return 60
        case .gold: return 45
        case .mini: return 25
        }
    }

    var sizeRange: ClosedRange<CGFloat> {
        switch self {
        case .standard: return 4...10
        case .gold: return 5...12
        case .mini: return 3...6
        }
    }

    var colors: [Color] {
        switch self {
        case .standard:
            return [.red, .blue, .green, .yellow, .orange, .purple, .pink, .turquoise60]
        case .gold:
            return [
                Color(red: 1.0, green: 0.84, blue: 0.0),
                Color(red: 0.85, green: 0.65, blue: 0.13),
                Color(red: 1.0, green: 0.93, blue: 0.55),
                Color(red: 0.72, green: 0.53, blue: 0.04),
                .white,
                .yellow,
            ]
        case .mini:
            return [.red, .blue, .green, .yellow, .orange, .purple]
        }
    }

    var duration: Double {
        switch self {
        case .standard: return 2.5
        case .gold: return 3.0
        case .mini: return 1.8
        }
    }
}

// MARK: - Confetti Shape
enum ConfettiShape: CaseIterable {
    case circle
    case rectangle

    @ViewBuilder
    func view(color: Color, size: CGFloat, rotation: Double) -> some View {
        switch self {
        case .circle:
            Circle()
                .fill(color)
                .frame(width: size, height: size)
        case .rectangle:
            Rectangle()
                .fill(color)
                .frame(width: size * 0.6, height: size * 1.2)
                .rotationEffect(.degrees(rotation))
        }
    }
}

// MARK: - Confetti Particle
struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGFloat
    let shape: ConfettiShape
    let rotation: Double
    var position: CGPoint
    var opacity: Double
    var velocity: CGFloat
}

// MARK: - Confetti Effect
struct ConfettiEffect: View {
    let variant: ConfettiVariant

    @State private var particles: [ConfettiParticle] = []

    init(variant: ConfettiVariant = .standard) {
        self.variant = variant
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    particle.shape.view(
                        color: particle.color,
                        size: particle.size,
                        rotation: particle.rotation
                    )
                    .position(particle.position)
                    .opacity(particle.opacity)
                }
            }
            .onAppear {
                generateParticles(in: geo.size)
                animateParticles(in: geo.size)
            }
        }
    }

    private func generateParticles(in size: CGSize) {
        let colors = variant.colors
        let sizeRange = variant.sizeRange

        particles = (0..<variant.particleCount).map { _ in
            ConfettiParticle(
                color: colors.randomElement()!,
                size: CGFloat.random(in: sizeRange),
                shape: ConfettiShape.allCases.randomElement()!,
                rotation: Double.random(in: 0...360),
                position: CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: -20
                ),
                opacity: 1.0,
                velocity: CGFloat.random(in: 100...300)
            )
        }
    }

    private func animateParticles(in size: CGSize) {
        let maxDelay = variant == .mini ? 0.8 : 1.5

        for i in particles.indices {
            let delay = Double.random(in: 0...maxDelay)
            withAnimation(.easeOut(duration: variant.duration).delay(delay)) {
                particles[i].position.y = size.height + 20
                particles[i].position.x += CGFloat.random(in: -100...100)
                particles[i].opacity = 0
            }
        }
    }
}

#Preview("Standard") {
    ConfettiEffect(variant: .standard)
}

#Preview("Gold") {
    ZStack {
        Color.black.ignoresSafeArea()
        ConfettiEffect(variant: .gold)
    }
}

#Preview("Mini") {
    ConfettiEffect(variant: .mini)
}
