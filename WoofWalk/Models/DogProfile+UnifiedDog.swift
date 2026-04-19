import Foundation

/// Conversion between the legacy `DogProfile` shape (embedded in
/// `UserProfile.dogs[]`) and the modern `UnifiedDog` that lives in
/// `/dogs/{dogId}`.
///
/// During Stage 2 both types coexist. Stage 3 will replace `DogProfile`
/// on the embedded array with a narrower `DogProfilePublic` projection
/// and delete this bridge entirely.
extension DogProfile {

    /// Render as a `UnifiedDog` ready for `DogRepository.addDog` /
    /// `updateDog`. The `primaryOwnerId` is left empty here — the
    /// repository fills it with the current user's uid.
    func toUnifiedDog() -> UnifiedDog {
        // Legacy DogProfile stores birthdate as ISO-8601 string; UnifiedDog
        // stores epoch-millis. Convert when we have one.
        let birthdateMillis: Int64? = birthdate.flatMap { iso in
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            return formatter.date(from: iso).map { Int64($0.timeIntervalSince1970 * 1000) }
        }

        return UnifiedDog(
            id: id,
            name: name,
            breed: breed.isEmpty ? nil : breed,
            photoUrl: photoUrl,
            temperament: temperament.isEmpty ? nil : temperament,
            nervousDog: nervousDog,
            warningNote: warningNote,
            birthdate: birthdateMillis,
            sex: sex,
            neutered: neutered ?? false,
            color: color,
            weight: weight,
            size: size,
            microchipId: microchipId,
            behavioralNotes: behavioralNotes,
            allergies: allergies,
            medications: medications,
            medicalConditions: medicalConditions,
            specialNeeds: specialNeeds,
            dietaryRestrictions: dietaryRestrictions,
            selectedGroomerId: selectedGroomerId
        )
    }
}
