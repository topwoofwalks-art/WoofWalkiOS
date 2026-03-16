import SwiftUI

struct TourSpotlightView: View {
    let step: TourStep
    let highlightConfig: HighlightConfig?
    let onNext: () -> Void
    let onPrevious: () -> Void
    let onSkip: () -> Void

    @State private var pulseScale: CGFloat = 1.0
    @State private var dimOpacity: Double = 0.0

    var body: some View {
        ZStack {
            dimmedBackground

            if let config = highlightConfig {
                spotlightHighlight(config: config)
            }

            tourCard
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3)) {
                dimOpacity = 0.7
            }
            if highlightConfig?.pulseEnabled == true {
                startPulseAnimation()
            }
        }
    }

    private var dimmedBackground: some View {
        Color.black
            .opacity(dimOpacity)
            .ignoresSafeArea()
            .onTapGesture {
            }
    }

    private func spotlightHighlight(config: HighlightConfig) -> some View {
        ZStack {
            switch step.spotlightShape {
            case .circle:
                Circle()
                    .fill(Color.clear)
                    .frame(width: config.radius * 2, height: config.radius * 2)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.8), lineWidth: 2)
                            .scaleEffect(pulseScale)
                    )
                    .position(config.position)

            case .rectangle:
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: config.radius * 2, height: config.radius * 2)
                    .overlay(
                        Rectangle()
                            .stroke(Color.white.opacity(0.8), lineWidth: 2)
                            .scaleEffect(pulseScale)
                    )
                    .position(config.position)

            case .roundedRectangle(let cornerRadius):
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.clear)
                    .frame(width: config.radius * 2, height: config.radius * 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.white.opacity(0.8), lineWidth: 2)
                            .scaleEffect(pulseScale)
                    )
                    .position(config.position)
            }
        }
        .blendMode(.destinationOut)
    }

    private var tourCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(step.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text(step.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 12) {
                Button(action: onSkip) {
                    Text("Skip")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let current = highlightConfig, current.targetElement != nil {
                    Button(action: onPrevious) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.blue)
                    }
                    .disabled(false)
                }

                Button(action: onNext) {
                    HStack(spacing: 4) {
                        Text("Next")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: cardAlignment)
    }

    private var cardAlignment: Alignment {
        step.position.alignment
    }

    private func startPulseAnimation() {
        withAnimation(
            Animation.easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
        ) {
            pulseScale = 1.1
        }
    }
}

struct TourOverlayModifier: ViewModifier {
    @ObservedObject var coordinator: TourCoordinator

    func body(content: Content) -> some View {
        ZStack {
            content

            if coordinator.isTourActive(),
               let step = coordinator.getCurrentStep() {
                TourSpotlightView(
                    step: step,
                    highlightConfig: coordinator.highlightedElement,
                    onNext: { coordinator.nextStep() },
                    onPrevious: { coordinator.previousStep() },
                    onSkip: { coordinator.skipTour() }
                )
                .transition(.opacity)
                .zIndex(999)
            }

            if let message = coordinator.overlayMessage {
                VStack {
                    Text(message)
                        .font(.subheadline)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemBackground))
                                .shadow(radius: 5)
                        )
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1000)
            }

            ForEach(coordinator.activeAnnotations) { annotation in
                AnnotationView(annotation: annotation)
                    .position(annotation.position)
                    .zIndex(998)
            }
        }
    }
}

struct AnnotationView: View {
    let annotation: TourAnnotation

    var body: some View {
        Text(annotation.text)
            .font(.caption)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(annotation.style.backgroundColor)
            )
            .foregroundColor(annotation.style.textColor)
            .shadow(radius: 3)
    }
}

extension View {
    func tourOverlay(coordinator: TourCoordinator) -> some View {
        modifier(TourOverlayModifier(coordinator: coordinator))
    }
}

struct TourTargetModifier: ViewModifier {
    let targetId: String
    @ObservedObject var coordinator: TourCoordinator

    @State private var targetFrame: CGRect = .zero

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: TourTargetPreferenceKey.self,
                            value: [targetId: geometry.frame(in: .global)]
                        )
                }
            )
            .onPreferenceChange(TourTargetPreferenceKey.self) { preferences in
                if let frame = preferences[targetId],
                   coordinator.highlightedElement?.targetElement == targetId {
                    let center = CGPoint(
                        x: frame.midX,
                        y: frame.midY
                    )
                    coordinator.highlightElement(
                        targetElement: targetId,
                        position: center,
                        radius: max(frame.width, frame.height) / 2 + 10
                    )
                }
            }
    }
}

extension View {
    func tourTarget(id: String, coordinator: TourCoordinator) -> some View {
        modifier(TourTargetModifier(targetId: id, coordinator: coordinator))
    }
}

struct TourTargetPreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}
