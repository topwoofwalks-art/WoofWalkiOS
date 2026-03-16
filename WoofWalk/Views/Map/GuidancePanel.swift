import SwiftUI
import MapKit

struct GuidancePanel: View {
    @ObservedObject var viewModel: GuidanceViewModel
    let onStop: () -> Void
    let onReroute: () -> Void

    var body: some View {
        Group {
            switch viewModel.guidanceState {
            case .idle:
                EmptyView()

            case .active(let instruction, let distance, let stepIndex, let totalSteps, let isOffRoute, let isRerouting, _, let remainingDist, let remainingTime):
                ActiveGuidanceView(
                    instruction: instruction,
                    distanceToNextStep: distance,
                    stepIndex: stepIndex,
                    totalSteps: totalSteps,
                    isOffRoute: isOffRoute,
                    isRerouting: isRerouting,
                    remainingDistance: remainingDist,
                    remainingTime: remainingTime,
                    onStop: onStop,
                    onReroute: onReroute
                )

            case .completed:
                CompletedGuidanceView(onDismiss: onStop)

            case .error(let message):
                ErrorGuidanceView(message: message, onDismiss: onStop)
            }
        }
    }
}

struct ActiveGuidanceView: View {
    let instruction: String
    let distanceToNextStep: Double
    let stepIndex: Int
    let totalSteps: Int
    let isOffRoute: Bool
    let isRerouting: Bool
    let remainingDistance: Double
    let remainingTime: Int
    let onStop: () -> Void
    let onReroute: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(instruction)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(2)

                    HStack(spacing: 12) {
                        Label(formatDistance(distanceToNextStep), systemImage: "arrow.right")
                        Label(formatDuration(remainingTime), systemImage: "clock")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))

                    if isRerouting {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.7)
                            Text("Rerouting...")
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                    } else if isOffRoute {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("Off Route")
                        }
                        .font(.caption)
                        .foregroundColor(.yellow)
                    }
                }

                Spacer()

                Button(action: onStop) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }

            HStack {
                ProgressView(value: Double(stepIndex), total: Double(totalSteps))
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    .frame(height: 4)

                Text("\(stepIndex + 1)/\(totalSteps)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }

            if isOffRoute && !isRerouting {
                Button(action: onReroute) {
                    HStack {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond")
                        Text("Reroute")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.2))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isOffRoute ? Color.red : Color.green)
                .shadow(radius: 8)
        )
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return String(format: "%.0fm", meters)
        } else {
            return String(format: "%.1fkm", meters / 1000)
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "< 1m"
        }
    }
}

struct CompletedGuidanceView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.green)

                Text("Destination Reached!")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }

            Button(action: onDismiss) {
                Text("Finish")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(radius: 8)
        )
    }
}

struct ErrorGuidanceView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(.red)

                Text("Navigation Error")
                    .font(.headline)
                    .fontWeight(.bold)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }

            Text(message)
                .font(.body)
                .foregroundColor(.secondary)

            Button(action: onDismiss) {
                Text("Dismiss")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(radius: 8)
        )
    }
}

struct OffRouteAlert: View {
    let onReroute: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("You're Off Route")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Would you like to recalculate your route?")
                        .font(.body)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 12) {
                Button(action: onContinue) {
                    Text("Continue Anyway")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                }

                Button(action: onReroute) {
                    Text("Reroute")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(radius: 8)
        )
    }
}

struct TurnByTurnView: View {
    let steps: [RouteStep]
    @Binding var currentStepIndex: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(index == currentStepIndex ? .blue : .gray.opacity(0.3))
                                .frame(width: 32, height: 32)

                            if index < currentStepIndex {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.white)
                            } else {
                                Text("\(index + 1)")
                                    .foregroundColor(.white)
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(step.htmlInstructions)
                                .font(.body)
                                .fontWeight(index == currentStepIndex ? .bold : .regular)

                            HStack {
                                Text(step.distance.text)
                                Text("•")
                                Text(step.duration.text)
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(index == currentStepIndex ? .blue.opacity(0.1) : .clear)
                    )
                }
            }
            .padding()
        }
    }
}
