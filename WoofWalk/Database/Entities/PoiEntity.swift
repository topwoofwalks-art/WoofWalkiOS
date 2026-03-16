import SwiftData
import Foundation

@Model
final class PoiEntity {
    @Attribute(.unique) var id: String
    var type: String
    var title: String
    var desc: String
    var lat: Double
    var lng: Double
    var geohash: String
    var photoUrls: String
    var createdBy: String
    var createdAt: Date
    var updatedAt: Date
    var status: String
    var voteUp: Int
    var voteDown: Int
    var regionCode: String
    var expiresAt: Date?
    var accessPublic: Bool
    var accessNotes: String
    var streetAddress: String
    var locality: String
    var administrativeArea: String
    var formattedAddress: String

    init(
        id: String,
        type: String,
        title: String,
        desc: String,
        lat: Double,
        lng: Double,
        geohash: String,
        photoUrls: String,
        createdBy: String,
        createdAt: Date,
        updatedAt: Date,
        status: String,
        voteUp: Int = 0,
        voteDown: Int = 0,
        regionCode: String,
        expiresAt: Date? = nil,
        accessPublic: Bool = true,
        accessNotes: String = "",
        streetAddress: String = "",
        locality: String = "",
        administrativeArea: String = "",
        formattedAddress: String = ""
    ) {
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
        self.accessPublic = accessPublic
        self.accessNotes = accessNotes
        self.streetAddress = streetAddress
        self.locality = locality
        self.administrativeArea = administrativeArea
        self.formattedAddress = formattedAddress
    }

    func toDomain() -> Poi {
        let photoUrlsList = photoUrls.split(separator: ",").map { String($0) }.filter { !$0.isEmpty }

        return Poi(
            id: id,
            type: type,
            title: title,
            desc: desc,
            lat: lat,
            lng: lng,
            geohash: geohash,
            photoUrls: photoUrlsList,
            createdBy: createdBy,
            createdAt: createdAt,
            updatedAt: updatedAt,
            status: status,
            voteUp: voteUp,
            voteDown: voteDown,
            regionCode: regionCode,
            expiresAt: expiresAt,
            access: AccessInfo(isPublic: accessPublic, notes: accessNotes),
            streetAddress: streetAddress,
            locality: locality,
            administrativeArea: administrativeArea,
            formattedAddress: formattedAddress
        )
    }

    static func fromDomain(_ poi: Poi) -> PoiEntity {
        return PoiEntity(
            id: poi.id,
            type: poi.type,
            title: poi.title,
            desc: poi.desc,
            lat: poi.lat,
            lng: poi.lng,
            geohash: poi.geohash,
            photoUrls: poi.photoUrls.joined(separator: ","),
            createdBy: poi.createdBy,
            createdAt: poi.createdAt,
            updatedAt: poi.updatedAt,
            status: poi.status,
            voteUp: poi.voteUp,
            voteDown: poi.voteDown,
            regionCode: poi.regionCode,
            expiresAt: poi.expiresAt,
            accessPublic: poi.access.isPublic,
            accessNotes: poi.access.notes,
            streetAddress: poi.streetAddress,
            locality: poi.locality,
            administrativeArea: poi.administrativeArea,
            formattedAddress: poi.formattedAddress
        )
    }
}
