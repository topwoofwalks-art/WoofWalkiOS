#if false
import SwiftUI

struct TourOverlay: View {
    let currentStep: TourStep
    let stepNumber: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onPrevious: () -> Void
    let onSkip: () -> Void

    @State private var dimOpacity: Double = 0.0
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            dimmedBackground

            VStack {
                progressIndicator

                Spacer()

                InstructionCard(
                    title: currentStep.title,
                    description: currentStep.description,
                    position: currentStep.position,
                    stepNumber: stepNumber,
                    totalSteps: totalSteps,
                    onNext: onNext,
                    onPrevious: stepNumber > 1 ? onPrevious : nil,
                    onSkip: onSkip
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3)) {
                dimOpacity = 0.7
            }
            startPulseAnimation()
        }
    }

    private var dimmedBackground: some View {
        Color.black
            .opacity(dimOpacity)
            .ignoresSafeArea()
    }

    private var progressIndicator: some View {
        HStack {
            Text("Step \(stepNumber) of \(totalSteps)")
                .font(.caption)
                .foregroundColor(.white)

            Spacer()

            Button(action: onSkip) {
                Text("Skip Tour")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    private func startPulseAnimation() {
        withAnimation(
            Animation.easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
        ) {
            pulseScale = 1.15
        }
    }
}

struct SpotlightModifier: ViewModifier {
    let isHighlighted: Bool
    let shape: SpotlightShape
    @State private var pulseScale: CGFloat = 1.0

    func body(content: Content) -> some View {
        ZStack {
            content

            if isHighlighted {
                spotlightOverlay
            }
        }
        .onAppear {
            if isHighlighted {
                startPulseAnimation()
            }
        }
    }

    private var spotlightOverlay: some View {
        Group {
            switch shape {
            case .circle:
                Circle()
                    .stroke(Color.green, lineWidth: 3)
                    .scaleEffect(pulseScale)
                    .overlay(
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .scaleEffect(pulseScale * 1.2)
                    )

            case .rectangle:
                Rectangle()
                    .stroke(Color.green, lineWidth: 3)
                    .scaleEffect(pulseScale)
                    .overlay(
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .scaleEffect(pulseScale * 1.2)
                    )

            case .roundedRectangle(let cornerRadius):
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.green, lineWidth: 3)
                    .scaleEffect(pulseScale)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Color.white.opacity(0.1))
                            .scaleEffect(pulseScale * 1.2)
                    )
            }
        }
    }

    private func startPulseAnimation() {
        withAnimation(
            Animation.easeInOut(duration: 1.0)
                .repeatForever(autoreverses: true)
        ) {
            pulseScale = 1.15
        }
    }
}

extension View {
    func tourSpotlight(
        id: String,
        isHighlighted: Bool,
        shape: SpotlightShape = .circle
    ) -> some View {
        modifier(SpotlightModifier(
            isHighlighted: isHighlighted,
            shape: shape
        ))
    }
}

struct TourOverlay_Previews: PreviewProvider {
    static var previews: some View {
        TourOverlay(
            currentStep: TourStep(
                id: "preview",
                title: "Welcome to WoofWalk",
                description: "Let's show you around the app and its amazing features!",
                position: .center
            ),
            stepNumber: 1,
            totalSteps: 5,
            onNext: {},
            onPrevious: {},
            onSkip: {}
        )
    }
}

#endif
