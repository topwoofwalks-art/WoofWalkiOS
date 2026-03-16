import Foundation
import SwiftUI

enum TourType: String, Codable {
    case initialWalkthrough = "INITIAL_WALKTHROUGH"
    case socialNavigationDemo = "SOCIAL_NAVIGATION_DEMO"
    case fieldDrawingDemo = "FIELD_DRAWING_DEMO"
    case mapFeaturesDemo = "MAP_FEATURES_DEMO"
    case custom = "CUSTOM"
}

enum TourState: String, Codable {
    case notStarted = "NOT_STARTED"
    case inProgress = "IN_PROGRESS"
    case paused = "PAUSED"
    case completed = "COMPLETED"
    case skipped = "SKIPPED"
}

enum SpotlightShape {
    case circle
    case rectangle
    case roundedRectangle(cornerRadius: CGFloat)
}

enum SpotlightPosition {
    case topLeft
    case topRight1
    case topRight2
    case topRight3
    case bottomNavSocial
    case bottomRight1
    case bottomRight2
    case bottomRight3
    case center

    var alignment: Alignment {
        switch self {
        case .topLeft: return .topLeading
        case .topRight1, .topRight2, .topRight3: return .topTrailing
        case .bottomNavSocial: return .bottom
        case .bottomRight1, .bottomRight2, .bottomRight3: return .bottomTrailing
        case .center: return .center
        }
    }
}

protocol TourAction {
    func execute()
}

struct NavigateToSocialAction: TourAction {
    func execute() {}
}

struct NavigateToMapAction: TourAction {
    func execute() {}
}

struct EnableDrawingModeAction: TourAction {
    func execute() {}
}

struct DisableDrawingModeAction: TourAction {
    func execute() {}
}

struct HighlightElementAction: TourAction {
    let elementId: String
    func execute() {}
}

struct ShowOverlayAction: TourAction {
    let message: String
    func execute() {}
}

struct TourStep: Identifiable {
    let id: String
    let title: String
    let description: String
    let targetViewId: String?
    let spotlightShape: SpotlightShape
    let position: SpotlightPosition
    let action: (any TourAction)?
    let metadata: [String: Any]

    init(
        id: String,
        title: String,
        description: String,
        targetViewId: String? = nil,
        spotlightShape: SpotlightShape = .circle,
        position: SpotlightPosition = .center,
        action: (any TourAction)? = nil,
        metadata: [String: Any] = [:]
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.targetViewId = targetViewId
        self.spotlightShape = spotlightShape
        self.position = position
        self.action = action
        self.metadata = metadata
    }
}

struct TourProgress {
    let tourType: TourType
    var currentStepIndex: Int
    let totalSteps: Int
    var state: TourState
    var completedSteps: Set<String>

    init(
        tourType: TourType,
        currentStepIndex: Int = -1,
        totalSteps: Int = 0,
        state: TourState = .notStarted,
        completedSteps: Set<String> = []
    ) {
        self.tourType = tourType
        self.currentStepIndex = currentStepIndex
        self.totalSteps = totalSteps
        self.state = state
        self.completedSteps = completedSteps
    }
}

struct HighlightConfig {
    let position: CGPoint
    let radius: CGFloat
    let pulseEnabled: Bool
    let targetElement: String?

    init(
        position: CGPoint = .zero,
        radius: CGFloat = 40.0,
        pulseEnabled: Bool = true,
        targetElement: String? = nil
    ) {
        self.position = position
        self.radius = radius
        self.pulseEnabled = pulseEnabled
        self.targetElement = targetElement
    }
}

struct TourAnnotation: Identifiable {
    let id: String
    let position: CGPoint
    let text: String
    let style: AnnotationStyle

    init(
        id: String = UUID().uuidString,
        position: CGPoint,
        text: String,
        style: AnnotationStyle = .default
    ) {
        self.id = id
        self.position = position
        self.text = text
        self.style = style
    }
}

enum AnnotationStyle {
    case `default`
    case highlight
    case warning
    case success
    case info

    var backgroundColor: Color {
        switch self {
        case .default: return .gray
        case .highlight: return .blue
        case .warning: return .orange
        case .success: return .green
        case .info: return .cyan
        }
    }

    var textColor: Color {
        return .white
    }
}
