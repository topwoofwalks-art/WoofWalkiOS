#if false
import Foundation

class TourPersistence {
    private let userDefaults: UserDefaults
    private let tourCompletionPrefix = "tour_completed_"
    private let stepSeenPrefix = "step_seen_"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func markTourCompleted(_ tourType: TourType) {
        let key = tourCompletionPrefix + tourType.rawValue
        userDefaults.set(true, forKey: key)
        userDefaults.set(Date(), forKey: key + "_date")
    }

    func isTourCompleted(_ tourType: TourType) -> Bool {
        let key = tourCompletionPrefix + tourType.rawValue
        return userDefaults.bool(forKey: key)
    }

    func getTourCompletionDate(_ tourType: TourType) -> Date? {
        let key = tourCompletionPrefix + tourType.rawValue + "_date"
        return userDefaults.object(forKey: key) as? Date
    }

    func markStepSeen(_ stepId: String, for tourType: TourType) {
        let key = stepSeenPrefix + tourType.rawValue + "_" + stepId
        userDefaults.set(true, forKey: key)
    }

    func isStepSeen(_ stepId: String, for tourType: TourType) -> Bool {
        let key = stepSeenPrefix + tourType.rawValue + "_" + stepId
        return userDefaults.bool(forKey: key)
    }

    func getSeenSteps(for tourType: TourType) -> Set<String> {
        var seenSteps: Set<String> = []
        let prefix = stepSeenPrefix + tourType.rawValue + "_"

        for (key, value) in userDefaults.dictionaryRepresentation() {
            if key.hasPrefix(prefix), value as? Bool == true {
                let stepId = String(key.dropFirst(prefix.count))
                seenSteps.insert(stepId)
            }
        }

        return seenSteps
    }

    func resetTour(_ tourType: TourType) {
        let completionKey = tourCompletionPrefix + tourType.rawValue
        userDefaults.removeObject(forKey: completionKey)
        userDefaults.removeObject(forKey: completionKey + "_date")

        let stepPrefix = stepSeenPrefix + tourType.rawValue + "_"
        let keysToRemove = userDefaults.dictionaryRepresentation().keys.filter {
            $0.hasPrefix(stepPrefix)
        }

        for key in keysToRemove {
            userDefaults.removeObject(forKey: key)
        }
    }

    func resetAllTours() {
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let tourKeys = allKeys.filter {
            $0.hasPrefix(tourCompletionPrefix) || $0.hasPrefix(stepSeenPrefix)
        }

        for key in tourKeys {
            userDefaults.removeObject(forKey: key)
        }
    }

    func markTourSkipped(_ tourType: TourType) {
        let key = tourCompletionPrefix + tourType.rawValue + "_skipped"
        userDefaults.set(true, forKey: key)
        userDefaults.set(Date(), forKey: key + "_date")
    }

    func wasTourSkipped(_ tourType: TourType) -> Bool {
        let key = tourCompletionPrefix + tourType.rawValue + "_skipped"
        return userDefaults.bool(forKey: key)
    }

    func setDontShowAgain(_ tourType: TourType) {
        let key = tourCompletionPrefix + tourType.rawValue + "_dont_show"
        userDefaults.set(true, forKey: key)
    }

    func shouldShowTour(_ tourType: TourType) -> Bool {
        let dontShowKey = tourCompletionPrefix + tourType.rawValue + "_dont_show"
        if userDefaults.bool(forKey: dontShowKey) {
            return false
        }

        return !isTourCompleted(tourType) && !wasTourSkipped(tourType)
    }

    func getTourStats(_ tourType: TourType) -> TourStats {
        let completed = isTourCompleted(tourType)
        let skipped = wasTourSkipped(tourType)
        let completionDate = getTourCompletionDate(tourType)
        let seenSteps = getSeenSteps(for: tourType)

        return TourStats(
            tourType: tourType,
            isCompleted: completed,
            isSkipped: skipped,
            completionDate: completionDate,
            seenStepsCount: seenSteps.count
        )
    }

    func getAllTourStats() -> [TourStats] {
        return [
            .initialWalkthrough,
            .socialNavigationDemo,
            .fieldDrawingDemo,
            .mapFeaturesDemo
        ].map { getTourStats($0) }
    }
}

struct TourStats {
    let tourType: TourType
    let isCompleted: Bool
    let isSkipped: Bool
    let completionDate: Date?
    let seenStepsCount: Int

    var status: String {
        if isCompleted {
            return "Completed"
        } else if isSkipped {
            return "Skipped"
        } else if seenStepsCount > 0 {
            return "In Progress"
        } else {
            return "Not Started"
        }
    }
}

extension TourCoordinator {
    func saveTourProgress() {
        guard let current = currentTour else { return }

        let persistence = TourPersistence(userDefaults: userDefaults)

        for stepId in current.completedSteps {
            persistence.markStepSeen(stepId, for: current.tourType)
        }

        if current.state == .completed {
            persistence.markTourCompleted(current.tourType)
        } else if current.state == .skipped {
            persistence.markTourSkipped(current.tourType)
        }
    }

    func loadTourProgress(_ tourType: TourType) -> Set<String> {
        let persistence = TourPersistence(userDefaults: userDefaults)
        return persistence.getSeenSteps(for: tourType)
    }

    func getTourStats(_ tourType: TourType) -> TourStats {
        let persistence = TourPersistence(userDefaults: userDefaults)
        return persistence.getTourStats(tourType)
    }

    func getAllTourStats() -> [TourStats] {
        let persistence = TourPersistence(userDefaults: userDefaults)
        return persistence.getAllTourStats()
    }
}
#endif
