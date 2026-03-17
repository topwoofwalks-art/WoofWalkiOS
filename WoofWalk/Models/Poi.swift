import Foundation
import FirebaseFirestore

struct Poi: Identifiable, Codable {
    @DocumentID var id: String?
    var type: String
    var title: String
    var desc: String
    var lat: Double
    var lng: Double
    var geohash: String
    var photoUrls: [String]
    var createdBy: String
    @ServerTimestamp var createdAt: Timestamp?
    @ServerTimestamp var updatedAt: Timestamp?
    var status: String
    var voteUp: Int
    var voteDown: Int
    var regionCode: String
    var expiresAt: Timestamp?
    var access: AccessInfo?
    var streetAddress: String
    var locality: String
    var administrativeArea: String
    var formattedAddress: String

    init(id: String? = nil,
         type: String = PoiType.bin.rawValue,
         title: String = "",
         desc: String = "",
         lat: Double = 0.0,
         lng: Double = 0.0,
         geohash: String = "",
         photoUrls: [String] = [],
         createdBy: String = "",
         createdAt: Timestamp? = nil,
         updatedAt: Timestamp? = nil,
         status: String = PoiStatus.active.rawValue,
         voteUp: Int = 0,
         voteDown: Int = 0,
         regionCode: String = "",
         expiresAt: Timestamp? = nil,
         access: AccessInfo? = nil,
         streetAddress: String = "",
         locality: String = "",
         administrativeArea: String = "",
         formattedAddress: String = "") {
        self.id = id
        self.type = type
        self.title = title
        self.desc = desc
        self.lat = lat
        self.lng = lng
        self.geohash = geohash
        self.photoUrls = photoUrls
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.status = status
        self.voteUp = voteUp
        self.voteDown = voteDown
        self.regionCode = regionCode
        self.expiresAt = expiresAt
        self.access = access
        self.streetAddress = streetAddress
        self.locality = locality
        self.administrativeArea = administrativeArea
        self.formattedAddress = formattedAddress
    }

    func getPoiType() -> PoiType {
        return PoiType(rawValue: type) ?? .bin
    }

    func getPoiStatus() -> PoiStatus {
        return PoiStatus(rawValue: status) ?? .active
    }

    func isExpired() -> Bool {
        guard let expiresAt = expiresAt else { return false }
        return expiresAt.dateValue() < Date()
    }

    func getDisplayLocation() -> String {
        if !formattedAddress.isEmpty {
            return formattedAddress
        } else if !streetAddress.isEmpty {
            return streetAddress
        } else {
            return String(format: "%.6f, %.6f", lat, lng)
        }
    }
}

// AccessInfo is defined in Models/POI/POI.swift

struct Comment: Identifiable, Codable {
    @DocumentID var id: String?
    var poiId: String
    var authorId: String
    var authorName: String
    var text: String
    @ServerTimestamp var createdAt: Timestamp?
    var voteUp: Int

    init(id: String? = nil,
         poiId: String = "",
         authorId: String = "",
         authorName: String = "",
         text: String = "",
         createdAt: Timestamp? = nil,
         voteUp: Int = 0) {
        self.id = id
        self.poiId = poiId
        self.authorId = authorId
        self.authorName = authorName
        self.text = text
        self.createdAt = createdAt
        self.voteUp = voteUp
    }
}
