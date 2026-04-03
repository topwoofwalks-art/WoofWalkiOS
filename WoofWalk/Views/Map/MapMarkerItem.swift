import Foundation
import CoreLocation

// MARK: - Map Marker Item

struct MapMarkerItem: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let kind: Kind

    enum Kind {
        case poi(POI)
        case pooBag(PooBagDrop)
        case publicDog(PublicDog)
        case lostDog(LostDog)
        case car
        case hazard(HazardReport)
        case trailCondition(TrailCondition)
        case offLeadZoneLabel(OffLeadZone)
        case planningWaypoint(index: Int, isFirst: Bool, isLast: Bool)
    }
}
