import Foundation

struct PersonalBestResult: Codable {
    var isNewLongestDistance: Bool
    var isNewLongestDuration: Bool
    var isNewFastestPace: Bool
    var isNewMostSteps: Bool
    var previousBestDistance: Double?
    var previousBestDuration: Int64?
    var previousBestPace: Double?
    var previousBestSteps: Int?
    var currentDistance: Double
    var currentDuration: Int64
    var currentPace: Double?
    var currentSteps: Int

    var hasAnyPersonalBest: Bool {
        isNewLongestDistance || isNewLongestDuration || isNewFastestPace || isNewMostSteps
    }

    init(isNewLongestDistance: Bool = false, isNewLongestDuration: Bool = false, isNewFastestPace: Bool = false, isNewMostSteps: Bool = false, previousBestDistance: Double? = nil, previousBestDuration: Int64? = nil, previousBestPace: Double? = nil, previousBestSteps: Int? = nil, currentDistance: Double = 0, currentDuration: Int64 = 0, currentPace: Double? = nil, currentSteps: Int = 0) {
        self.isNewLongestDistance = isNewLongestDistance; self.isNewLongestDuration = isNewLongestDuration; self.isNewFastestPace = isNewFastestPace; self.isNewMostSteps = isNewMostSteps; self.previousBestDistance = previousBestDistance; self.previousBestDuration = previousBestDuration; self.previousBestPace = previousBestPace; self.previousBestSteps = previousBestSteps; self.currentDistance = currentDistance; self.currentDuration = currentDuration; self.currentPace = currentPace; self.currentSteps = currentSteps
    }
}
