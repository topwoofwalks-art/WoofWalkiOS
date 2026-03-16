import SwiftUI

struct ConfettiEffect: View {
    @State private var particles: [ConfettiParticle] = []

    let colors: [Color] = [.red, .blue, .green, .yellow, .orange, .purple, .pink, .turquoise60]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
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
        particles = (0..<60).map { _ in
            ConfettiParticle(
                color: colors.randomElement()!,
                size: CGFloat.random(in: 4...10),
                position: CGPoint(x: CGFloat.random(in: 0...size.width), y: -20),
                opacity: 1.0,
                velocity: CGFloat.random(in: 100...300)
            )
        }
    }

    private func animateParticles(in size: CGSize) {
        for i in particles.indices {
            let delay = Double.random(in: 0...1.5)
            withAnimation(.easeOut(duration: 2.5).delay(delay)) {
                particles[i].position.y = size.height + 20
                particles[i].position.x += CGFloat.random(in: -100...100)
                particles[i].opacity = 0
            }
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGFloat
    var position: CGPoint
    var opacity: Double
    var velocity: CGFloat
}
