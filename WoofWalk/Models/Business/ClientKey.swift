import Foundation
import FirebaseFirestore

// MARK: - Key Type

/// Type of physical key or access mechanism.
enum KeyType: String, Codable, CaseIterable, Identifiable {
    case fob
    case physical
    case card
    case smartLock
    case combination

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fob: return "Key Fob"
        case .physical: return "Physical Key"
        case .card: return "Key Card"
        case .smartLock: return "Smart Lock"
        case .combination: return "Combination"
        }
    }

    var icon: String {
        switch self {
        case .fob: return "wave.3.right"
        case .physical: return "key.fill"
        case .card: return "creditcard.fill"
        case .smartLock: return "lock.fill"
        case .combination: return "number"
        }
    }
}

// MARK: - Key Status

/// Current status/location of the key.
enum KeyStatus: String, Codable, CaseIterable, Identifiable {
    case withClient
    case withWalker
    case inOffice
    case lost
    case returned

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .withClient: return "With Client"
        case .withWalker: return "With Walker"
        case .inOffice: return "In Office"
        case .lost: return "Lost"
        case .returned: return "Returned"
        }
    }

    var color: String {
        switch self {
        case .withClient: return "blue"
        case .withWalker: return "orange"
        case .inOffice: return "green"
        case .lost: return "red"
        case .returned: return "gray"
        }
    }
}

// MARK: - Key Action

/// Action performed on a key during a scan.
enum KeyAction: String, Codable, CaseIterable, Identifiable {
    case pickup
    case `return`
    case verified
    case lookup

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pickup: return "Picked Up"
        case .return: return "Returned"
        case .verified: return "Verified"
        case .lookup: return "Looked Up"
        }
    }

    var icon: String {
        switch self {
        case .pickup: return "arrow.up.circle.fill"
        case .return: return "arrow.down.circle.fill"
        case .verified: return "checkmark.circle.fill"
        case .lookup: return "magnifyingglass.circle.fill"
        }
    }

    /// The resulting key status after this action is performed.
    var resultingStatus: KeyStatus? {
        switch self {
        case .pickup: return .withWalker
        case .return: return .inOffice
        case .verified, .lookup: return nil // Status unchanged
        }
    }

    var successMessage: String {
        switch self {
        case .pickup: return "Key picked up successfully"
        case .return: return "Key returned successfully"
        case .verified: return "Key verified"
        case .lookup: return "Key details retrieved"
        }
    }
}

// MARK: - Client Key

/// Represents a client's key/fob for property access.
/// Matches Android Firestore structure: organizations/{userId}/keys/{keyCode}
struct ClientKey: Identifiable, Codable {
    @DocumentID var id: String?
    var clientId: String
    var clientName: String
    var keyType: String  // Raw Firestore value; use keyTypeEnum for typed access
    var keyCode: String
    var status: String   // Raw Firestore value; use statusEnum for typed access
    var address: String
    var accessInstructions: String
    var notes: String
    var createdAt: Int64
    var lastScannedAt: Int64?
    var lastScannedBy: String?

    // MARK: - Computed Properties

    var keyTypeEnum: KeyType {
        KeyType(rawValue: keyType) ?? .physical
    }

    var statusEnum: KeyStatus {
        KeyStatus(rawValue: status) ?? .withClient
    }

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case clientId
        case clientName
        case keyType
        case keyCode
        case status
        case address
        case accessInstructions
        case notes
        case createdAt
        case lastScannedAt
        case lastScannedBy
    }

    // MARK: - Convenience Init

    init(
        id: String? = nil,
        clientId: String = "",
        clientName: String = "",
        keyType: String = KeyType.physical.rawValue,
        keyCode: String = "",
        status: String = KeyStatus.withClient.rawValue,
        address: String = "",
        accessInstructions: String = "",
        notes: String = "",
        createdAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        lastScannedAt: Int64? = nil,
        lastScannedBy: String? = nil
    ) {
        self.id = id
        self.clientId = clientId
        self.clientName = clientName
        self.keyType = keyType
        self.keyCode = keyCode
        self.status = status
        self.address = address
        self.accessInstructions = accessInstructions
        self.notes = notes
        self.createdAt = createdAt
        self.lastScannedAt = lastScannedAt
        self.lastScannedBy = lastScannedBy
    }
}

// MARK: - Key Scan Record

/// A record of a key scan event.
/// Stored in Firestore at: organizations/{userId}/scanRecords/{id}
struct KeyScanRecord: Identifiable, Codable {
    @DocumentID var id: String?
    var keyId: String
    var keyCode: String
    var clientName: String
    var action: String  // Raw Firestore value; use actionEnum for typed access
    var scannedBy: String
    var timestamp: Int64
    var notes: String
    var location: String?

    // MARK: - Computed Properties

    var actionEnum: KeyAction {
        KeyAction(rawValue: action) ?? .lookup
    }

    var timestampDate: Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
    }

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case keyId
        case keyCode
        case clientName
        case action
        case scannedBy
        case timestamp
        case notes
        case location
    }

    // MARK: - Convenience Init

    init(
        id: String? = nil,
        keyId: String,
        keyCode: String = "",
        clientName: String = "",
        action: String = KeyAction.lookup.rawValue,
        scannedBy: String = "",
        timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        notes: String = "",
        location: String? = nil
    ) {
        self.id = id
        self.keyId = keyId
        self.keyCode = keyCode
        self.clientName = clientName
        self.action = action
        self.scannedBy = scannedBy
        self.timestamp = timestamp
        self.notes = notes
        self.location = location
    }
}
