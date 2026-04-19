import Foundation

// MARK: - Boarding Service Configuration

/// A room type offered by a boarding facility.
struct BoardingRoomType: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var description: String?
    var pricePerNight: Double
    var maxDogs: Int
    var amenities: [String]
    var isActive: Bool

    init(
        id: String = UUID().uuidString,
        name: String = "",
        description: String? = nil,
        pricePerNight: Double = 0.0,
        maxDogs: Int = 1,
        amenities: [String] = [],
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.pricePerNight = pricePerNight
        self.maxDogs = maxDogs
        self.amenities = amenities
        self.isActive = isActive
    }
}

/// A boarding package (e.g. "Luxury Weekend", "Extended Stay").
struct BoardingPackage: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var description: String?
    var nightsIncluded: Int
    var price: Double
    var roomTypeId: String?
    var extras: [String]
    var isActive: Bool

    init(
        id: String = UUID().uuidString,
        name: String = "",
        description: String? = nil,
        nightsIncluded: Int = 1,
        price: Double = 0.0,
        roomTypeId: String? = nil,
        extras: [String] = [],
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.nightsIncluded = nightsIncluded
        self.price = price
        self.roomTypeId = roomTypeId
        self.extras = extras
        self.isActive = isActive
    }
}

/// Full boarding service configuration for a business.
struct BoardingServiceConfig: Codable, Equatable {
    var roomTypes: [BoardingRoomType]
    var packages: [BoardingPackage]
    var totalCapacity: Int
    var checkInTime: String
    var checkOutTime: String
    var requiresVaccinations: Bool
    var requiresTrialNight: Bool

    init(
        roomTypes: [BoardingRoomType] = [],
        packages: [BoardingPackage] = [],
        totalCapacity: Int = 10,
        checkInTime: String = "14:00",
        checkOutTime: String = "11:00",
        requiresVaccinations: Bool = true,
        requiresTrialNight: Bool = false
    ) {
        self.roomTypes = roomTypes
        self.packages = packages
        self.totalCapacity = totalCapacity
        self.checkInTime = checkInTime
        self.checkOutTime = checkOutTime
        self.requiresVaccinations = requiresVaccinations
        self.requiresTrialNight = requiresTrialNight
    }
}
