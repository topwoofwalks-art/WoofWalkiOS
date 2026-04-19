import Foundation

// MARK: - Daycare Service Configuration

/// A daycare package (e.g. "Full Day", "Half Day", "5-Day Bundle").
struct DaycarePackage: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var description: String?
    var durationHours: Double
    var price: Double
    var sessionsIncluded: Int
    var isActive: Bool

    init(
        id: String = UUID().uuidString,
        name: String = "",
        description: String? = nil,
        durationHours: Double = 8.0,
        price: Double = 0.0,
        sessionsIncluded: Int = 1,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.durationHours = durationHours
        self.price = price
        self.sessionsIncluded = sessionsIncluded
        self.isActive = isActive
    }
}

/// A structured activity programme offered during daycare.
struct DaycareActivityProgramme: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var description: String?
    var activities: [String]
    var isActive: Bool

    init(
        id: String = UUID().uuidString,
        name: String = "",
        description: String? = nil,
        activities: [String] = [],
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.activities = activities
        self.isActive = isActive
    }
}

/// Full daycare service configuration for a business.
struct DaycareServiceConfig: Codable, Equatable {
    var packages: [DaycarePackage]
    var openTime: String
    var closeTime: String
    var totalCapacity: Int
    var activities: [DaycareActivityProgramme]
    var requiresAssessment: Bool

    init(
        packages: [DaycarePackage] = [],
        openTime: String = "07:00",
        closeTime: String = "19:00",
        totalCapacity: Int = 20,
        activities: [DaycareActivityProgramme] = [],
        requiresAssessment: Bool = true
    ) {
        self.packages = packages
        self.openTime = openTime
        self.closeTime = closeTime
        self.totalCapacity = totalCapacity
        self.activities = activities
        self.requiresAssessment = requiresAssessment
    }
}
