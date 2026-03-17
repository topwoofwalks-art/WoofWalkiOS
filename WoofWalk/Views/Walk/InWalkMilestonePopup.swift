import SwiftUI

enum WalkMilestone: Equatable {
    case distance(kilometers: Double)  // 1, 5, 10
    case duration(minutes: Int)        // 30, 60

    var icon: String {
        switch self {
        case .distance: return "trophy.fill"
        case .duration: return "clock.badge.checkmark.fill"
        }
    }

    var text: String {
        switch self {
        case .distance(let km):
            return km >= 1.0
                ? "\(Int(km)) km reached!"
                : String(format: "%.0f m reached!", km * 1000)
        case .duration(let min):
            return min >= 60
                ? "\(min / 60) hour walk!"
                : "\(min) min walk!"
        }
    }

    var color: Color {
        switch self {
        case .distance(let km):
            if km >= 10 { return .yellow }
            if km >= 5 { return .orange }
            return .green
        case .duration(let min):
            if min >= 60 { return .yellow }
            return .blue
        }
    }
}

struct InWalkMilestonePopup: View {
    let milestone: WalkMilestone
    let onDismiss: () -> Void

    @State private var isShowing = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: milestone.icon)
                .font(.title2)
                .foregroundColor(milestone.color)
                .wiggle()

            Text(milestone.text)
                .font(.headline)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        )
        .overlay(
            Capsule()
                .stroke(milestone.color.opacity(0.5), lineWidth: 1.5)
        )
        .offset(y: isShowing ? 0 : -120)
        .opacity(isShowing ? 1 : 0)
        .animation(
            .spring(response: 0.5, dampingFraction: 0.7),
            value: isShowing
        )
        .onAppear {
            HapticFeedback.milestone()
            isShowing = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeIn(duration: 0.25)) {
                    isShowing = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDismiss()
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        InWalkMilestonePopup(milestone: .distance(kilometers: 1), onDismiss: {})
        InWalkMilestonePopup(milestone: .duration(minutes: 30), onDismiss: {})
    }
}
