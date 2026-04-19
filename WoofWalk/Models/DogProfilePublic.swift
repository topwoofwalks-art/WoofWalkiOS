import Foundation

/// Public projection of a dog — the only fields stored in the
/// denormalised `users/{uid}.dogs[]` array after the Stage 3 refactor.
///
/// Maintained by the `onDogWrite` Cloud Function from `/dogs/{dogId}`.
/// Crucially does NOT include medications, medication schedules, vet
/// info, vaccinations, allergies, medical conditions, microchip id,
/// weight, weight history, selected groomer/walker/vet, or walk
/// preferences — so reading `users/{friendUid}` directly cannot leak
/// any of that.
///
/// Behavioural warnings stay — safety-relevant for friends who might
/// dog-sit.
struct DogProfilePublic: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var breed: String?
    var birthdate: Int64?      // epoch millis
    var sex: String?
    var neutered: Bool
    var color: String?
    var size: String?
    var photoUrl: String?
    var thumbnailUrl: String?
    var temperament: String?
    var nervousDog: Bool
    var warningNote: String?
    var behavioralNotes: String?

    init(
        id: String = UUID().uuidString,
        name: String = "",
        breed: String? = nil,
        birthdate: Int64? = nil,
        sex: String? = nil,
        neutered: Bool = false,
        color: String? = nil,
        size: String? = nil,
        photoUrl: String? = nil,
        thumbnailUrl: String? = nil,
        temperament: String? = nil,
        nervousDog: Bool = false,
        warningNote: String? = nil,
        behavioralNotes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.breed = breed
        self.birthdate = birthdate
        self.sex = sex
        self.neutered = neutered
        self.color = color
        self.size = size
        self.photoUrl = photoUrl
        self.thumbnailUrl = thumbnailUrl
        self.temperament = temperament
        self.nervousDog = nervousDog
        self.warningNote = warningNote
        self.behavioralNotes = behavioralNotes
    }

    var ageYears: Int {
        guard let bd = birthdate else { return 0 }
        let date = Date(timeIntervalSince1970: TimeInterval(bd) / 1000.0)
        return Calendar.current.dateComponents([.year], from: date, to: Date()).year ?? 0
    }

    /// Build from a full `UnifiedDog`.
    static func from(_ dog: UnifiedDog, thumbnailUrl: String? = nil) -> DogProfilePublic {
        DogProfilePublic(
            id: dog.id ?? "",
            name: dog.name,
            breed: dog.breed,
            birthdate: dog.birthdate,
            sex: dog.sex,
            neutered: dog.neutered,
            color: dog.color,
            size: dog.size,
            photoUrl: dog.photoUrl,
            thumbnailUrl: thumbnailUrl,
            temperament: dog.temperament,
            nervousDog: dog.nervousDog,
            warningNote: dog.warningNote,
            behavioralNotes: dog.behavioralNotes
        )
    }
}
