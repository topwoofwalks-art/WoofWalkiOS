#if false
import SwiftUI

struct InstructionCard: View {
    let title: String
    let description: String
    let position: SpotlightPosition
    let stepNumber: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onPrevious: (() -> Void)?
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }

            navigationButtons
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        )
        .frame(maxWidth: .infinity, alignment: cardAlignment)
    }

    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if let previous = onPrevious {
                Button(action: previous) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }

            Spacer()

            Button(action: onNext) {
                HStack(spacing: 4) {
                    Text(stepNumber < totalSteps ? "Next" : "Done")
                    if stepNumber < totalSteps {
                        Image(systemName: "chevron.right")
                    }
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.green)
                )
            }
        }
    }

    private var cardAlignment: Alignment {
        switch position {
        case .topLeft, .topRight1, .topRight2, .topRight3:
            return .top
        case .bottomNavSocial, .bottomRight1, .bottomRight2, .bottomRight3:
            return .bottom
        case .center:
            return .center
        }
    }
}

struct PointerArrow: View {
    let direction: ArrowDirection

    var body: some View {
        Path { path in
            switch direction {
            case .up:
                path.move(to: CGPoint(x: 10, y: 0))
                path.addLine(to: CGPoint(x: 20, y: 10))
                path.addLine(to: CGPoint(x: 0, y: 10))
                path.closeSubpath()

            case .down:
                path.move(to: CGPoint(x: 10, y: 10))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 20, y: 0))
                path.closeSubpath()

            case .left:
                path.move(to: CGPoint(x: 0, y: 10))
                path.addLine(to: CGPoint(x: 10, y: 0))
                path.addLine(to: CGPoint(x: 10, y: 20))
                path.closeSubpath()

            case .right:
                path.move(to: CGPoint(x: 10, y: 10))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 20))
                path.closeSubpath()
            }
        }
        .fill(Color.white)
        .frame(width: 20, height: 20)
        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
    }
}

enum ArrowDirection {
    case up, down, left, right
}

struct InstructionCard_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            InstructionCard(
                title: "Welcome",
                description: "This is a tour of the app. Follow along to learn all the features!",
                position: .bottom,
                stepNumber: 1,
                totalSteps: 5,
                onNext: {},
                onPrevious: nil,
                onSkip: {}
            )
            .padding()
        }
    }
}
#endif
