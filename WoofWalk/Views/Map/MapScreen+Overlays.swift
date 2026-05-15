import SwiftUI
import MapKit
import CoreLocation

// MARK: - MapScreen Overlays Extension

extension MapScreen {

    // MARK: - Hazard Markers

    var hazardMarkerItems: [MapMarkerItem] {
        mapViewModel.hazardReports
            .filter { !$0.isExpired }
            .map { hazard in
                MapMarkerItem(
                    id: "hazard-\(hazard.id ?? UUID().uuidString)",
                    coordinate: hazard.coordinate,
                    kind: .hazard(hazard)
                )
            }
    }

    // MARK: - Trail Condition Markers

    var trailConditionMarkerItems: [MapMarkerItem] {
        mapViewModel.trailConditions
            .filter { !$0.isExpired }
            .map { condition in
                MapMarkerItem(
                    id: "trail-\(condition.id ?? UUID().uuidString)",
                    coordinate: condition.coordinate,
                    kind: .trailCondition(condition)
                )
            }
    }

    // MARK: - Hazard Alert Banner Overlay

    var hazardAlertOverlay: some View {
        VStack {
            HazardAlertBannerContainer(
                hazards: mapViewModel.hazardReports,
                userLocation: locationManager.location,
                onReroute: { hazard in
                    handleHazardReroute(hazard)
                },
                dismissedHazardIds: $dismissedHazardIds
            )
            Spacer()
        }
        .padding(.top, 8)
    }

    // MARK: - Hazard Marker View

    @ViewBuilder
    func hazardMarkerView(for hazard: HazardReport) -> some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(hazard.hazardSeverity.color)
                    .frame(width: 36, height: 36)
                    .shadow(color: hazard.hazardSeverity.color.opacity(0.5), radius: 4)

                Image(systemName: hazard.hazardType.iconName)
                    .foregroundColor(.white)
                    .font(.system(size: 16))
            }

            Text(hazard.hazardType.emoji)
                .font(.system(size: 10))
        }
    }

    // MARK: - Trail Condition Marker View

    @ViewBuilder
    func trailConditionMarkerView(for condition: TrailCondition) -> some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(condition.conditionType.color)
                    .frame(width: 32, height: 32)
                    .shadow(radius: 3)

                Image(systemName: condition.conditionType.iconName)
                    .foregroundColor(.white)
                    .font(.system(size: 14))
            }

            if condition.voteScore != 0 {
                HStack(spacing: 2) {
                    Image(systemName: condition.voteScore > 0 ? "arrow.up" : "arrow.down")
                        .font(.system(size: 7))
                    Text("\(abs(condition.voteScore))")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundColor(condition.voteScore > 0 ? .green : .red)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(
                    Capsule().fill(.regularMaterial)
                )
            }
        }
    }

    // MARK: - Off-Lead Zone Label View

    @ViewBuilder
    func offLeadZoneLabelView(for zone: OffLeadZone) -> some View {
        HStack(spacing: 4) {
            Text(zone.zoneType.emoji)
                .font(.system(size: 12))
            Text(zone.name)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(zone.zoneType.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(radius: 2)
        )
    }

    // MARK: - Dog Match Overlay (reactive-dog parity)

    /// Floating card at the top of the map when the reactive-dog
    /// matcher surfaces a compatible nearby dog. Mirrors Android
    /// `DogMatchOverlay`. Shows one match at a time; tapping the X
    /// dismisses locally (see `MapViewModel.dismissedDogMatchIds`)
    /// and the next un-dismissed match takes its place.
    @ViewBuilder
    var dogMatchOverlay: some View {
        if let match = mapViewModel.activeDogMatch {
            VStack {
                DogMatchCard(
                    match: match,
                    onWave: {
                        DogMatchWaveAction.sendWave(toOwnerUid: match.ownerUid)
                        mapViewModel.dismissDogMatch(match.id)
                    },
                    onDismiss: {
                        mapViewModel.dismissDogMatch(match.id)
                    }
                )
                .id(match.id) // re-instantiate when match changes so auto-dismiss timer resets
                Spacer()
            }
            .padding(.top, 80) // below hazard banner / RAG pill row
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Reroute Handler

    func handleHazardReroute(_ hazard: HazardReport) {
        guard let userLocation = locationManager.location else { return }

        // Calculate a detour around the hazard by offsetting perpendicular to the
        // user-hazard line, then routing through the offset point.
        let hazardLoc = hazard.coordinate
        let latDiff = hazardLoc.latitude - userLocation.latitude
        let lngDiff = hazardLoc.longitude - userLocation.longitude

        // Perpendicular offset (~200m, roughly 0.002 degrees)
        let offsetLat = hazardLoc.latitude + lngDiff * 0.002 / max(abs(lngDiff) + abs(latDiff), 0.0001)
        let offsetLng = hazardLoc.longitude - latDiff * 0.002 / max(abs(lngDiff) + abs(latDiff), 0.0001)

        let detourPoint = CLLocationCoordinate2D(latitude: offsetLat, longitude: offsetLng)
        routingViewModel.generateCircularRoute(userLocation: userLocation, viaPoint: detourPoint)
    }
}

// MARK: - Extended MapMarkerItem Kind

extension MapMarkerItem.Kind {
    // Note: These cases need to be added to the MapMarkerItem.Kind enum
    // in MapScreen.swift. The extension here documents the intended additions:
    //
    // case hazard(HazardReport)
    // case trailCondition(TrailCondition)
    // case offLeadZoneLabel(OffLeadZone)
}
