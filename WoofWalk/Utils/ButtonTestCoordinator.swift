import SwiftUI
import CoreLocation

/// Commands that the test automation can send to MapScreen
enum TestCommand: Equatable {
    case none
    // Map controls
    case tapCarButton
    case tapFilterButton
    case tapLocationButton
    case tapTorchButton
    case tapLivestockButton
    case tapWalkingPathsButton
    case tapRainModeButton
    case tapPubsButton
    case tapAddPOIButton
    case tapWalkButton
    case tapQuickAddBin
    // Sheets & dialogs
    case openFilterSheet
    case closeFilterSheet
    case openNearbyPubsSheet
    case closeSheet
    // State toggles
    case enableRainMode
    case disableRainMode
    // Walk flow
    case startWalk
    case stopWalk
    // Verification
    case verifyMapLoaded
    case verifyPOIsVisible
    case verifyBinDistanceVisible
}

/// Singleton coordinator for button-level testing.
/// MapScreen observes `currentCommand` and executes it against its own @State vars.
@MainActor
class ButtonTestCoordinator: ObservableObject {
    static let shared = ButtonTestCoordinator()

    @Published var currentCommand: TestCommand = .none
    @Published var lastResult: String = ""
    @Published var commandCompleted = false

    func send(_ command: TestCommand) async {
        currentCommand = command
        commandCompleted = false
        // Wait for MapScreen to process
        try? await Task.sleep(nanoseconds: 500_000_000)
        // Wait for completion signal
        for _ in 0..<20 { // max 10 seconds
            if commandCompleted { break }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        currentCommand = .none
    }

    func reportResult(_ result: String) {
        lastResult = result
        commandCompleted = true
    }
}
