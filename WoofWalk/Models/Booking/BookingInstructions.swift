import Foundation

/// Special instructions for a booking, matching Android's BookingInstructions model.
struct BookingInstructions: Codable, Equatable {
    var accessInstructions: String = ""
    var pickupInstructions: String = ""
    var feedingInstructions: String = ""
    var medicationInstructions: String = ""
    var emergencyContact: String = ""
    var additionalNotes: String = ""

    /// Whether any instructions have been provided
    var hasAnyInstructions: Bool {
        !accessInstructions.isEmpty ||
        !pickupInstructions.isEmpty ||
        !feedingInstructions.isEmpty ||
        !medicationInstructions.isEmpty ||
        !emergencyContact.isEmpty ||
        !additionalNotes.isEmpty
    }
}

/// Health information for a booking, matching Android's BookingHealthInfo model.
struct BookingHealthInfo: Codable, Equatable {
    var vaccinationsUpToDate: Bool = false
    var vaccinationRecordUrl: String?
    var hasAllergies: Bool = false
    var allergyDetails: String?
    var hasMedicalConditions: Bool = false
    var medicalDetails: String?
    var vetPhone: String?
    var emergencyVetPreferred: Bool = false
    var specialInstructions: String?
}
