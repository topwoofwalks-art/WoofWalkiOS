import SwiftUI
import MapKit
import CoreLocation
import FirebaseAuth
import FirebaseFirestore

// MARK: - MapScreen Actions Extension

extension MapScreen {

    // MARK: - Map Tap Handlers

    func handleMapTap(_ coordinate: CLLocationCoordinate2D) {
        guard !walkTrackingViewModel.isWalkActive else { return }

        // In planning mode, taps add waypoints instead of showing the dialog
        if isPlanningMode {
            mapViewModel.addPlanningWaypoint(coordinate)
            return
        }

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
        // Use max of both sources - walkTrackingVM accumulates from GPS, mapViewModel from polyline
        completedDistance = max(walkTrackingViewModel.walkDistance, mapViewModel.walkDistance)
        completedDuration = Int(walkTrackingViewModel.walkDuration)
        walkTrackingViewModel.stopWalk()
        mapViewModel.stopWalkTracking()
        guidanceViewModel.stopGuidance()
        showWalkSummary = true

        // Mark planned walk as completed if this was a guided planned walk
        if pendingPlannedWalk != nil {
            let walkId = "\(Auth.auth().currentUser?.uid ?? "")_\(Int(Date().timeIntervalSince1970 * 1000))"
            markPlannedWalkCompleted(walkId: walkId)
        }

        Task {
            await BadgeAwardingService.shared.checkAndAwardBadgesAfterWalk(
                walkDistance: completedDistance
            )

            // Record charity points if eligible (matches Android WalkTrackingViewModel.recordCharityPoints)
            let charityPoints = await CharityRepository.shared.recordCharityPoints(
                distanceMeters: completedDistance
            )
            if charityPoints > 0 {
                let charityId = CharityRepository.shared.getSelectedCharityId()
                let charityName = CharityRepository.shared.getCharityName(charityId)
                print("[MapScreen] Charity points awarded: \(charityPoints) for \(charityName)")
            }

            // Update challenge progress after walk completion
            var streakValue = 0
            if let uid = Auth.auth().currentUser?.uid {
                streakValue = (try? await Firestore.firestore().collection("users")
                    .document(uid)
                    .getDocument()
                    .data(as: UserProfile.self).walkStreak?.currentStreak) ?? 0
                await ChallengeRepository.shared.updateChallengeProgressAfterWalk(
                    distanceMeters: completedDistance,
                    durationSeconds: completedDuration,
                    currentStreak: streakValue
                )
            }

            // Schedule streak reminder notification for tomorrow
            NotificationService.shared.scheduleStreakReminder(
                streakDays: streakValue,
                dogName: "Your dog"
            )
        }
    }

    // MARK: - Execute Planned Walk

    func executePlannedWalk(_ walk: PlannedWalk) {
        let waypoints = walk.routePolyline.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }

        guard waypoints.count >= 2 else {
            print("[MapScreen] Cannot start planned walk: need at least 2 waypoints")
            startWalk()
            return
        }

        // Center map on the walk start
        let startCoord = waypoints.first!
        region = MKCoordinateRegion(
            center: startCoord,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )

        // Store planned walk ID for completion marking
        pendingPlannedWalk = walk

        // Use RoutingViewModel to fetch the full route, then start guidance
        let origin = waypoints.first!
        let destination = waypoints.last!

        if waypoints.count == 2 {
            routingViewModel.onMapTap(origin: origin, destination: destination, destinationName: walk.title)
        } else {
            // Multi-waypoint: use the via point for circular route generation
            let viaPoint = waypoints[waypoints.count / 2]
            routingViewModel.generateCircularRoute(
                userLocation: origin,
                viaPoint: viaPoint
            )
        }

        // Observe routing state to start guidance once route is ready
        Task {
            for _ in 0..<30 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                if case .previewReady(let preview) = routingViewModel.routingState,
                   let route = preview.route, !preview.isLoading {
                    if let userLoc = locationManager.location {
                        guidanceViewModel.startGuidance(route: route, userLocation: userLoc)
                        walkTrackingViewModel.startWalk()
                        mapViewModel.startWalkTracking()
                        print("[MapScreen] Started guided walk for planned walk: \(walk.title)")
                    }
                    return
                }
            }
            print("[MapScreen] Route fetch timed out for planned walk, starting unguided walk")
            startWalk()
        }
    }

    func markPlannedWalkCompleted(walkId: String) {
        guard let plannedWalk = pendingPlannedWalk, let plannedWalkId = plannedWalk.id else { return }
        let repo = PlannedWalkRepository()
        Task {
            do {
                try await repo.markAsCompleted(plannedWalkId: plannedWalkId, completedWalkId: walkId)
                print("[MapScreen] Marked planned walk \(plannedWalkId) as completed")
            } catch {
                print("[MapScreen] Failed to mark planned walk as completed: \(error.localizedDescription)")
            }
        }
        pendingPlannedWalk = nil
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
            mapViewModel.loadOverpassPOIs(near: location, zoomSpan: region.span.latitudeDelta)
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
                UserDefaults.standard.set(location.latitude, forKey: "carLocationLat")
                UserDefaults.standard.set(location.longitude, forKey: "carLocationLng")
            }
        } else {
            showCarOptionsDialog = true
        }
    }

    func clearCarLocation() {
        carLocation = nil
        UserDefaults.standard.removeObject(forKey: "carLocationLat")
        UserDefaults.standard.removeObject(forKey: "carLocationLng")
    }

    func callPhoneNumber(_ phone: String) {
        if let url = URL(string: "tel://\(phone)") {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Pub Actions

    func openPubInMaps(_ pub: POI) {
        let coordinate = CLLocationCoordinate2D(latitude: pub.lat, longitude: pub.lng)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = pub.title
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }
}
