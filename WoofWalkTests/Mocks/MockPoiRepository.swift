import Foundation
import CoreLocation
@testable import WoofWalk

@MainActor
class MockPoiRepository {
    var pois: [POI] = []
    var shouldThrowError = false

    var addPoiCalled = false
    var deletePoiCalled = false
    var votePoiCalled = false

    func getPoisNearby(center: CLLocationCoordinate2D, radiusMeters: Double) async throws -> [POI] {
        guard !shouldThrowError else {
            throw NSError(domain: "MockPoiRepository", code: -1)
        }
        return pois
    }

    func addPoi(_ poi: POI) async throws {
        addPoiCalled = true
        guard !shouldThrowError else {
            throw NSError(domain: "MockPoiRepository", code: -1)
        }
        pois.append(poi)
    }

    func deletePoi(_ poiId: String) async throws {
        deletePoiCalled = true
        guard !shouldThrowError else {
            throw NSError(domain: "MockPoiRepository", code: -1)
        }
        pois.removeAll { $0.id == poiId }
    }

    func votePoi(_ poiId: String, isUpvote: Bool) async throws {
        votePoiCalled = true
        guard !shouldThrowError else {
            throw NSError(domain: "MockPoiRepository", code: -1)
        }
        if let index = pois.firstIndex(where: { $0.id == poiId }) {
            if isUpvote {
                pois[index].voteUp += 1
            } else {
                pois[index].voteDown += 1
            }
        }
    }
}
