import SwiftUI

struct LivestockFieldTourDemo: View {
    let onComplete: () -> Void
    let onSkip: () -> Void

    @State private var currentStep: Int = 0
    @State private var animatedPointCount: Int = 0
    @State private var dimOpacity: Double = 0.0

    private let steps: [LivestockTourStep] = [
        LivestockTourStep(
            title: "Livestock Fields",
            description: "Learn how to mark livestock fields to help keep dogs safe on walks!",
            showLivestockButton: false,
            highlightLivestockButton: false,
            showDrawingPoints: false,
            pointCount: 0,
            showSpeciesDialog: false,
            showCompletedField: false,
            selectedSpecies: [],
            isDangerous: false
        ),
        LivestockTourStep(
            title: "Find the Button",
            description: "Tap the livestock button on the bottom-left of the map to start",
            showLivestockButton: true,
            highlightLivestockButton: true,
            showDrawingPoints: false,
            pointCount: 0,
            showSpeciesDialog: false,
            showCompletedField: false,
            selectedSpecies: [],
            isDangerous: false
        ),
        LivestockTourStep(
            title: "View Existing Fields",
            description: "Nearby livestock fields will be shown on the map with colored boundaries.",
            showLivestockButton: true,
            highlightLivestockButton: false,
            showDrawingPoints: false,
            pointCount: 0,
            showSpeciesDialog: false,
            showCompletedField: false,
            selectedSpecies: [],
            isDangerous: false
        ),
        LivestockTourStep(
            title: "Enable Drawing Mode",
            description: "Tap 'Draw Field' to enter drawing mode. Then tap points on the map to outline the field boundary.",
            showLivestockButton: true,
            highlightLivestockButton: false,
            showDrawingPoints: true,
            pointCount: 1,
            showSpeciesDialog: false,
            showCompletedField: false,
            selectedSpecies: [],
            isDangerous: false
        ),
        LivestockTourStep(
            title: "Tap to Add Vertices",
            description: "Continue tapping to add points around the field boundary. Each tap adds a new vertex.",
            showLivestockButton: true,
            highlightLivestockButton: false,
            showDrawingPoints: true,
            pointCount: 3,
            showSpeciesDialog: false,
            showCompletedField: false,
            selectedSpecies: [],
            isDangerous: false
        ),
        LivestockTourStep(
            title: "Close the Polygon",
            description: "Add at least 3 points, then tap the green checkmark to finish and close the boundary.",
            showLivestockButton: true,
            highlightLivestockButton: false,
            showDrawingPoints: true,
            pointCount: 5,
            showSpeciesDialog: false,
            showCompletedField: false,
            selectedSpecies: [],
            isDangerous: false
        ),
        LivestockTourStep(
            title: "Select Species",
            description: "Choose which animals are in this field - you can select multiple!",
            showLivestockButton: false,
            highlightLivestockButton: false,
            showDrawingPoints: true,
            pointCount: 5,
            showSpeciesDialog: true,
            showCompletedField: false,
            selectedSpecies: [],
            isDangerous: false
        ),
        LivestockTourStep(
            title: "Mark as Hazardous",
            description: "If the field has aggressive animals, calving livestock, or bulls, mark it as hazardous.",
            showLivestockButton: false,
            highlightLivestockButton: false,
            showDrawingPoints: true,
            pointCount: 5,
            showSpeciesDialog: true,
            showCompletedField: false,
            selectedSpecies: [.cattle],
            isDangerous: true
        ),
        LivestockTourStep(
            title: "Submit the Field",
            description: "Tap 'Save Field' to submit. The field is now saved and visible to other dog walkers. Great job!",
            showLivestockButton: false,
            highlightLivestockButton: false,
            showDrawingPoints: true,
            pointCount: 5,
            showSpeciesDialog: false,
            showCompletedField: true,
            selectedSpecies: [.cattle],
            isDangerous: true
        )
    ]

    var body: some View {
        ZStack {
            Color.black
                .opacity(dimOpacity)
                .ignoresSafeArea()

            if currentStep < steps.count {
                let step = steps[currentStep]

                if step.showDrawingPoints && animatedPointCount > 0 {
                    DemoFieldDrawing(
                        pointCount: animatedPointCount,
                        completed: step.showCompletedField,
                        species: step.selectedSpecies,
                        isDangerous: step.isDangerous
                    )
                }

                if step.showLivestockButton {
                    DemoLivestockButton(highlighted: step.highlightLivestockButton)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .padding(.leading, 16)
                        .padding(.bottom, 200)
                }

                if step.showSpeciesDialog {
                    DemoSpeciesDialog(
                        selectedSpecies: step.selectedSpecies,
                        isDangerous: step.isDangerous
                    )
                }

                LivestockTourOverlayContent(
                    step: step,
                    currentStep: currentStep,
                    totalSteps: steps.count,
                    onNext: nextStep,
                    onPrevious: previousStep,
                    onSkip: onSkip
                )
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3)) {
                dimOpacity = 0.7
            }
        }
        .onChange(of: currentStep) { _, newStep in
            if newStep < steps.count {
                let step = steps[newStep]
                if step.showDrawingPoints && step.pointCount > animatedPointCount {
                    animatePoints(to: step.pointCount)
                }
            }
        }
    }

    private func animatePoints(to count: Int) {
        Task {
            for i in animatedPointCount..<count {
                try? await Task.sleep(nanoseconds: 300_000_000)
                animatedPointCount = i + 1
            }
        }
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
            if currentStep < steps.count {
                animatedPointCount = steps[currentStep].pointCount
            }
        }
    }
}

struct LivestockTourStep {
    let title: String
    let description: String
    let showLivestockButton: Bool
    let highlightLivestockButton: Bool
    let showDrawingPoints: Bool
    let pointCount: Int
    let showSpeciesDialog: Bool
    let showCompletedField: Bool
    let selectedSpecies: [LivestockSpecies]
    let isDangerous: Bool
}

struct LivestockTourOverlayContent: View {
    let step: LivestockTourStep
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onPrevious: () -> Void
    let onSkip: () -> Void

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

            InstructionCard(
                title: step.title,
                description: step.description,
                position: .bottom,
                stepNumber: currentStep + 1,
                totalSteps: totalSteps,
                onNext: onNext,
                onPrevious: currentStep > 0 ? onPrevious : nil,
                onSkip: onSkip
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
}

struct DemoLivestockButton: View {
    let highlighted: Bool
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            if highlighted {
                Circle()
                    .fill(Color.green.opacity(0.3))
                    .frame(width: 80, height: 80)
                    .scaleEffect(pulseScale)

                Circle()
                    .stroke(Color.green, lineWidth: 3)
                    .frame(width: 80, height: 80)
            }

            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.primary)
                )
        }
        .onAppear {
            if highlighted {
                withAnimation(
                    Animation.easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true)
                ) {
                    pulseScale = 1.15
                }
            }
        }
    }
}

struct DemoFieldDrawing: View {
    let pointCount: Int
    let completed: Bool
    let species: [LivestockSpecies]
    let isDangerous: Bool

    private let demoPoints: [CGPoint] = [
        CGPoint(x: 0.3, y: 0.4),
        CGPoint(x: 0.6, y: 0.35),
        CGPoint(x: 0.7, y: 0.5),
        CGPoint(x: 0.65, y: 0.65),
        CGPoint(x: 0.35, y: 0.6)
    ]

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let actualPoints = demoPoints.prefix(pointCount).map { normalized in
                CGPoint(
                    x: size.width * normalized.x,
                    y: size.height * normalized.y
                )
            }

            Canvas { context, canvasSize in
                if actualPoints.count >= 3 {
                    var path = Path()
                    path.move(to: actualPoints[0])
                    for i in 1..<actualPoints.count {
                        path.addLine(to: actualPoints[i])
                    }
                    path.closeSubpath()

                    let fillColor = completed
                        ? (isDangerous ? Color.red.opacity(0.3) : Color.green.opacity(0.3))
                        : Color.blue.opacity(0.3)

                    context.fill(path, with: .color(fillColor))

                    let strokeColor = completed
                        ? (isDangerous ? Color.red : Color.green)
                        : Color.blue

                    context.stroke(path, with: .color(strokeColor), lineWidth: 3)
                } else if actualPoints.count == 2 {
                    var path = Path()
                    path.move(to: actualPoints[0])
                    path.addLine(to: actualPoints[1])
                    context.stroke(path, with: .color(.blue), lineWidth: 3)
                }

                for point in actualPoints {
                    let circlePath = Path(ellipseIn: CGRect(
                        x: point.x - 8,
                        y: point.y - 8,
                        width: 16,
                        height: 16
                    ))
                    context.fill(circlePath, with: .color(.white))

                    let innerCirclePath = Path(ellipseIn: CGRect(
                        x: point.x - 6,
                        y: point.y - 6,
                        width: 12,
                        height: 12
                    ))
                    context.fill(innerCirclePath, with: .color(.blue))
                }

                if completed && !actualPoints.isEmpty {
                    let centerX = actualPoints.map { $0.x }.reduce(0, +) / CGFloat(actualPoints.count)
                    let centerY = actualPoints.map { $0.y }.reduce(0, +) / CGFloat(actualPoints.count)
                    let center = CGPoint(x: centerX, y: centerY)

                    let outerCirclePath = Path(ellipseIn: CGRect(
                        x: center.x - 24,
                        y: center.y - 24,
                        width: 48,
                        height: 48
                    ))
                    context.fill(outerCirclePath, with: .color(.white))

                    let iconCirclePath = Path(ellipseIn: CGRect(
                        x: center.x - 20,
                        y: center.y - 20,
                        width: 40,
                        height: 40
                    ))
                    let iconColor = isDangerous ? Color.red : Color.green
                    context.fill(iconCirclePath, with: .color(iconColor))
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct DemoSpeciesDialog: View {
    let selectedSpecies: [LivestockSpecies]
    let isDangerous: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text("New Livestock Field")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)

            VStack(alignment: .leading, spacing: 12) {
                Text("Select Livestock Species")
                    .font(.headline)

                VStack(spacing: 8) {
                    ForEach(LivestockSpecies.allCases, id: \.self) { species in
                        HStack {
                            Text(species.displayName)
                                .font(.body)

                            Spacer()

                            if selectedSpecies.contains(species) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedSpecies.contains(species)
                                    ? Color.green.opacity(0.1)
                                    : Color.clear)
                        )
                    }
                }

                Divider()
                    .padding(.vertical, 8)

                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(isDangerous ? .red : .gray)

                    Text("Hazardous Field")
                        .font(.body)

                    Spacer()

                    if isDangerous {
                        Image(systemName: "checkmark.square.fill")
                            .foregroundColor(.red)
                    } else {
                        Image(systemName: "square")
                            .foregroundColor(.gray)
                    }
                }

                Text("Mark as hazardous if field contains aggressive livestock, calving animals, or bulls")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            .padding()

            HStack(spacing: 12) {
                Button(action: {}) {
                    Text("Cancel")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue, lineWidth: 1)
                        )
                }

                Button(action: {}) {
                    Text("Save Field")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedSpecies.isEmpty ? Color.gray : Color.green)
                        )
                }
                .disabled(selectedSpecies.isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
        .padding(.horizontal, 32)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

struct LivestockFieldTourDemo_Previews: PreviewProvider {
    static var previews: some View {
        LivestockFieldTourDemo(
            onComplete: {
                print("Tour completed")
            },
            onSkip: {
                print("Tour skipped")
            }
        )
    }
}
