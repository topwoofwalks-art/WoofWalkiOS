#if false
import SwiftUI

struct TourExampleView: View {
    @StateObject private var tourCoordinator = TourCoordinator()

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("WoofWalk Tour Demo")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Divider()

                Button("Start Social Tour") {
                    tourCoordinator.startTour(.socialNavigationDemo)
                }
                .buttonStyle(.borderedProminent)
                .tourTarget(id: "social_tour_button", coordinator: tourCoordinator)

                Button("Start Field Drawing Tour") {
                    tourCoordinator.startTour(.fieldDrawingDemo)
                }
                .buttonStyle(.borderedProminent)
                .tourTarget(id: "drawing_tour_button", coordinator: tourCoordinator)

                Button("Start Map Features Tour") {
                    tourCoordinator.startTour(.mapFeaturesDemo)
                }
                .buttonStyle(.borderedProminent)
                .tourTarget(id: "map_tour_button", coordinator: tourCoordinator)

                Divider()

                Button("Reset All Tours") {
                    resetAllTours()
                }
                .buttonStyle(.bordered)

                Spacer()

                tourStatsView
            }
            .padding()
            .tourOverlay(coordinator: tourCoordinator)
            .onAppear {
                setupTourCallbacks()
                checkAndStartInitialTour()
            }
        }
    }

    private var tourStatsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tour Statistics")
                .font(.headline)

            ForEach(tourCoordinator.getAllTourStats(), id: \.tourType.rawValue) { stats in
                HStack {
                    Text(tourTypeDisplayName(stats.tourType))
                        .font(.subheadline)

                    Spacer()

                    Text(stats.status)
                        .font(.caption)
                        .foregroundColor(statusColor(stats.status))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }

    private func setupTourCallbacks() {
        tourCoordinator.setOnStepChangeCallback { step in
            print("Tour step changed: \(step.title)")
        }

        tourCoordinator.setOnTourCompleteCallback { tourType in
            print("Tour completed: \(tourType.rawValue)")
        }

        tourCoordinator.setOnTourSkipCallback { tourType in
            print("Tour skipped: \(tourType.rawValue)")
        }
    }

    private func checkAndStartInitialTour() {
        if tourCoordinator.shouldShowTour(.initialWalkthrough) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                tourCoordinator.startTour(.initialWalkthrough)
            }
        }
    }

    private func resetAllTours() {
        let persistence = TourPersistence()
        persistence.resetAllTours()

        tourCoordinator.resetTour(.initialWalkthrough)
        tourCoordinator.resetTour(.socialNavigationDemo)
        tourCoordinator.resetTour(.fieldDrawingDemo)
        tourCoordinator.resetTour(.mapFeaturesDemo)
    }

    private func tourTypeDisplayName(_ type: TourType) -> String {
        switch type {
        case .initialWalkthrough: return "Initial Walkthrough"
        case .socialNavigationDemo: return "Social Navigation"
        case .fieldDrawingDemo: return "Field Drawing"
        case .mapFeaturesDemo: return "Map Features"
        case .custom: return "Custom"
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "Completed": return .green
        case "Skipped": return .orange
        case "In Progress": return .blue
        default: return .gray
        }
    }
}

struct CustomTourExampleView: View {
    @StateObject private var tourCoordinator = TourCoordinator()

    var body: some View {
        VStack(spacing: 20) {
            Text("Custom Tour Example")
                .font(.title)
                .tourTarget(id: "title", coordinator: tourCoordinator)

            Button("Primary Action") {
                print("Primary action")
            }
            .buttonStyle(.borderedProminent)
            .tourTarget(id: "primary_button", coordinator: tourCoordinator)

            Button("Secondary Action") {
                print("Secondary action")
            }
            .buttonStyle(.bordered)
            .tourTarget(id: "secondary_button", coordinator: tourCoordinator)

            Toggle("Enable Feature", isOn: .constant(false))
                .tourTarget(id: "toggle", coordinator: tourCoordinator)

            Button("Start Custom Tour") {
                startCustomTour()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .tourOverlay(coordinator: tourCoordinator)
    }

    private func startCustomTour() {
        let steps = [
            TourStep(
                id: "welcome",
                title: "Welcome",
                description: "This is a custom tour demonstrating how to create your own tour flows.",
                targetViewId: "title",
                spotlightShape: .roundedRectangle(cornerRadius: 8),
                position: .center
            ),
            TourStep(
                id: "primary_action",
                title: "Primary Action",
                description: "This is your main action button. Tap it to perform the primary task.",
                targetViewId: "primary_button",
                spotlightShape: .circle,
                position: .center
            ),
            TourStep(
                id: "secondary_action",
                title: "Secondary Action",
                description: "Use this button for secondary tasks or alternative actions.",
                targetViewId: "secondary_button",
                spotlightShape: .circle,
                position: .center
            ),
            TourStep(
                id: "toggle_feature",
                title: "Toggle Feature",
                description: "Enable or disable this feature using the toggle switch.",
                targetViewId: "toggle",
                spotlightShape: .roundedRectangle(cornerRadius: 12),
                position: .center,
                action: ShowOverlayAction(message: "Feature toggled!")
            )
        ]

        tourCoordinator.registerCustomTour(.custom, steps: steps)
        tourCoordinator.startTour(.custom)
    }
}

struct TourWithAnnotationsExample: View {
    @StateObject private var tourCoordinator = TourCoordinator()

    var body: some View {
        ZStack {
            VStack(spacing: 40) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 100, height: 100)
                    .tourTarget(id: "circle", coordinator: tourCoordinator)

                Rectangle()
                    .fill(Color.green)
                    .frame(width: 100, height: 100)
                    .tourTarget(id: "rectangle", coordinator: tourCoordinator)

                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.orange)
                    .frame(width: 100, height: 100)
                    .tourTarget(id: "rounded_rectangle", coordinator: tourCoordinator)
            }

            Button("Start Tour with Annotations") {
                startTourWithAnnotations()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 40)
        }
        .tourOverlay(coordinator: tourCoordinator)
    }

    private func startTourWithAnnotations() {
        tourCoordinator.addAnnotation(
            TourAnnotation(
                position: CGPoint(x: 200, y: 100),
                text: "Circle Shape",
                style: .info
            )
        )

        tourCoordinator.addAnnotation(
            TourAnnotation(
                position: CGPoint(x: 200, y: 250),
                text: "Rectangle Shape",
                style: .highlight
            )
        )

        tourCoordinator.addAnnotation(
            TourAnnotation(
                position: CGPoint(x: 200, y: 400),
                text: "Rounded Rectangle",
                style: .success
            )
        )

        let steps = [
            TourStep(
                id: "shapes_intro",
                title: "Shape Gallery",
                description: "Explore different shapes and their properties.",
                position: .center
            ),
            TourStep(
                id: "circle_shape",
                title: "Circle",
                description: "A perfect circle with equal radius on all sides.",
                targetViewId: "circle",
                spotlightShape: .circle,
                position: .topLeft
            ),
            TourStep(
                id: "rectangle_shape",
                title: "Rectangle",
                description: "A four-sided shape with right angles.",
                targetViewId: "rectangle",
                spotlightShape: .rectangle,
                position: .center
            ),
            TourStep(
                id: "rounded_rectangle_shape",
                title: "Rounded Rectangle",
                description: "A rectangle with rounded corners for a softer look.",
                targetViewId: "rounded_rectangle",
                spotlightShape: .roundedRectangle(cornerRadius: 20),
                position: .center
            )
        ]

        tourCoordinator.registerCustomTour(.custom, steps: steps)
        tourCoordinator.startTour(.custom)

        tourCoordinator.setOnTourCompleteCallback { _ in
            tourCoordinator.clearAnnotations()
        }

        tourCoordinator.setOnTourSkipCallback { _ in
            tourCoordinator.clearAnnotations()
        }
    }
}

#Preview("Tour Example") {
    TourExampleView()
}

#Preview("Custom Tour") {
    CustomTourExampleView()
}

#Preview("Annotations") {
    TourWithAnnotationsExample()
}

#endif
