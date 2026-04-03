import SwiftUI
import MapKit
import CoreLocation

// MARK: - MapScreen Test Command Handler Extension

extension MapScreen {

    // MARK: - Button Test Command Handler

    func handleTestCommand(_ command: TestCommand) {
        let coord = ButtonTestCoordinator.shared
        guard command != .none else { return }

        switch command {
        case .tapCarButton:
            handleCarButton()
            coord.reportResult("Car button tapped, carLocation=\(carLocation != nil)")
        case .tapFilterButton, .openFilterSheet:
            showFilterSheet = true
            coord.reportResult("Filter sheet opened")
        case .closeFilterSheet, .closeSheet:
            showFilterSheet = false
            showNearbyPubsSheet = false
            showTrailConditionSheet = false
            coord.reportResult("Sheets closed")
        case .tapLocationButton:
            centerOnUser()
            coord.reportResult("Centered on user location")
        case .tapTorchButton:
            toggleTorch()
            coord.reportResult("Torch toggled, isTorchOn=\(isTorchOn)")
        case .tapLivestockButton:
            showLivestockMode.toggle()
            coord.reportResult("Livestock mode=\(showLivestockMode)")
        case .tapWalkingPathsButton:
            showWalkingPaths.toggle()
            coord.reportResult("Walking paths=\(showWalkingPaths)")
        case .tapRainModeButton, .enableRainMode:
            showRainMode = true
            coord.reportResult("Rain mode enabled")
        case .disableRainMode:
            showRainMode = false
            coord.reportResult("Rain mode disabled")
        case .tapPubsButton, .openNearbyPubsSheet:
            showNearbyPubsSheet = true
            coord.reportResult("Nearby pubs sheet opened")
        case .tapAddPOIButton:
            addPOI()
            coord.reportResult("Add POI triggered")
        case .tapWalkButton:
            toggleWalk()
            coord.reportResult("Walk toggled, isActive=\(walkTrackingViewModel.isWalkActive)")
        case .startWalk:
            if !walkTrackingViewModel.isWalkActive { startWalk() }
            coord.reportResult("Walk started")
        case .stopWalk:
            if walkTrackingViewModel.isWalkActive { stopWalk() }
            coord.reportResult("Walk stopped")
        case .tapQuickAddBin:
            quickAddBin()
            coord.reportResult("Quick add bin triggered")
        case .verifyMapLoaded:
            let hasPois = !mapViewModel.pois.isEmpty
            coord.reportResult("Map loaded, POIs=\(mapViewModel.pois.count), hasPois=\(hasPois)")
        case .verifyPOIsVisible:
            let filtered = mapViewModel.filteredPOIs.count
            coord.reportResult("Filtered POIs visible: \(filtered)")
        case .verifyBinDistanceVisible:
            let bins = mapViewModel.pois.filter { $0.poiType == .bin }
            coord.reportResult("Bins loaded: \(bins.count)")
        // L2 data flow verification
        case .verifyPOICount:
            coord.reportResult("Total POIs: \(mapViewModel.pois.count), filtered: \(mapViewModel.filteredPOIs.count)")
        case .verifyBinCount:
            let bins = mapViewModel.pois.filter { $0.poiType == .bin }
            coord.reportResult("Bins: \(bins.count)")
        case .verifyPubCount:
            let pubTypes: Set<PoiType> = [.dogFriendlyPub, .dogFriendlyCafe, .dogFriendlyRestaurant]
            let pubs = mapViewModel.pois.filter { pubTypes.contains($0.poiType) }
            coord.reportResult("Pubs: \(pubs.count)")
        case .verifyMapViewModelState:
            let state = "pois=\(mapViewModel.pois.count) hazards=\(mapViewModel.hazardReports.count) trails=\(mapViewModel.trailConditions.count) dogs=\(mapViewModel.publicDogs.count) lost=\(mapViewModel.lostDogs.count)"
            coord.reportResult("MapVM: \(state)")
        case .verifyWalkTrackingState:
            coord.reportResult("Walk: active=\(walkTrackingViewModel.isWalkActive) dist=\(walkTrackingViewModel.walkDistance) dur=\(walkTrackingViewModel.walkDuration)")
        // L3 sheet content
        case .openFilterSheetAndVerify:
            showFilterSheet = true
            let typeCount = POI.POIType.allCases.count
            coord.reportResult("Filter sheet opened, \(typeCount) POI types available")
        case .openPubsSheetAndVerify:
            showNearbyPubsSheet = true
            let pubTypes: Set<PoiType> = [.dogFriendlyPub, .dogFriendlyCafe, .dogFriendlyRestaurant]
            let pubs = mapViewModel.pois.filter { pubTypes.contains($0.poiType) }
            coord.reportResult("Pubs sheet opened, \(pubs.count) pubs available")
        case .openTrailConditionSheet:
            showTrailConditionSheet = true
            coord.reportResult("Trail condition sheet opened")
        case .closeTrailConditionSheet:
            showTrailConditionSheet = false
            coord.reportResult("Trail condition sheet closed")
        // L4 form submission
        case .submitQuickBin:
            quickAddBin()
            coord.reportResult("Quick bin submitted at current location")
        case .verifyBinAdded:
            let bins = mapViewModel.pois.filter { $0.poiType == .bin }
            coord.reportResult("Bin count after add: \(bins.count)")
        // L5 walk lifecycle
        case .verifyWalkActive:
            coord.reportResult("Walk active: \(walkTrackingViewModel.isWalkActive)")
        case .verifyWalkDistance:
            coord.reportResult("Walk distance: \(walkTrackingViewModel.walkDistance)m, duration: \(walkTrackingViewModel.walkDuration)s")
        case .verifyWalkStopped:
            coord.reportResult("Walk stopped: active=\(walkTrackingViewModel.isWalkActive) finalDist=\(walkTrackingViewModel.walkDistance)")
        // L8 error resilience
        case .addPOIWithNoLocation:
            // Should not crash when location is nil
            mapViewModel.addPOI(type: .bin, at: CLLocationCoordinate2D(latitude: 0, longitude: 0))
            coord.reportResult("POI added at 0,0 without crash")
        case .startWalkWithNoLocation:
            if !walkTrackingViewModel.isWalkActive {
                walkTrackingViewModel.startWalk()
                walkTrackingViewModel.stopWalk()
            }
            coord.reportResult("Walk start/stop with no GPS - no crash")
        case .toggleAllFiltersOff:
            mapViewModel.selectedPOITypes = []
            let filtered = mapViewModel.filteredPOIs.count
            coord.reportResult("All filters off, visible: \(filtered)")
        case .toggleAllFiltersOn:
            mapViewModel.selectedPOITypes = Set(POI.POIType.allCases)
            let filtered = mapViewModel.filteredPOIs.count
            coord.reportResult("All filters on, visible: \(filtered)")
        case .rapidToggleRainMode:
            for _ in 0..<10 { showRainMode.toggle() }
            showRainMode = false
            coord.reportResult("Rain mode toggled 10x rapidly, final=off")
        case .rapidToggleTorch:
            for _ in 0..<6 {
                isTorchOn.toggle()
            }
            isTorchOn = false
            coord.reportResult("Torch toggled 6x rapidly, final=off")
        // L9 state persistence
        case .saveCarLocation:
            carLocation = CLLocationCoordinate2D(latitude: 51.5, longitude: -0.1)
            UserDefaults.standard.set(51.5, forKey: "carLocationLat")
            UserDefaults.standard.set(-0.1, forKey: "carLocationLng")
            coord.reportResult("Car location saved to 51.5,-0.1")
        case .verifyCarLocationSaved:
            let lat = UserDefaults.standard.double(forKey: "carLocationLat")
            let lng = UserDefaults.standard.double(forKey: "carLocationLng")
            let hasLoc = carLocation != nil
            coord.reportResult("Car persisted: lat=\(lat) lng=\(lng) stateHasLoc=\(hasLoc)")
        case .clearCarLocationPersisted:
            clearCarLocation()
            coord.reportResult("Car location cleared")
        case .verifyCarLocationCleared:
            let lat = UserDefaults.standard.double(forKey: "carLocationLat")
            let hasLoc = carLocation != nil
            coord.reportResult("Car cleared: lat=\(lat) stateHasLoc=\(hasLoc)")
        case .verifySettingsLoaded:
            let style = settingsViewModel.settings.mapStyle.rawValue
            let rain = settingsViewModel.settings.rainAutoDetection
            coord.reportResult("Settings: mapStyle=\(style) rainAutoDetect=\(rain)")
        // L10 performance
        case .rapidTabSwitch:
            for tab in AppTab.allCases {
                AppNavigator.shared.selectedTab = tab
            }
            AppNavigator.shared.selectedTab = .map
            coord.reportResult("Cycled all 5 tabs rapidly, no crash")
        case .rapidRouteNavigation:
            for route in [AppRoute.settings, .challenges, .league, .badgeGallery, .milestones] {
                AppNavigator.shared.navigate(to: route)
                AppNavigator.shared.popToRoot()
            }
            coord.reportResult("Navigated 5 routes rapidly with popToRoot, no crash")
        case .stressTestFilterToggle:
            for type in POI.POIType.allCases {
                mapViewModel.togglePOIType(type)
            }
            for type in POI.POIType.allCases {
                mapViewModel.togglePOIType(type)
            }
            coord.reportResult("Toggled all \(POI.POIType.allCases.count) filters twice, no crash")
        // L11 boundary values
        case .addPOIAtMaxCoords:
            mapViewModel.addPOI(type: .bin, at: CLLocationCoordinate2D(latitude: 90.0, longitude: 180.0))
            coord.reportResult("POI at max coords (90,180) - no crash")
        case .addPOIAtMinCoords:
            mapViewModel.addPOI(type: .bin, at: CLLocationCoordinate2D(latitude: -90.0, longitude: -180.0))
            coord.reportResult("POI at min coords (-90,-180) - no crash")
        case .addPOIAtAntimeridian:
            mapViewModel.addPOI(type: .bin, at: CLLocationCoordinate2D(latitude: 0.0, longitude: 179.9999))
            coord.reportResult("POI at antimeridian - no crash")
        case .walkWithZeroDistance:
            walkTrackingViewModel.startWalk()
            walkTrackingViewModel.stopWalk()
            coord.reportResult("Zero-distance walk start/stop - no crash, dist=\(walkTrackingViewModel.walkDistance)")
        case .filterWithEmptyPOIs:
            let saved = mapViewModel.pois
            mapViewModel.pois = []
            let count = mapViewModel.filteredPOIs.count
            mapViewModel.pois = saved
            coord.reportResult("Filter with empty POIs: \(count), restored \(saved.count)")
        case .verifyAfterChaos:
            let pois = mapViewModel.pois.count
            let filtered = mapViewModel.filteredPOIs.count
            let active = walkTrackingViewModel.isWalkActive
            coord.reportResult("After chaos: pois=\(pois) filtered=\(filtered) walkActive=\(active) rainMode=\(showRainMode)")
        // L12 memory pressure
        case .loadPOIsTwice:
            mapViewModel.loadPOIs(near: region.center)
            mapViewModel.loadPOIs(near: region.center)
            coord.reportResult("Double POI load triggered - no crash")
        case .toggleAllButtonsRapidly:
            showRainMode.toggle(); showRainMode.toggle()
            showLivestockMode.toggle(); showLivestockMode.toggle()
            showWalkingPaths.toggle(); showWalkingPaths.toggle()
            isTorchOn.toggle(); isTorchOn.toggle()
            showFogOfWar.toggle(); showFogOfWar.toggle()
            coord.reportResult("All buttons toggled on/off rapidly - no crash")
        case .openCloseAllSheets:
            showFilterSheet = true; showFilterSheet = false
            showNearbyPubsSheet = true; showNearbyPubsSheet = false
            showTrailConditionSheet = true; showTrailConditionSheet = false
            showMapClickDialog = true; showMapClickDialog = false
            showPOISelectionDialog = true; showPOISelectionDialog = false
            coord.reportResult("All 5 sheets opened/closed rapidly - no crash")
        case .navigateAllRoutesFast:
            let routes: [AppRoute] = [.settings, .challenges, .league, .badgeGallery, .milestones,
                .hazardReport, .offLeadZones, .rainModeSettings, .plannedWalks, .routeLibrary,
                .nearbyPubs, .languageSettings, .notificationSettings, .privacySettings,
                .notifications, .charitySettings, .chatList, .discovery, .walkHistory, .stats]
            for route in routes {
                AppNavigator.shared.navigate(to: route)
                AppNavigator.shared.popToRoot()
            }
            coord.reportResult("Navigated \(routes.count) routes with instant popToRoot - no crash")
        // L13 state corruption
        case .walkDuringModeSwitch:
            walkTrackingViewModel.startWalk()
            AppNavigator.shared.switchMode(.business)
            AppNavigator.shared.switchMode(.public_)
            walkTrackingViewModel.stopWalk()
            coord.reportResult("Walk during mode switch - no crash, walk stopped cleanly")
        case .modeWhileSheetOpen:
            showFilterSheet = true
            AppNavigator.shared.switchMode(.business)
            AppNavigator.shared.switchMode(.public_)
            showFilterSheet = false
            coord.reportResult("Mode switch while sheet open - no crash")
        case .doubleStartWalk:
            walkTrackingViewModel.startWalk()
            walkTrackingViewModel.startWalk()
            walkTrackingViewModel.stopWalk()
            coord.reportResult("Double start walk - no crash")
        case .doubleStopWalk:
            walkTrackingViewModel.stopWalk()
            walkTrackingViewModel.stopWalk()
            coord.reportResult("Double stop walk - no crash")
        case .popEmptyNavigation:
            AppNavigator.shared.popToRoot()
            AppNavigator.shared.pop()
            AppNavigator.shared.pop()
            AppNavigator.shared.popToRoot()
            coord.reportResult("Pop empty nav stack 4x - no crash")
        case .navigateWhileWalking:
            walkTrackingViewModel.startWalk()
            AppNavigator.shared.navigate(to: .settings)
            AppNavigator.shared.popToRoot()
            AppNavigator.shared.navigate(to: .challenges)
            AppNavigator.shared.popToRoot()
            walkTrackingViewModel.stopWalk()
            coord.reportResult("Navigate settings+challenges during walk - no crash")
        case .none:
            break
        }
    }
}
