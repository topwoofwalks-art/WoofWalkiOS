import SwiftUI

struct MapTourDemo: View {
    let onComplete: () -> Void
    let onSkip: () -> Void

    @State private var currentStep: Int = -1
    @State private var dimOpacity: Double = 0.0

    private let steps: [MapTourStep] = [
        MapTourStep(
            title: "Welcome to WoofWalk",
            description: "Let's show you around the map and its amazing features!",
            highlightedButton: nil
        ),
        MapTourStep(
            title: "Zoom Controls",
            description: "Use pinch gestures to zoom in and out on the map, or double-tap to zoom.",
            highlightedButton: nil
        ),
        MapTourStep(
            title: "My Location",
            description: "Tap this button to center the map on your current location.",
            highlightedButton: .location
        ),
        MapTourStep(
            title: "Search",
            description: "Find dog parks, water fountains, and pet-friendly places nearby.",
            highlightedButton: .search
        ),
        MapTourStep(
            title: "Filter",
            description: "Show only the markers you care about. Hide the rest for a cleaner map.",
            highlightedButton: .filter
        ),
        MapTourStep(
            title: "Points of Interest",
            description: "Green markers show dog parks, blue markers show water fountains, and other colors indicate different amenities.",
            highlightedButton: nil
        ),
        MapTourStep(
            title: "Add New Place",
            description: "Long press anywhere on the map to add a new point of interest for the community.",
            highlightedButton: nil
        ),
        MapTourStep(
            title: "Start Walk",
            description: "Ready to walk? Tap this button to begin tracking your route and earning paw points!",
            highlightedButton: .startWalk
        ),
        MapTourStep(
            title: "Random Walk",
            description: "Tap anywhere on the map to plan a random walk route. Perfect for exploring new areas!",
            highlightedButton: nil
        ),
        MapTourStep(
            title: "Route Preview",
            description: "Before starting, you'll see a preview of your route with distance and estimated time.",
            highlightedButton: nil
        ),
        MapTourStep(
            title: "Walking Mode",
            description: "While walking, your route is tracked in real-time. Your path appears in green on the map.",
            highlightedButton: nil
        ),
        MapTourStep(
            title: "Navigation Guidance",
            description: "Turn-by-turn directions will guide you along your route. Audio cues help you navigate hands-free.",
            highlightedButton: nil
        ),
        MapTourStep(
            title: "Walk Complete",
            description: "When you finish, view your stats: distance, time, calories burned, and paw points earned!",
            highlightedButton: nil
        )
    ]

    var body: some View {
        ZStack {
            Color.black
                .opacity(dimOpacity)
                .ignoresSafeArea()
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        dimOpacity = 0.7
                    }
                }

            if currentStep == -1 {
                welcomeScreen
            } else if currentStep >= 0 && currentStep < steps.count {
                MapTourOverlayContent(
                    step: steps[currentStep],
                    currentStep: currentStep,
                    totalSteps: steps.count,
                    onNext: nextStep,
                    onPrevious: previousStep,
                    onSkip: onSkip
                )
            }
        }
        .onAppear {
            currentStep = -1
        }
    }

    private var welcomeScreen: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("Welcome to")
                    .font(.title)
                    .foregroundColor(.white)

                Text("WoofWalk")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.green)

                Text("Let's show you around!")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.9))
            }

            VStack(spacing: 16) {
                Button(action: { currentStep = 0 }) {
                    Text("Start Tour")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: 200)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.green)
                        )
                }

                Button(action: onSkip) {
                    Text("Skip")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding()
    }

    private func nextStep() {
        if currentStep < steps.count - 1 {
            withAnimation {
                currentStep += 1
            }
        } else {
            onComplete()
        }
    }

    private func previousStep() {
        if currentStep > 0 {
            withAnimation {
                currentStep -= 1
            }
        }
    }
}

struct MapTourStep {
    let title: String
    let description: String
    let highlightedButton: MapButtonType?
}

enum MapButtonType {
    case search
    case filter
    case location
    case startWalk
    case addPlace
}

struct MapTourOverlayContent: View {
    let step: MapTourStep
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onPrevious: () -> Void
    let onSkip: () -> Void

    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        VStack {
            HStack {
                Text("\(currentStep + 1) of \(totalSteps)")
                    .font(.caption)
                    .foregroundColor(.white)

                Spacer()

                Button(action: onSkip) {
                    Text("Skip")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()

            if let buttonType = step.highlightedButton {
                highlightIndicator(for: buttonType)
            }

            Spacer()

            InstructionCard(
                title: step.title,
                description: step.description,
                position: cardPosition,
                stepNumber: currentStep + 1,
                totalSteps: totalSteps,
                onNext: onNext,
                onPrevious: currentStep > 0 ? onPrevious : nil,
                onSkip: onSkip
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .onAppear {
            startPulseAnimation()
        }
    }

    private var cardPosition: SpotlightPosition {
        if let buttonType = step.highlightedButton {
            switch buttonType {
            case .search, .filter, .location:
                return .topRight1
            case .startWalk:
                return .bottomRight1
            case .addPlace:
                return .bottomRight2
            }
        }
        return .center
    }

    @ViewBuilder
    private func highlightIndicator(for buttonType: MapButtonType) -> some View {
        VStack {
            switch buttonType {
            case .search, .filter, .location:
                HStack {
                    Spacer()
                    Circle()
                        .stroke(Color.green, lineWidth: 3)
                        .frame(width: 56, height: 56)
                        .scaleEffect(pulseScale)
                        .padding(.trailing, 16)
                        .padding(.top, topPadding(for: buttonType))
                }
                Spacer()

            case .startWalk, .addPlace:
                Spacer()
                HStack {
                    Spacer()
                    Circle()
                        .stroke(Color.green, lineWidth: 3)
                        .frame(width: 56, height: 56)
                        .scaleEffect(pulseScale)
                        .padding(.trailing, 16)
                        .padding(.bottom, bottomPadding(for: buttonType))
                }
            }
        }
    }

    private func topPadding(for type: MapButtonType) -> CGFloat {
        switch type {
        case .search:
            return 60
        case .filter:
            return 130
        case .location:
            return 200
        default:
            return 0
        }
    }

    private func bottomPadding(for type: MapButtonType) -> CGFloat {
        switch type {
        case .startWalk:
            return 200
        case .addPlace:
            return 270
        default:
            return 0
        }
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

struct MapTourDemo_Previews: PreviewProvider {
    static var previews: some View {
        MapTourDemo(
            onComplete: {
                print("Tour completed")
            },
            onSkip: {
                print("Tour skipped")
            }
        )
    }
}
