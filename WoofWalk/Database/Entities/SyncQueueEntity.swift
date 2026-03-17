#if false
import SwiftData
import Foundation

@Model
final class SyncQueueEntity {
    var id: Int64
    var entityType: String
    var entityId: String
    var operation: String
    var data: String
    var timestamp: Date
    var retryCount: Int
    var lastError: String?

    init(
        id: Int64 = 0,
        entityType: String,
        entityId: String,
        operation: String,
        data: String,
        timestamp: Date = Date(),
        retryCount: Int = 0,
        lastError: String? = nil
    ) {
        self.id = id
        self.entityType = entityType
        self.entityId = entityId
        self.operation = operation
        self.data = data
        self.timestamp = timestamp
        self.retryCount = retryCount
        self.lastError = lastError
    }

    enum EntityType {
        static let poi = "poi"
        static let walk = "walk"
        static let comment = "comment"
        static let vote = "vote"
    }

    enum Operation {
        static let create = "create"
        static let update = "update"
        static let delete = "delete"
    }
}

#endif
