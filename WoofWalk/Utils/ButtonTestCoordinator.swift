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
    // Verification - L1
    case verifyMapLoaded
    case verifyPOIsVisible
    case verifyBinDistanceVisible
    // Verification - L2 data flow
    case verifyPOICount
    case verifyBinCount
    case verifyPubCount
    case verifyMapViewModelState
    case verifyWalkTrackingState
    // Verification - L3 sheet content
    case openFilterSheetAndVerify
    case openPubsSheetAndVerify
    case openTrailConditionSheet
    case closeTrailConditionSheet
    // L4 form submission
    case submitQuickBin
    case verifyBinAdded
    // L5 walk lifecycle
    case verifyWalkActive
    case verifyWalkDistance
    case verifyWalkStopped
}

/// Singleton coordinator for button-level testing.
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
        for _ in 0..<20 {
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
