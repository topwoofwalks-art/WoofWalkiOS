import Foundation
import FirebaseFirestore

/// Medical record for a dog, stored in
/// `/dogs/{dogId}/medicalRecords/{recordId}` and gated to
/// owner/co-owner/org-with-canViewMedical by Firestore rules.
///
/// Individual vaccination / condition / allergy / medication-log /
/// procedure entries live here so the main `/dogs/{dogId}` doc stays
/// free of medical data that would otherwise travel through the
/// embedded `users/{uid}.dogs[]` projection.
struct MedicalRecord: Identifiable, Codable {
    @DocumentID var id: String?
    var dogId: String
    var type: MedicalRecordType
    var title: String
    var description: String
    var recordedAt: Int64                     // epoch millis
    var recordedBy: String
    var sharedWithOrgIds: [String]

    // Vaccination fields (type == .vaccination)
    var vaccinationName: String?
    var veterinarian: String?
    var batchNumber: String?
    var administeredAt: Int64?
    var expiresAt: Int64?
    var documentUrl: String?

    // Condition fields
    var severity: String?                     // MILD | MODERATE | SEVERE
    var diagnosedAt: Int64?
    var isActive: Bool?

    // Allergy fields
    var trigger: String?
    var reaction: String?

    // Forward-compat extras
    var metadata: [String: String]
    var updatedAt: Int64

    init(
        id: String? = nil,
        dogId: String = "",
        type: MedicalRecordType = .note,
        title: String = "",
        description: String = "",
        recordedAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        recordedBy: String = "",
        sharedWithOrgIds: [String] = [],
        vaccinationName: String? = nil,
        veterinarian: String? = nil,
        batchNumber: String? = nil,
        administeredAt: Int64? = nil,
        expiresAt: Int64? = nil,
        documentUrl: String? = nil,
        severity: String? = nil,
        diagnosedAt: Int64? = nil,
        isActive: Bool? = nil,
        trigger: String? = nil,
        reaction: String? = nil,
        metadata: [String: String] = [:],
        updatedAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) {
        self.id = id
        self.dogId = dogId
        self.type = type
        self.title = title
        self.description = description
        self.recordedAt = recordedAt
        self.recordedBy = recordedBy
        self.sharedWithOrgIds = sharedWithOrgIds
        self.vaccinationName = vaccinationName
        self.veterinarian = veterinarian
        self.batchNumber = batchNumber
        self.administeredAt = administeredAt
        self.expiresAt = expiresAt
        self.documentUrl = documentUrl
        self.severity = severity
        self.diagnosedAt = diagnosedAt
        self.isActive = isActive
        self.trigger = trigger
        self.reaction = reaction
        self.metadata = metadata
        self.updatedAt = updatedAt
    }
}

enum MedicalRecordType: String, Codable, CaseIterable {
    case vaccination = "VACCINATION"
    case condition = "CONDITION"
    case allergy = "ALLERGY"
    case dietaryRestriction = "DIETARY_RESTRICTION"
    case specialNeed = "SPECIAL_NEED"
    case procedure = "PROCEDURE"
    case medicationLog = "MEDICATION_LOG"
    case note = "NOTE"
}
