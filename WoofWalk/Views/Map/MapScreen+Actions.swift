import SwiftUI
import MapKit
import CoreLocation

// MARK: - MapScreen Actions Extension

extension MapScreen {

    // MARK: - Map Tap Handlers

    func handleMapTap(_ coordinate: CLLocationCoordinate2D) {
        guard !walkTrackingViewModel.isWalkActive else { return }
        clickedLocation = coordinate
        showMapClickDialog = true
    }

    func handlePOITap(_ poi: POI) {
        selectedPOI = poi
        showPOIDetailSheet = true
    }

    func handleBagDropTap(_ bagDrop: PooBagDrop) {
        selectedBagDrop = bagDrop
    }

    func handlePublicDogTap(_ dog: PublicDog) {
        selectedPublicDog = dog
        showPublicDogSheet = true
    }

    func handleLostDogTap(_ dog: LostDog) {
        selectedLostDog = dog
        showLostDogSheet = true
    }

    // MARK: - Walk Actions

    func toggleWalk() {
        if walkTrackingViewModel.isWalkActive {
            stopWalk()
        } else {
            startWalk()
        }
    }

    func startWalk() {
        guard guidanceViewModel.guidanceState == .idle else {
            return
        }
        if !hasShownPrompt {
            showBackgroundLocationPrompt = true
            hasShownPrompt = true
            return
        }
        walkTrackingViewModel.startWalk()
        mapViewModel.startWalkTracking()
    }

    func stopWalk() {
        completedDistance = walkTrackingViewModel.walkDistance
        completedDuration = Int(walkTrackingViewModel.walkDuration)
        walkTrackingViewModel.stopWalk()
        mapViewModel.stopWalkTracking()
        showWalkSummary = true

        Task {
            await BadgeAwardingService.shared.checkAndAwardBadges(
                walkDistance: completedDistance,
                totalWalks: 0,
                totalDistance: completedDistance,
                poisCreated: 0,
                votesGiven: 0
            )
        }
    }

    // MARK: - POI Actions

    func addPOI() {
        guard let location = locationManager.location else { return }
        mapViewModel.addPOI(type: .bin, at: location)
    }

    func quickAddBin() {
        guard let location = locationManager.location else { return }
        mapViewModel.addPOI(type: .bin, at: location)
    }

    func quickAddPooBag() {
        guard let location = locationManager.location else { return }
        mapViewModel.addPooBagDrop(at: location)
    }

    // MARK: - Map Navigation Actions

    func centerOnUser() {
        if let location = locationManager.location {
            region = MKCoordinateRegion(
                center: location,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            mapViewModel.loadPOIs(near: location)
        }
    }

    // MARK: - Utility Actions

    func toggleTorch() {
        isTorchOn.toggle()
        TorchManager.shared.toggleTorch(isTorchOn)
    }

    func handleCarButton() {
        if carLocation == nil {
            if let location = locationManager.location {
                carLocation = location
            }
        } else {
            showCarOptionsDialog = true
        }
    }

    func callPhoneNumber(_ phone: String) {
        if let url = URL(string: "tel://\(phone)") {
            UIApplication.shared.open(url)
        }
    }
}
