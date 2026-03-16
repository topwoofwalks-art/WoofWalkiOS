import Foundation
import SwiftUI
import Combine

@MainActor
class TourCoordinator: ObservableObject {
    @Published private(set) var currentTour: TourProgress?
    @Published private(set) var highlightedElement: HighlightConfig?
    @Published private(set) var overlayMessage: String?
    @Published private(set) var activeAnnotations: [TourAnnotation] = []

    private var onStepChangeCallback: ((TourStep) -> Void)?
    private var onTourCompleteCallback: ((TourType) -> Void)?
    private var onTourSkipCallback: ((TourType) -> Void)?

    private var tourDefinitions: [TourType: [TourStep]] = [:]
    private let userDefaults: UserDefaults

    private let tourShownKey = "tour_shown_"
    private let tutorialCompletedKey = "tutorial_completed"
    private let tutorialVersionKey = "tutorial_version"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        initializeDefaultTours()
    }

    private func initializeDefaultTours() {
        tourDefinitions[.socialNavigationDemo] = [
            TourStep(
                id: "social_intro",
                title: "Social Features",
                description: "Let's explore how to connect with other dog owners!",
                targetViewId: "bottom_nav_social",
                position: .bottomNavSocial,
                action: NavigateToSocialAction()
            ),
            TourStep(
                id: "social_friends",
                title: "Friends Tab",
                description: "Find and connect with nearby dog owners. You can add friends, see their profiles, and coordinate walks together.",
                targetViewId: "social_tab_friends",
                position: .topLeft
            ),
            TourStep(
                id: "social_events",
                title: "Events",
                description: "Discover local dog events, meetups, and playdates in your area.",
                targetViewId: "social_tab_events",
                position: .topLeft
            ),
            TourStep(
                id: "social_group_walks",
                title: "Group Walks",
                description: "Join or create group walks. Walk with other dog owners and make new friends!",
                targetViewId: "social_tab_group_walks",
                position: .topLeft
            ),
            TourStep(
                id: "social_chats",
                title: "Chats",
                description: "Message your friends directly. Stay connected and plan activities together.",
                targetViewId: "social_tab_chats",
                position: .topLeft
            ),
            TourStep(
                id: "social_lost_dogs",
                title: "Lost Dogs Alert",
                description: "Help reunite lost dogs with their owners. Report or search for missing pets in your community.",
                targetViewId: "social_tab_lost_dogs",
                position: .topLeft,
                action: NavigateToMapAction()
            )
        ]

        tourDefinitions[.fieldDrawingDemo] = [
            TourStep(
                id: "draw_intro",
                title: "Field Drawing",
                description: "Mark off-leash areas and dog-friendly zones directly on the map!",
                targetViewId: nil,
                position: .center
            ),
            TourStep(
                id: "draw_enable",
                title: "Enable Drawing Mode",
                description: "Long press on the map to start drawing. Tap points to create a boundary.",
                targetViewId: "map_view",
                position: .center,
                action: EnableDrawingModeAction()
            ),
            TourStep(
                id: "draw_points",
                title: "Add Points",
                description: "Tap on the map to add points. These will form the boundary of your field.",
                targetViewId: "map_view",
                position: .center
            ),
            TourStep(
                id: "draw_complete",
                title: "Complete Drawing",
                description: "Tap the checkmark button to complete your field. The area will be saved and visible to other users.",
                targetViewId: "draw_complete_button",
                position: .bottomRight1,
                action: DisableDrawingModeAction()
            ),
            TourStep(
                id: "draw_delete",
                title: "Delete Fields",
                description: "Need to remove a field? Tap on it and select delete.",
                targetViewId: "draw_delete_button",
                position: .bottomRight2
            )
        ]

        tourDefinitions[.mapFeaturesDemo] = [
            TourStep(
                id: "map_search",
                title: "Search",
                description: "Find dog parks, water fountains, and pet-friendly places nearby.",
                targetViewId: "search_button",
                position: .topRight1
            ),
            TourStep(
                id: "map_filter",
                title: "Filter",
                description: "Show only the markers you care about. Hide the rest for a cleaner map.",
                targetViewId: "filter_button",
                position: .topRight2
            ),
            TourStep(
                id: "map_location",
                title: "My Location",
                description: "Quickly center the map on your current location.",
                targetViewId: "location_button",
                position: .topRight3
            ),
            TourStep(
                id: "map_tracking",
                title: "Start Walk",
                description: "Begin tracking your walk to earn points and save your routes.",
                targetViewId: "start_walk_button",
                position: .bottomRight3
            )
        ]
    }

    func shouldShowTour(_ tourType: TourType) -> Bool {
        switch tourType {
        case .initialWalkthrough:
            return !userDefaults.bool(forKey: tutorialCompletedKey)
        case .socialNavigationDemo, .fieldDrawingDemo, .mapFeaturesDemo:
            let key = tourShownKey + tourType.rawValue
            return !userDefaults.bool(forKey: key)
        case .custom:
            return false
        }
    }

    func startTour(_ tourType: TourType, customSteps: [TourStep]? = nil) {
        let steps = customSteps ?? tourDefinitions[tourType] ?? []

        guard !steps.isEmpty else { return }

        currentTour = TourProgress(
            tourType: tourType,
            currentStepIndex: -1,
            totalSteps: steps.count,
            state: .inProgress
        )

        nextStep()
    }

    func nextStep() {
        guard let current = currentTour,
              let steps = tourDefinitions[current.tourType] else { return }

        let nextIndex = current.currentStepIndex + 1

        if nextIndex >= steps.count {
            completeTour()
            return
        }

        let nextStep = steps[nextIndex]
        currentTour = TourProgress(
            tourType: current.tourType,
            currentStepIndex: nextIndex,
            totalSteps: current.totalSteps,
            state: current.state,
            completedSteps: current.completedSteps.union([nextStep.id])
        )

        executeStepAction(nextStep)
        onStepChangeCallback?(nextStep)

        if let targetId = nextStep.targetViewId {
            highlightedElement = HighlightConfig(
                position: .zero,
                targetElement: targetId
            )
        }
    }

    func previousStep() {
        guard let current = currentTour,
              current.currentStepIndex > 0,
              let steps = tourDefinitions[current.tourType] else { return }

        let prevIndex = current.currentStepIndex - 1
        let prevStep = steps[prevIndex]

        currentTour = TourProgress(
            tourType: current.tourType,
            currentStepIndex: prevIndex,
            totalSteps: current.totalSteps,
            state: current.state,
            completedSteps: current.completedSteps
        )

        executeStepAction(prevStep)
        onStepChangeCallback?(prevStep)

        if let targetId = prevStep.targetViewId {
            highlightedElement = HighlightConfig(
                position: .zero,
                targetElement: targetId
            )
        }
    }

    func pauseTour() {
        guard let current = currentTour else { return }
        currentTour = TourProgress(
            tourType: current.tourType,
            currentStepIndex: current.currentStepIndex,
            totalSteps: current.totalSteps,
            state: .paused,
            completedSteps: current.completedSteps
        )
        highlightedElement = nil
    }

    func resumeTour() {
        guard let current = currentTour else { return }
        currentTour = TourProgress(
            tourType: current.tourType,
            currentStepIndex: current.currentStepIndex,
            totalSteps: current.totalSteps,
            state: .inProgress,
            completedSteps: current.completedSteps
        )
    }

    func skipTour() {
        guard let current = currentTour else { return }

        markTourAsShown(current.tourType)

        currentTour = TourProgress(
            tourType: current.tourType,
            currentStepIndex: current.currentStepIndex,
            totalSteps: current.totalSteps,
            state: .skipped,
            completedSteps: current.completedSteps
        )

        onTourSkipCallback?(current.tourType)
        clearTour()
    }

    func completeTour() {
        guard let current = currentTour else { return }

        markTourAsShown(current.tourType)

        currentTour = TourProgress(
            tourType: current.tourType,
            currentStepIndex: current.currentStepIndex,
            totalSteps: current.totalSteps,
            state: .completed,
            completedSteps: current.completedSteps
        )

        onTourCompleteCallback?(current.tourType)
        clearTour()
    }

    func clearTour() {
        currentTour = nil
        highlightedElement = nil
        overlayMessage = nil
        activeAnnotations = []
    }

    func getCurrentStep() -> TourStep? {
        guard let current = currentTour,
              let steps = tourDefinitions[current.tourType] else { return nil }
        return steps.indices.contains(current.currentStepIndex) ? steps[current.currentStepIndex] : nil
    }

    func setOnStepChangeCallback(_ callback: @escaping (TourStep) -> Void) {
        onStepChangeCallback = callback
    }

    func setOnTourCompleteCallback(_ callback: @escaping (TourType) -> Void) {
        onTourCompleteCallback = callback
    }

    func setOnTourSkipCallback(_ callback: @escaping (TourType) -> Void) {
        onTourSkipCallback = callback
    }

    func addAnnotation(_ annotation: TourAnnotation) {
        activeAnnotations.append(annotation)
    }

    func removeAnnotation(_ annotationId: String) {
        activeAnnotations.removeAll { $0.id == annotationId }
    }

    func clearAnnotations() {
        activeAnnotations = []
    }

    func showOverlayMessage(_ message: String) {
        overlayMessage = message
    }

    func hideOverlayMessage() {
        overlayMessage = nil
    }

    func highlightElement(
        targetElement: String,
        position: CGPoint,
        radius: CGFloat = 40.0
    ) {
        highlightedElement = HighlightConfig(
            position: position,
            radius: radius,
            targetElement: targetElement
        )
    }

    func clearHighlight() {
        highlightedElement = nil
    }

    private func executeStepAction(_ step: TourStep) {
        if let action = step.action as? ShowOverlayAction {
            showOverlayMessage(action.message)
        }
        step.action?.execute()
    }

    func markTourAsShown(_ tourType: TourType) {
        switch tourType {
        case .initialWalkthrough:
            userDefaults.set(true, forKey: tutorialCompletedKey)
        case .socialNavigationDemo, .fieldDrawingDemo, .mapFeaturesDemo:
            let key = tourShownKey + tourType.rawValue
            userDefaults.set(true, forKey: key)
        case .custom:
            break
        }
    }

    func resetTour(_ tourType: TourType) {
        switch tourType {
        case .initialWalkthrough:
            userDefaults.set(false, forKey: tutorialCompletedKey)
            userDefaults.set(0, forKey: tutorialVersionKey)
        case .socialNavigationDemo, .fieldDrawingDemo, .mapFeaturesDemo:
            let key = tourShownKey + tourType.rawValue
            userDefaults.set(false, forKey: key)
        case .custom:
            break
        }
    }

    func registerCustomTour(_ tourType: TourType, steps: [TourStep]) {
        tourDefinitions[tourType] = steps
    }

    func getTourProgress() -> TourProgress? {
        return currentTour
    }

    func isTourActive() -> Bool {
        return currentTour?.state == .inProgress
    }

    func getTourStepById(_ stepId: String) -> TourStep? {
        return tourDefinitions.values
            .flatMap { $0 }
            .first { $0.id == stepId }
    }
}
