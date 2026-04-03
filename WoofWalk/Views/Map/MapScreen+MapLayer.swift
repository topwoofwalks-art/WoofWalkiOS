import SwiftUI
import MapKit
import CoreLocation

// MARK: - MapScreen Map Layer Extension

extension MapScreen {

    // MARK: - Map Annotations

    var mapAnnotations: [MapMarkerItem] {
        var items: [MapMarkerItem] = []

        // POIs
        for poi in mapViewModel.filteredPOIs {
            items.append(MapMarkerItem(
                id: "poi-\(poi.id)",
                coordinate: poi.coordinate,
                kind: .poi(poi)
            ))
        }

        // Poo bag drops
        for bag in mapViewModel.activeBagDrops {
            items.append(MapMarkerItem(
                id: "bag-\(bag.id)",
                coordinate: bag.coordinate,
                kind: .pooBag(bag)
            ))
        }

        // Public dogs
        for dog in mapViewModel.publicDogs {
            items.append(MapMarkerItem(
                id: "dog-\(dog.id)",
                coordinate: dog.coordinate,
                kind: .publicDog(dog)
            ))
        }

        // Lost dogs
        for dog in mapViewModel.lostDogs {
            items.append(MapMarkerItem(
                id: "lost-\(dog.id)",
                coordinate: dog.coordinate,
                kind: .lostDog(dog)
            ))
        }

        // Car location
        if let car = carLocation {
            items.append(MapMarkerItem(
                id: "car",
                coordinate: car,
                kind: .car
            ))
        }

        // Hazard reports
        items.append(contentsOf: hazardMarkerItems)

        // Trail conditions
        items.append(contentsOf: trailConditionMarkerItems)

        // Off-lead zone labels (center markers)
        for zone in mapViewModel.offLeadZones {
            items.append(MapMarkerItem(
                id: "zone-\(zone.id)",
                coordinate: zone.center,
                kind: .offLeadZoneLabel(zone)
            ))
        }

        // Planning waypoints
        if isPlanningMode {
            let waypoints = mapViewModel.planningWaypoints
            for (index, wp) in waypoints.enumerated() {
                items.append(MapMarkerItem(
                    id: "planning-wp-\(index)",
                    coordinate: wp,
                    kind: .planningWaypoint(
                        index: index,
                        isFirst: index == 0,
                        isLast: index == waypoints.count - 1
                    )
                ))
            }
        }

        return items
    }

    // MARK: - Map Layer View

    var mapLayer: some View {
        Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: mapAnnotations) { item in
            MapAnnotation(coordinate: item.coordinate) {
                switch item.kind {
                case .poi(let poi):
                    POIMarkerView(poi: poi)
                        .onTapGesture { handlePOITap(poi) }
                case .pooBag(let bag):
                    Image(systemName: "bag.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 16))
                        .padding(8)
                        .background(Circle().fill(.orange))
                        .shadow(radius: 3)
                        .onTapGesture { handleBagDropTap(bag) }
                case .publicDog(let dog):
                    Image(systemName: dog.isNervous ? "exclamationmark.triangle.fill" : "pawprint.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 16))
                        .padding(8)
                        .background(Circle().fill(dog.isNervous ? .orange : .blue))
                        .shadow(radius: 3)
                        .onTapGesture { handlePublicDogTap(dog) }
                case .lostDog(let dog):
                    VStack(spacing: 2) {
                        Image(systemName: "exclamationmark.octagon.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 16))
                            .padding(8)
                            .background(Circle().fill(.red))
                            .shadow(radius: 3)
                        Text("LOST")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.red)
                    }
                    .onTapGesture { handleLostDogTap(dog) }
                case .car:
                    Image(systemName: "car.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 16))
                        .padding(8)
                        .background(Circle().fill(.cyan))
                        .shadow(radius: 3)
                case .hazard(let hazard):
                    let hType = HazardType(rawValue: hazard.type)
                    ZStack {
                        Circle()
                            .fill((HazardSeverity(rawValue: hazard.severity) ?? .medium).color)
                            .frame(width: 40, height: 40)
                            .shadow(radius: 3)
                        Text(hType?.emoji ?? "\u{26A0}\u{FE0F}")
                            .font(.system(size: 20))
                    }
                case .trailCondition(let condition):
                    let tType = TrailConditionType(rawValue: condition.type)
                    ZStack {
                        Circle()
                            .fill(tType?.color ?? .gray)
                            .frame(width: 36, height: 36)
                            .shadow(radius: 2)
                        Text(tType?.emoji ?? "\u{2753}")
                            .font(.system(size: 16))
                    }
                case .offLeadZoneLabel(let zone):
                    let zType = ZoneType(rawValue: zone.type)
                    Text(zType?.displayName ?? zone.name)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.regularMaterial))
                        .foregroundColor(zType?.color ?? .gray)
                case .planningWaypoint(let index, let isFirst, let isLast):
                    ZStack {
                        Circle()
                            .fill(isFirst ? Color.green : (isLast ? Color.orange : Color.turquoise60))
                            .frame(width: 28, height: 28)
                            .shadow(radius: 3)
                        Text("\(index + 1)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Planning Overlay

    @ViewBuilder
    var planningOverlay: some View {
        if isPlanningMode {
            PlanningModeOverlay(
                isActive: $isPlanningMode,
                waypoints: mapViewModel.planningWaypoints,
                estimatedDistance: mapViewModel.plannedRouteDistance,
                estimatedDuration: mapViewModel.plannedRouteDuration,
                isLoopClosed: mapViewModel.isLoopClosed,
                canCloseLoop: mapViewModel.planningWaypoints.count >= 3 && !mapViewModel.isLoopClosed,
                closingSegmentPreview: mapViewModel.closingSegmentPreview,
                mapCenterCoordinate: region.center,
                isFetchingRoute: mapViewModel.isFetchingRoute,
                useFootpathRouting: $mapViewModel.useFootpathRouting,
                onAddWaypoint: { mapViewModel.addPlanningWaypoint($0) },
                onRemoveLastWaypoint: { mapViewModel.removeLastPlanningWaypoint() },
                onClearAll: { mapViewModel.clearAllPlanningWaypoints() },
                onCloseLoop: { mapViewModel.closeLoop() },
                onSave: { showSavePlannedWalkDialog = true },
                onStartWalk: { isPlanningMode = false; startWalk() },
                onCancel: { isPlanningMode = false; mapViewModel.clearAllPlanningWaypoints() }
            )
        }
    }
}
