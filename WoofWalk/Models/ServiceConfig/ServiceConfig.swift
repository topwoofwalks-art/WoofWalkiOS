import Foundation

// MARK: - Service Configuration Map

/// Top-level container for all per-service-type configurations.
/// Each field is optional — a business only populates configs for services it offers.
struct ServiceConfigMap: Codable, Equatable {
    var grooming: GroomingServiceConfig?
    var boarding: BoardingServiceConfig?
    var training: TrainingServiceConfig?
    var walk: WalkServiceConfig?
    var daycare: DaycareServiceConfig?
    var sitting: SittingServiceConfig?

    init(
        grooming: GroomingServiceConfig? = nil,
        boarding: BoardingServiceConfig? = nil,
        training: TrainingServiceConfig? = nil,
        walk: WalkServiceConfig? = nil,
        daycare: DaycareServiceConfig? = nil,
        sitting: SittingServiceConfig? = nil
    ) {
        self.grooming = grooming
        self.boarding = boarding
        self.training = training
        self.walk = walk
        self.daycare = daycare
        self.sitting = sitting
    }
}
