import SwiftUI

enum DirectionType: String {
    case straight, slightLeft, slightRight, left, right, sharpLeft, sharpRight, uTurn, arrive, depart

    var systemImage: String {
        switch self {
        case .straight: return "arrow.up"
        case .slightLeft: return "arrow.up.left"
        case .slightRight: return "arrow.up.right"
        case .left: return "arrow.left"
        case .right: return "arrow.right"
        case .sharpLeft: return "arrow.down.left"
        case .sharpRight: return "arrow.down.right"
        case .uTurn: return "arrow.uturn.down"
        case .arrive: return "flag.checkered"
        case .depart: return "figure.walk"
        }
    }

    static func from(maneuver: String) -> DirectionType {
        switch maneuver.lowercased() {
        case let m where m.contains("left") && m.contains("sharp"): return .sharpLeft
        case let m where m.contains("right") && m.contains("sharp"): return .sharpRight
        case let m where m.contains("left") && m.contains("slight"): return .slightLeft
        case let m where m.contains("right") && m.contains("slight"): return .slightRight
        case let m where m.contains("left"): return .left
        case let m where m.contains("right"): return .right
        case let m where m.contains("u-turn") || m.contains("uturn"): return .uTurn
        case let m where m.contains("arrive") || m.contains("destination"): return .arrive
        case let m where m.contains("depart"): return .depart
        default: return .straight
        }
    }
}

struct DirectionIcon: View {
    let direction: DirectionType
    let size: CGFloat

    init(direction: DirectionType, size: CGFloat = 32) {
        self.direction = direction; self.size = size
    }

    var body: some View {
        Image(systemName: direction.systemImage)
            .font(.system(size: size, weight: .bold))
            .foregroundColor(.white)
            .frame(width: size * 2, height: size * 2)
            .background(Circle().fill(Color.turquoise60))
    }
}
