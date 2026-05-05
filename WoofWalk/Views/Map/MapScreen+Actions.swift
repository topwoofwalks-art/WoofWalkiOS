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

    func handleLostDogTap(_ dog: LostDogAnnotation) {
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

        // Charity ad gate — mirrors Android DogSelectionSheet flow.
        // If the user has charity mode enabled AND has picked a
        // charity, show the rewarded-ad pre-screen. They can watch
        // (earns points at walk-end) or skip (walk starts, no points).
        // Either way the walk starts. Anyone with charity off goes
        // straight through.
        let charityEnabled = CharityRepository.shared.isCharityEnabled()
        let charityId = CharityRepository.shared.getSelectedCharityId()
        if charityEnabled && !charityId.isEmpty {
            CharityRepository.shared.setCharityAdWatched(false)
            showCharityAdPreScreen = true
            return
        }

        // No charity → start immediately.
        CharityRepository.shared.setCharityAdWatched(false)
        walkTrackingViewModel.startWalk()
        mapViewModel.startWalkTracking()
    }

    /// Called from the CharityAdPreScreen "Watch Ad & Walk" button.
    /// Presents the rewarded interstitial; on reward sets the flag,
    /// on dismiss starts the walk. On any failure starts walk anyway
    /// (no points awarded — the gate stays false).
    func chargeCharityAdAndStart() {
        showCharityAdPreScreen = false
        guard let root = topViewController() else {
            // No window/root — degrade gracefully and start walk.
            walkTrackingViewModel.startWalk()
            mapViewModel.startWalkTracking()
            return
        }
        Task { @MainActor in
            await CharityAdManager.shared.requestTrackingAuthorizationIfNeeded()
            CharityAdManager.shared.showAd(
                from: root,
                onRewardEarned: {
                    CharityRepository.shared.setCharityAdWatched(true)
                },
                onAdDismissed: {
                    walkTrackingViewModel.startWalk()
                    mapViewModel.startWalkTracking()
                },
                onAdFailed: {
                    print("[startWalk] ad not ready, starting walk without charity points")
                    CharityRepository.shared.setCharityAdWatched(false)
                    walkTrackingViewModel.startWalk()
                    mapViewModel.startWalkTracking()
                }
            )
        }
    }

    /// Called from the CharityAdPreScreen "Skip Ad & Walk" button.
    func skipCharityAdAndStart() {
        showCharityAdPreScreen = false
        CharityRepository.shared.setCharityAdWatched(false)
        walkTrackingViewModel.startWalk()
        mapViewModel.startWalkTracking()
    }

    /// Walk the responder chain on the foreground key window to find
    /// the top-most presented view controller. AdMob's
    /// rewardedInterstitialAd.present(from:) needs a UIViewController
    /// to host the ad. SwiftUI doesn't expose one directly so this
    /// reaches into UIApplication.
    private func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
        guard let windowScene = scenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return nil }
        var top = rootVC
        while let presented = top.presentedViewController { top = presented }
        return top
    }

    func stopWalk() {
        // Use max of both sources - walkTrackingVM accumulates from GPS, mapViewModel from polyline
        completedDistance = max(walkTrackingViewModel.walkDistance, mapViewModel.walkDistance)
        completedDuration = Int(walkTrackingViewModel.walkDuration)
        // Reset charity state — populated below once recordCharityPoints
        // returns. The recap sheet hides the card while these are 0/empty.
        completedCharityPoints = 0
        completedCharityName = ""
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

            // Record charity points if eligible (matches Android
            // WalkTrackingViewModel.recordCharityPoints) AND surface them
            // to the recap. Pre-fix the recording fired but the UI never
            // saw the result — user reported "Walk-for-Charity not built
            // yet" because their walks raised silent points with no
            // visible feedback.
            let charityPoints = await CharityRepository.shared.recordCharityPoints(
                distanceMeters: completedDistance
            )
            if charityPoints > 0 {
                let charityId = CharityRepository.shared.getSelectedCharityId()
                let charityName = CharityRepository.shared.getCharityName(charityId)
                await MainActor.run {
                    completedCharityPoints = charityPoints
                    completedCharityName = charityName
                }
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
