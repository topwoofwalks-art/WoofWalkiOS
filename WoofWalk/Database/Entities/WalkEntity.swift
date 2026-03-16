import SwiftData
import Foundation

@Model
final class WalkEntity {
    @Attribute(.unique) var id: String
    var userId: String
    var startedAt: Date
    var endedAt: Date?
    var distanceMeters: Int
    var durationSec: Int
    var trackJson: String
    var polyline: String
    var dogIdsJson: String
    var syncedToFirestore: Bool

    init(
        id: String,
        userId: String,
        startedAt: Date,
        endedAt: Date? = nil,
        distanceMeters: Int,
        durationSec: Int,
        trackJson: String,
        polyline: String,
        dogIdsJson: String = "[]",
        syncedToFirestore: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.distanceMeters = distanceMeters
        self.durationSec = durationSec
        self.trackJson = trackJson
        self.polyline = polyline
        self.dogIdsJson = dogIdsJson
        self.syncedToFirestore = syncedToFirestore
    }

    func toDomain() -> WalkHistory {
        let decoder = JSONDecoder()
        let trackPoints = (try? decoder.decode([TrackPoint].self, from: trackJson.data(using: .utf8) ?? Data())) ?? []
        let dogIds = (try? decoder.decode([String].self, from: dogIdsJson.data(using: .utf8) ?? Data())) ?? []

        return WalkHistory(
            id: id,
            userId: userId,
            startedAt: startedAt,
            endedAt: endedAt,
            distanceMeters: distanceMeters,
            durationSec: durationSec,
            track: trackPoints,
            polyline: polyline,
            dogIds: dogIds
        )
    }

    static func fromDomain(_ walk: WalkHistory, syncedToFirestore: Bool = false) -> WalkEntity {
        let encoder = JSONEncoder()
        let trackJson = (try? encoder.encode(walk.track)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        let dogIdsJson = (try? encoder.encode(walk.dogIds)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

        return WalkEntity(
            id: walk.id,
            userId: walk.userId,
            startedAt: walk.startedAt,
            endedAt: walk.endedAt,
            distanceMeters: walk.distanceMeters,
            durationSec: walk.durationSec,
            trackJson: trackJson,
            polyline: walk.polyline,
            dogIdsJson: dogIdsJson,
            syncedToFirestore: syncedToFirestore
        )
    }
}
