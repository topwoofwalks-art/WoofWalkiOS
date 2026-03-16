import Foundation
import SwiftUI
import Combine

@MainActor
class TourViewModel: ObservableObject {
    @Published var activeTour: Tour?
    @Published var currentStepIndex: Int = 0
    @Published var isShowingTour: Bool = false
    @Published var availableTours: [Tour] = []
    @Published var completedTourIds: Set<String> = []

    private var cancellables = Set<AnyCancellable>()
    private let userDefaults = UserDefaults.standard
    private let completedToursKey = "completedTours"

    init() {
        loadCompletedTours()
        setupAvailableTours()
    }

    var currentStep: TourStep? {
        guard let tour = activeTour,
              currentStepIndex < tour.steps.count else {
            return nil
        }
        return tour.steps[currentStepIndex]
    }

    var isFirstStep: Bool {
        currentStepIndex == 0
    }

    var isLastStep: Bool {
        guard let tour = activeTour else { return false }
        return currentStepIndex == tour.steps.count - 1
    }

    var progress: Double {
        guard let tour = activeTour, !tour.steps.isEmpty else {
            return 0.0
        }
        return Double(currentStepIndex + 1) / Double(tour.steps.count)
    }

    func startTour(_ tour: Tour) {
        activeTour = tour
        currentStepIndex = 0
        isShowingTour = true
    }

    func nextStep() {
        guard let tour = activeTour else { return }

        if currentStepIndex < tour.steps.count - 1 {
            currentStepIndex += 1
        } else {
            completeTour()
        }
    }

    func previousStep() {
        guard currentStepIndex > 0 else { return }
        currentStepIndex -= 1
    }

    func skipTour() {
        activeTour = nil
        currentStepIndex = 0
        isShowingTour = false
    }

    func completeTour() {
        guard let tour = activeTour else { return }

        completedTourIds.insert(tour.id)
        saveCompletedTours()

        activeTour = nil
        currentStepIndex = 0
        isShowingTour = false
    }

    func resetTour(_ tourId: String) {
        completedTourIds.remove(tourId)
        saveCompletedTours()
    }

    func resetAllTours() {
        completedTourIds.removeAll()
        saveCompletedTours()
    }

    func shouldShowTour(for target: TourTarget) -> Tour? {
        availableTours.first { tour in
            tour.targetScreen == target &&
            !completedTourIds.contains(tour.id)
        }
    }

    func markStepCompleted(_ stepId: String) {
        guard var tour = activeTour,
              let stepIndex = tour.steps.firstIndex(where: { $0.id == stepId }) else {
            return
        }

        tour.steps[stepIndex].isCompleted = true
        activeTour = tour
    }

    private func loadCompletedTours() {
        if let data = userDefaults.data(forKey: completedToursKey),
           let tours = try? JSONDecoder().decode(Set<String>.self, from: data) {
            completedTourIds = tours
        }
    }

    private func saveCompletedTours() {
        if let data = try? JSONEncoder().encode(completedTourIds) {
            userDefaults.set(data, forKey: completedToursKey)
        }
    }

    private func setupAvailableTours() {
        availableTours = [
            createMapTour(),
            createLivestockFieldTour(),
            createWalkingPathTour(),
            createWalkTrackingTour()
        ]
    }

    private func createMapTour() -> Tour {
        Tour(
            id: "map_basics",
            title: "Map Basics",
            description: "Learn how to navigate and use the map",
            steps: [
                TourStep(
                    id: "map_step1",
                    title: "Welcome",
                    message: "Welcome to WoofWalk! Let's explore the map features.",
                    targetElement: nil,
                    action: nil,
                    order: 0,
                    isCompleted: false
                ),
                TourStep(
                    id: "map_step2",
                    title: "Camera Modes",
                    message: "Tap the camera icon to switch between different view modes.",
                    targetElement: "cameraButton",
                    action: .tap,
                    order: 1,
                    isCompleted: false
                ),
                TourStep(
                    id: "map_step3",
                    title: "POI Filters",
                    message: "Use the filter button to show or hide different points of interest.",
                    targetElement: "filterButton",
                    action: .tap,
                    order: 2,
                    isCompleted: false
                )
            ],
            targetScreen: .map,
            priority: 1,
            completedAt: nil
        )
    }

    private func createLivestockFieldTour() -> Tour {
        Tour(
            id: "livestock_fields",
            title: "Livestock Fields",
            description: "Learn about livestock field warnings",
            steps: [
                TourStep(
                    id: "livestock_step1",
                    title: "Field Overlays",
                    message: "Orange polygons show areas with livestock. Tap to see details.",
                    targetElement: "fieldOverlay",
                    action: .tap,
                    order: 0,
                    isCompleted: false
                ),
                TourStep(
                    id: "livestock_step2",
                    title: "Draw New Field",
                    message: "Long press on the map to start drawing a new livestock field.",
                    targetElement: nil,
                    action: .longPress,
                    order: 1,
                    isCompleted: false
                ),
                TourStep(
                    id: "livestock_step3",
                    title: "Report Accuracy",
                    message: "Help the community by reporting if field data is accurate.",
                    targetElement: "accuracyButton",
                    action: .tap,
                    order: 2,
                    isCompleted: false
                )
            ],
            targetScreen: .livestockFields,
            priority: 2,
            completedAt: nil
        )
    }

    private func createWalkingPathTour() -> Tour {
        Tour(
            id: "walking_paths",
            title: "Walking Paths",
            description: "Discover safe walking paths",
            steps: [
                TourStep(
                    id: "path_step1",
                    title: "Path Quality",
                    message: "Green paths are high quality, yellow are moderate, red are challenging.",
                    targetElement: "pathOverlay",
                    action: nil,
                    order: 0,
                    isCompleted: false
                ),
                TourStep(
                    id: "path_step2",
                    title: "Path Details",
                    message: "Tap a path to see surface type, shade level, and other details.",
                    targetElement: "pathOverlay",
                    action: .tap,
                    order: 1,
                    isCompleted: false
                )
            ],
            targetScreen: .walkingPaths,
            priority: 3,
            completedAt: nil
        )
    }

    private func createWalkTrackingTour() -> Tour {
        Tour(
            id: "walk_tracking",
            title: "Walk Tracking",
            description: "Track your walks with your dog",
            steps: [
                TourStep(
                    id: "walk_step1",
                    title: "Start Walk",
                    message: "Tap the start button to begin tracking your walk.",
                    targetElement: "startWalkButton",
                    action: .tap,
                    order: 0,
                    isCompleted: false
                ),
                TourStep(
                    id: "walk_step2",
                    title: "Pause & Resume",
                    message: "You can pause and resume your walk at any time.",
                    targetElement: "pauseButton",
                    action: .tap,
                    order: 1,
                    isCompleted: false
                ),
                TourStep(
                    id: "walk_step3",
                    title: "View Stats",
                    message: "See distance, duration, and pace in real-time.",
                    targetElement: "statsPanel",
                    action: nil,
                    order: 2,
                    isCompleted: false
                )
            ],
            targetScreen: .walkTracking,
            priority: 4,
            completedAt: nil
        )
    }
}
