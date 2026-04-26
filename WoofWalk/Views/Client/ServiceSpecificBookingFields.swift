import SwiftUI
import FirebaseFirestore

// MARK: - Booking Dog Details (rich capture for grooming / walking / sitting)
//
// Spec: design_audit_2026_04_26_portal_services/06_booking_dog_details.md
//
// Every field is a `(value, isDirty)` pair. Profile preload only writes to
// fields where `isDirty == false` so a back-nav into the step doesn't
// clobber edits the user's already made.

struct DirtyField<T: Equatable>: Equatable {
    var value: T
    var isDirty: Bool = false

    mutating func set(_ newValue: T) {
        value = newValue
        isDirty = true
    }

    /// Apply a profile-derived prefill. Only writes when the user hasn't
    /// touched the field yet. Returns true if the value actually changed.
    @discardableResult
    mutating func prefill(_ candidate: T) -> Bool {
        guard !isDirty else { return false }
        if value == candidate { return false }
        value = candidate
        return true
    }
}

/// Canonical four-chip dog size. Matches `DogSize` in
/// `app/.../ServiceConfig.kt:342` and the portal's wizard.
enum DogSizeOption: String, CaseIterable, Identifiable {
    case small  = "S"
    case medium = "M"
    case large  = "L"
    case giant  = "XL"

    var id: String { rawValue }

    var displayLabel: String {
        switch self {
        case .small:  return "Small"
        case .medium: return "Medium"
        case .large:  return "Large"
        case .giant:  return "Giant"
        }
    }

    /// Map free-form profile.size → canonical chip. Mirrors
    /// `DogSize.fromString` in ServiceConfig.kt:357-358.
    static func fromString(_ raw: String?) -> DogSizeOption? {
        guard let s = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !s.isEmpty else { return nil }
        switch s {
        case "s", "small": return .small
        case "m", "med", "medium": return .medium
        case "l", "large": return .large
        case "xl", "giant", "extra large", "extra-large", "extralarge": return .giant
        default: return nil
        }
    }
}

// MARK: - Per-Vertical Detail Bags

/// Walking-specific rich details. Mirrors §4b of the spec.
struct WalkBookingDetails: Equatable {
    var leadManners: DirtyField<String> = .init(value: "")
    var offLeadAllowed: DirtyField<Bool> = .init(value: false)
    var offLeadWaiverAccepted: DirtyField<Bool> = .init(value: false)
    var offLeadWaiverAt: Int64? = nil
    var recallReliability: DirtyField<String> = .init(value: "")
    var dogTolerance: DirtyField<String> = .init(value: "")
    var strangerTolerance: DirtyField<String> = .init(value: "")
    var fearTriggers: DirtyField<Set<String>> = .init(value: [])
    var pickupAddress: DirtyField<String> = .init(value: "")
    var gateCode: DirtyField<String> = .init(value: "")
    var keysOrLockbox: DirtyField<String> = .init(value: "")
    var dogBag: DirtyField<Set<String>> = .init(value: [])
    var callMeIf: DirtyField<Set<String>> = .init(value: [])
    var photoPolicy: DirtyField<String> = .init(value: "Yes please")

    static let leadMannersOptions = ["Loose lead", "Light puller", "Strong puller", "Reactive on lead"]
    static let recallOptions = ["Bombproof", "Usually comes back", "Hit or miss", "Long-line only"]
    static let dogToleranceOptions = ["Loves them", "Selective", "Nervous", "Reactive", "Don't allow approach"]
    static let strangerToleranceOptions = ["Loves everyone", "Cautious", "Barks", "Reactive"]
    static let fearTriggerOptions = [
        "Bikes", "Scooters", "Skateboards", "Hi-vis", "Men", "Children",
        "Loud noises", "Bin lorries", "Sirens", "Other dogs", "Cats"
    ]
    static let dogBagOptions = [
        "Treats", "Poo bags", "Water", "Towel", "Coat",
        "Toy", "Long-line", "Muzzle", "Med (carry only)"
    ]
    static let callMeIfOptions = [
        "Paw injury", "Limping", "Vomiting", "Abnormal poo",
        "Won't walk", "Hot weather concern", "Other dog incident", "Lost collar/tag"
    ]
    static let photoPolicyOptions = ["Yes please", "Just one selfie", "No need"]

    /// Server payload — keys mirror the portal/Android shape so the booking
    /// detail screen renders the same field names. See spec §7.
    func toPayload() -> [String: Any] {
        var dict: [String: Any] = [
            "leadManners": leadManners.value,
            "offLeadAllowed": offLeadAllowed.value,
            "recallReliability": recallReliability.value,
            "dogTolerance": dogTolerance.value,
            "strangerTolerance": strangerTolerance.value,
            "fearTriggers": Array(fearTriggers.value).sorted(),
            "pickupAddress": pickupAddress.value,
            "gateCode": gateCode.value,
            "keysOrLockbox": keysOrLockbox.value,
            "dogBag": Array(dogBag.value).sorted(),
            "callMeIf": Array(callMeIf.value).sorted(),
            "photoPolicy": photoPolicy.value
        ]
        if offLeadAllowed.value && offLeadWaiverAccepted.value {
            dict["offLeadWaiverAt"] = offLeadWaiverAt ?? Int64(Date().timeIntervalSince1970 * 1000)
        }
        return dict
    }
}

/// Grooming-specific rich details. Mirrors §4a of the spec.
struct GroomingBookingDetails: Equatable {
    var coatType: DirtyField<Set<String>> = .init(value: [])
    var coatCondition: DirtyField<String> = .init(value: "")
    var lastGroomDate: DirtyField<Date?> = .init(value: nil)
    var allergies: DirtyField<String> = .init(value: "")
    var groomStyle: DirtyField<String> = .init(value: "")
    var lengthPreference: DirtyField<String> = .init(value: "")
    var additionalServices: DirtyField<Set<String>> = .init(value: [])
    var behaviour: DirtyField<String> = .init(value: "")
    var sensitiveAreas: DirtyField<Set<String>> = .init(value: [])
    var handlingNotes: DirtyField<String> = .init(value: "")

    static let coatTypeOptions = ["Smooth", "Wire", "Curly", "Double", "Long", "Poodle-cross", "Other"]
    static let coatConditionOptions = ["Clean", "Shedding", "Tangled", "Matted", "Heavily matted"]
    static let groomStyleOptions = [
        "Breed standard", "Puppy cut", "Teddy bear",
        "Short summer", "Long & tidy", "I'm not sure"
    ]
    static let lengthOptions = ["Very short", "Short", "Medium", "Long", "Leave length"]
    static let additionalServiceOptions = [
        "De-shed", "Hand-strip", "Teeth brush", "Anal glands",
        "Ear pluck", "Ear clean", "Nail trim", "Nail grind",
        "Sanitary trim", "Paw pad trim", "Face trim",
        "Blueberry facial", "Aromatherapy"
    ]
    static let behaviourOptions = [
        "Calm", "Wriggly", "Anxious", "First time", "Aggressive — muzzle needed"
    ]
    static let sensitiveAreaOptions = ["Paws", "Ears", "Tail", "Belly", "Mouth", "Hindquarters"]

    func toPayload() -> [String: Any] {
        var dict: [String: Any] = [
            "coatType": Array(coatType.value).sorted(),
            "coatCondition": coatCondition.value,
            "allergies": allergies.value,
            "style": groomStyle.value,
            "lengthPreference": lengthPreference.value,
            "additionalServices": Array(additionalServices.value).sorted(),
            "behaviour": behaviour.value,
            "sensitiveAreas": Array(sensitiveAreas.value).sorted(),
            "handlingNotes": handlingNotes.value
        ]
        if let lgd = lastGroomDate.value {
            dict["lastGroomDate"] = Int64(lgd.timeIntervalSince1970 * 1000)
        }
        return dict
    }
}

/// Sitting-specific rich details. Mirrors §4c of the spec.
struct SittingBookingDetails: Equatable {
    var vaccinationOK: DirtyField<Bool> = .init(value: false)
    var neutered: DirtyField<Bool> = .init(value: false)
    var microchipId: DirtyField<String> = .init(value: "")

    var accessMethod: DirtyField<String> = .init(value: "")
    var accessNotes: DirtyField<String> = .init(value: "")
    var alarmCode: DirtyField<String> = .init(value: "")

    var feedingMorning: DirtyField<String> = .init(value: "")
    var feedingEvening: DirtyField<String> = .init(value: "")
    var feedingMidday: DirtyField<String> = .init(value: "")
    var foodLocation: DirtyField<String> = .init(value: "")
    var amountPerMeal: DirtyField<String> = .init(value: "")
    var treatsAllowed: DirtyField<Bool> = .init(value: true)
    var treatNotes: DirtyField<String> = .init(value: "")

    var medications: DirtyField<[SittingMedicationEntry]> = .init(value: [])

    var allowedRooms: DirtyField<Set<String>> = .init(value: [])
    var offLimitsAreas: DirtyField<String> = .init(value: "")
    var sleepLocation: DirtyField<String> = .init(value: "")
    var bedtimeRitual: DirtyField<String> = .init(value: "")
    var soundsToAvoid: DirtyField<Set<String>> = .init(value: [])

    var vetName: DirtyField<String> = .init(value: "")
    var vetPhone: DirtyField<String> = .init(value: "")
    var vetAddress: DirtyField<String> = .init(value: "")
    var insuranceCompany: DirtyField<String> = .init(value: "")
    var insurancePolicy: DirtyField<String> = .init(value: "")
    var emergencyAuth: DirtyField<Bool> = .init(value: false)
    var emergencyVetCapGBP: DirtyField<String> = .init(value: "")
    var backupContactName: DirtyField<String> = .init(value: "")
    var backupContactPhone: DirtyField<String> = .init(value: "")

    static let accessMethodOptions = [
        "I'll be home", "Key under [...]", "Lockbox",
        "Key handover", "Smart lock", "Other"
    ]
    static let allowedRoomOptions = ["Lounge", "Kitchen", "Bedroom", "All rooms", "Garden only"]
    static let soundsToAvoidOptions = [
        "Fireworks", "Hoover", "Doorbell", "Thunder", "TV at high volume"
    ]

    func toPayload() -> [String: Any] {
        let medsArray: [[String: Any]] = medications.value.map { med in
            [
                "name": med.name,
                "times": med.times,
                "dosage": med.dosage,
                "withFood": med.withFood,
                "notes": med.notes
            ]
        }
        var dict: [String: Any] = [
            "vaccinationOK": vaccinationOK.value,
            "neutered": neutered.value,
            "microchipId": microchipId.value,
            "accessMethod": accessMethod.value,
            "accessNotes": accessNotes.value,
            "alarmCode": alarmCode.value,
            "feedingMorning": feedingMorning.value,
            "feedingEvening": feedingEvening.value,
            "feedingMidday": feedingMidday.value,
            "foodLocation": foodLocation.value,
            "amountPerMeal": amountPerMeal.value,
            "treatsAllowed": treatsAllowed.value,
            "treatNotes": treatNotes.value,
            "medications": medsArray,
            "allowedRooms": Array(allowedRooms.value).sorted(),
            "offLimitsAreas": offLimitsAreas.value,
            "sleepLocation": sleepLocation.value,
            "bedtimeRitual": bedtimeRitual.value,
            "soundsToAvoid": Array(soundsToAvoid.value).sorted(),
            "vet": [
                "name": vetName.value,
                "phone": vetPhone.value,
                "address": vetAddress.value
            ],
            "insurance": [
                "company": insuranceCompany.value,
                "policy": insurancePolicy.value
            ],
            "emergencyAuth": emergencyAuth.value,
            "backupContact": [
                "name": backupContactName.value,
                "phone": backupContactPhone.value
            ]
        ]
        if let cap = Double(emergencyVetCapGBP.value), cap > 0 {
            dict["emergencyVetCapGBP"] = cap
        }
        return dict
    }
}

struct SittingMedicationEntry: Equatable, Identifiable {
    var id = UUID()
    var name: String = ""
    var times: String = ""
    var dosage: String = ""
    var withFood: Bool = false
    var notes: String = ""
}

// MARK: - Top-level booking dog details

/// Rich dog-details capture for the booking flow. Owns the shared
/// "Basics" block (breed, size, weight, age echoes, sex, neutered,
/// microchip) and the per-vertical bag.
struct BookingDogDetails: Equatable {
    /// Currently-targeted dog id. Drives profile preload + save-back.
    var dogId: String?
    var dogName: String = ""

    // Basics — preloaded from `dogs/{dogId}` and editable.
    var breed: DirtyField<String> = .init(value: "")
    var size: DirtyField<DogSizeOption?> = .init(value: nil)
    var weightKg: DirtyField<String> = .init(value: "")
    var ageYears: Int? = nil
    var sex: String? = nil
    var neutered: Bool = false

    // Per-vertical bags — populated on demand.
    var walk: WalkBookingDetails = .init()
    var grooming: GroomingBookingDetails = .init()
    var sitting: SittingBookingDetails = .init()

    /// Whether the user wants the diff written back to `dogs/{dogId}`.
    var saveBackToProfile: Bool = false

    /// Soft validation — gates Continue at the addDetails step.
    var isValidForVerticals: Bool {
        let breedOK = !breed.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let sizeOK = size.value != nil
        return breedOK && sizeOK
    }

    /// Server payload. Drops `nil` and unset values so the booking doc
    /// stays tidy. Caller forwards under top-level `dogDetails` key.
    func toServerPayload(serviceType: BookingServiceType) -> [String: Any] {
        var dict: [String: Any] = [
            "breed": breed.value.trimmingCharacters(in: .whitespacesAndNewlines),
            "size": size.value?.rawValue ?? "",
            "savedToProfile": saveBackToProfile
        ]
        if let weight = Double(weightKg.value), weight > 0 {
            dict["weightKg"] = weight
        }
        if let age = ageYears { dict["ageYears"] = age }
        if let sx = sex, !sx.isEmpty { dict["sex"] = sx }
        dict["neutered"] = neutered
        switch serviceType {
        case .walk, .meetGreet:
            // Walk config is forwarded on the booking under `walkConfig`,
            // but we also echo the dog-details snapshot. Caller wires both.
            break
        case .grooming, .boarding, .daycare, .training,
             .inSitting, .outSitting, .petSitting:
            break
        }
        return dict
    }
}

// MARK: - Profile preload + save-back

/// Helpers that translate between the on-disk `UnifiedDog` and our local
/// rich form state. Profile-preload writes only to fields where
/// `isDirty == false` (the stale-edit guard from spec §2).
enum BookingDogDetailsLoader {
    /// Apply a freshly-loaded `UnifiedDog` onto the form state. Honours
    /// the dirty-flag so back-nav doesn't clobber edits.
    static func prefill(
        _ details: inout BookingDogDetails,
        from dog: UnifiedDog,
        serviceType: BookingServiceType
    ) {
        details.dogId = dog.id
        details.dogName = dog.name
        details.ageYears = dog.ageYears > 0 ? dog.ageYears : nil
        details.sex = dog.sex
        details.neutered = dog.neutered

        details.breed.prefill(dog.breed ?? "")
        if let mapped = DogSizeOption.fromString(dog.size) {
            details.size.prefill(mapped)
        } else if details.size.value == nil && !details.size.isDirty {
            // Spec §3: if profile.size is null, MEDIUM is selected by
            // default but UI nudges with "Confirm size" caption.
            details.size.value = .medium
        }
        if let w = dog.weight, w > 0 {
            details.weightKg.prefill(String(format: "%.1f", w))
        }

        switch serviceType {
        case .grooming:
            // Allergies → grooming.allergies (textual prefill).
            let allergyText = [dog.allergies, dog.dietaryRestrictions]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "; ")
            details.grooming.allergies.prefill(allergyText)
            // nervousDog → handlingNotes seed.
            if dog.nervousDog {
                let seed = ["Anxious — handle gently", dog.behavioralNotes]
                    .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: ". ")
                details.grooming.handlingNotes.prefill(seed)
            } else if let notes = dog.behavioralNotes, !notes.isEmpty {
                details.grooming.handlingNotes.prefill(notes)
            }
        case .walk, .meetGreet:
            if let prefs = dog.walkPreferences {
                details.walk.offLeadAllowed.prefill(prefs.offLeashPreferred)
            }
            // goodWithDogs (Bool?) → tri-state chip.
            if let gwd = dog.goodWithDogs {
                let chip = gwd ? "Loves them" : "Don't allow approach"
                details.walk.dogTolerance.prefill(chip)
            }
            // nervousDog + behavioralNotes → fearTriggers seed.
            if let notes = dog.behavioralNotes, !notes.isEmpty {
                // Detect a few common keywords from free-text and seed
                // chips. Conservative — only matches lowercase exact words.
                let lower = notes.lowercased()
                var seed: Set<String> = []
                let map: [(String, String)] = [
                    ("bike", "Bikes"), ("scooter", "Scooters"), ("skateboard", "Skateboards"),
                    ("hi-vis", "Hi-vis"), ("hivis", "Hi-vis"),
                    ("man ", "Men"), ("men ", "Men"),
                    ("child", "Children"), ("kid", "Children"),
                    ("loud", "Loud noises"), ("noise", "Loud noises"),
                    ("bin lorr", "Bin lorries"), ("siren", "Sirens"),
                    ("other dog", "Other dogs"), ("cat", "Cats")
                ]
                for (needle, chip) in map where lower.contains(needle) {
                    seed.insert(chip)
                }
                if !seed.isEmpty {
                    details.walk.fearTriggers.prefill(seed)
                }
            }
        case .petSitting, .inSitting, .outSitting:
            if let chip = dog.microchipId, !chip.isEmpty {
                details.sitting.microchipId.prefill(chip)
            }
            details.sitting.neutered.prefill(dog.neutered)
            if let vac = dog.vaccinationStatus?.lowercased() {
                let ok = vac.contains("up_to_date") || vac.contains("up to date")
                    || vac.contains("current") || vac.contains("valid")
                details.sitting.vaccinationOK.prefill(ok)
            }
            if let vet = dog.vetInfo {
                details.sitting.vetName.prefill(vet.name)
                details.sitting.vetPhone.prefill(vet.phone)
                if let addr = vet.address { details.sitting.vetAddress.prefill(addr) }
            }
            if let meds = dog.medications, !meds.isEmpty,
               details.sitting.medications.value.isEmpty,
               !details.sitting.medications.isDirty {
                let entry = SittingMedicationEntry(name: meds)
                details.sitting.medications.value = [entry]
            }
        case .boarding, .daycare, .training:
            break
        }
    }

    /// Diff the form against the originally-loaded UnifiedDog. Returns the
    /// fields that should be written back when the save-back toggle is ON.
    /// Per-booking-only fields (gate code, this-trip notes, emergency cap,
    /// photos) are skipped (spec §5).
    static func profileDiff(
        details: BookingDogDetails,
        original: UnifiedDog
    ) -> [String: Any] {
        var diff: [String: Any] = [:]
        let breedTrim = details.breed.value.trimmingCharacters(in: .whitespacesAndNewlines)
        if breedTrim != (original.breed ?? "") && !breedTrim.isEmpty {
            diff["breed"] = breedTrim
        }
        let mappedSize = details.size.value?.rawValue ?? ""
        if !mappedSize.isEmpty && mappedSize != (original.size ?? "") {
            diff["size"] = mappedSize
        }
        if let w = Double(details.weightKg.value), w > 0,
           abs(w - (original.weight ?? 0)) > 0.01 {
            diff["weight"] = w
        }
        // Sitting-specific fields that map onto profile.
        let chipTrim = details.sitting.microchipId.value
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !chipTrim.isEmpty && chipTrim != (original.microchipId ?? "") {
            diff["microchipId"] = chipTrim
        }
        let vetName = details.sitting.vetName.value
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let vetPhone = details.sitting.vetPhone.value
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let vetAddr = details.sitting.vetAddress.value
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let origVet = original.vetInfo
        let vetChanged = (!vetName.isEmpty && vetName != (origVet?.name ?? "")) ||
            (!vetPhone.isEmpty && vetPhone != (origVet?.phone ?? "")) ||
            (!vetAddr.isEmpty && vetAddr != (origVet?.address ?? ""))
        if vetChanged {
            var vet: [String: Any] = [
                "name": vetName,
                "clinic": origVet?.clinic ?? "",
                "phone": vetPhone,
                "address": vetAddr,
                "emergencyContact": origVet?.emergencyContact ?? false
            ]
            if let email = origVet?.email { vet["email"] = email }
            diff["vetInfo"] = vet
        }
        // Grooming → allergies (text).
        let allergyTrim = details.grooming.allergies.value
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !allergyTrim.isEmpty && allergyTrim != (original.allergies ?? "") {
            diff["allergies"] = allergyTrim
        }
        return diff
    }

    /// Returns true if at least one profile-mappable field differs from
    /// the originally-loaded dog. Drives the enable/disable state of the
    /// "Update [name]'s profile" toggle (spec §5).
    static func hasProfileDiff(
        details: BookingDogDetails,
        original: UnifiedDog?
    ) -> Bool {
        guard let original = original else { return false }
        return !profileDiff(details: details, original: original).isEmpty
    }

    /// Write the diff to `dogs/{dogId}`. Non-blocking — caller treats
    /// failure as soft (toast, booking still proceeds).
    static func writeProfileDiff(
        dogId: String,
        diff: [String: Any]
    ) async throws {
        guard !dogId.isEmpty, !diff.isEmpty else { return }
        var payload = diff
        payload["updatedAt"] = Int64(Date().timeIntervalSince1970 * 1000)
        let db = Firestore.firestore()
        try await db.collection("dogs").document(dogId).updateData(payload)
    }

    /// One-shot fetch of the full UnifiedDog for the given id. Returns
    /// nil if the doc is missing or can't be decoded.
    static func loadDog(id: String) async -> UnifiedDog? {
        guard !id.isEmpty else { return nil }
        let db = Firestore.firestore()
        do {
            let snap = try await db.collection("dogs").document(id).getDocument()
            guard snap.exists else { return nil }
            let dog = try snap.data(as: UnifiedDog.self)
            return dog
        } catch {
            print("[BookingDogDetailsLoader] loadDog \(id) failed: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Shared UI helpers

struct DogDetailsSectionCard<Content: View>: View {
    let title: String
    let icon: String
    let filledCount: Int?
    let totalCount: Int?
    @Binding var isExpanded: Bool
    let collapsible: Bool
    let content: () -> Content

    init(
        title: String,
        icon: String,
        filledCount: Int? = nil,
        totalCount: Int? = nil,
        isExpanded: Binding<Bool>,
        collapsible: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.filledCount = filledCount
        self.totalCount = totalCount
        self._isExpanded = isExpanded
        self.collapsible = collapsible
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                guard collapsible else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundColor(Color(hex: 0xB388FF))
                        .frame(width: 22)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    if let f = filledCount, let t = totalCount, t > 0 {
                        Text("\(f) of \(t)")
                            .font(.caption2)
                            .foregroundColor(.neutral60)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(Color.neutral20)
                            )
                    }
                    Spacer()
                    if collapsible {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.neutral60)
                    }
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.neutral20)
        )
    }
}

struct DogDetailsFieldLabel: View {
    let text: String
    var optional: Bool = true

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
                .foregroundColor(.neutral60)
            if !optional {
                Text("•")
                    .font(.caption2)
                    .foregroundColor(Color(hex: 0xFF7B7B))
                Text("required")
                    .font(.caption2)
                    .foregroundColor(Color(hex: 0xFF7B7B))
            }
        }
        .padding(.bottom, 2)
    }
}

struct DogDetailsTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.neutral40))
            .keyboardType(keyboard)
            .font(.body)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.neutral10)
            )
    }
}

struct DogDetailsTextArea: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.neutral40), axis: .vertical)
            .lineLimit(2...4)
            .font(.body)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.neutral10)
            )
    }
}

struct DogDetailsChipsSingle: View {
    let options: [String]
    let selected: String
    let onSelected: (String) -> Void

    var body: some View {
        DogDetailsFlowLayout(spacing: 8) {
            ForEach(options, id: \.self) { opt in
                let isSel = opt == selected
                Button {
                    onSelected(opt)
                } label: {
                    Text(opt)
                        .font(.caption)
                        .foregroundColor(isSel ? .white : .neutral60)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(isSel ? Color(hex: 0x7C4DFF) : Color.neutral10)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct DogDetailsChipsMulti: View {
    let options: [String]
    let selected: Set<String>
    let onToggle: (String) -> Void

    var body: some View {
        DogDetailsFlowLayout(spacing: 8) {
            ForEach(options, id: \.self) { opt in
                let isSel = selected.contains(opt)
                Button {
                    onToggle(opt)
                } label: {
                    HStack(spacing: 4) {
                        if isSel {
                            Image(systemName: "checkmark")
                                .font(.caption2)
                        }
                        Text(opt)
                            .font(.caption)
                    }
                    .foregroundColor(isSel ? .white : .neutral60)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(isSel ? Color(hex: 0x7C4DFF) : Color.neutral10)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct DogDetailsFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Top-level details view (dispatcher)

/// Renders the rich Add-Details form for grooming / walking / sitting.
/// Boarding / daycare / training keep the existing simpler flow — caller
/// is expected to skip this view for those verticals.
struct BookingDogDetailsView: View {
    @Binding var details: BookingDogDetails
    let serviceType: BookingServiceType
    let originalDog: UnifiedDog?
    let isSizeNudgeShown: Bool

    @State private var basicsExpanded = true
    @State private var section2Expanded = false
    @State private var section3Expanded = false
    @State private var section4Expanded = false
    @State private var section5Expanded = false
    @State private var section6Expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            basicsCard

            switch serviceType {
            case .walk, .meetGreet:
                walkSections
            case .grooming:
                groomingSections
            case .petSitting, .inSitting, .outSitting:
                sittingSections
            case .boarding, .daycare, .training:
                EmptyView()
            }

            saveBackToggle
        }
    }

    // MARK: Basics

    private var basicsCard: some View {
        DogDetailsSectionCard(
            title: "Basics",
            icon: "pawprint.fill",
            isExpanded: $basicsExpanded,
            collapsible: false
        ) {
            VStack(alignment: .leading, spacing: 12) {
                DogDetailsFieldLabel(text: "Breed", optional: false)
                DogDetailsTextField(
                    placeholder: "e.g. Cockapoo, Lurcher, Lab cross",
                    text: Binding(
                        get: { details.breed.value },
                        set: { setField(\BookingDogDetails.breed, $0) }
                    )
                )

                if isSizeNudgeShown {
                    Text("Confirm size — we've guessed Medium")
                        .font(.caption2)
                        .foregroundColor(Color(hex: 0xFFB74D))
                }
                DogDetailsFieldLabel(text: "Size", optional: false)
                sizeChipsRow

                if let age = details.ageYears, age > 0 {
                    HStack(spacing: 12) {
                        ageEcho(age: age)
                        weightEditor
                    }
                } else {
                    weightEditor
                }
            }
        }
    }

    private var sizeChipsRow: some View {
        HStack(spacing: 8) {
            ForEach(DogSizeOption.allCases) { opt in
                let isSel = details.size.value == opt
                Button {
                    setField(\BookingDogDetails.size, opt)
                } label: {
                    VStack(spacing: 2) {
                        Text(opt.displayLabel)
                            .font(.caption.weight(isSel ? .bold : .regular))
                        Text(opt.rawValue)
                            .font(.caption2)
                            .foregroundColor(isSel ? .white.opacity(0.85) : .neutral50)
                    }
                    .foregroundColor(isSel ? .white : .neutral60)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isSel ? Color(hex: 0x7C4DFF) : Color.neutral10)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func ageEcho(age: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Age")
                .font(.caption2)
                .foregroundColor(.neutral60)
            Text("\(age) yr\(age == 1 ? "" : "s")")
                .font(.caption.bold())
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.neutral10))
    }

    private var weightEditor: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Weight (kg)")
                .font(.caption2)
                .foregroundColor(.neutral60)
            DogDetailsTextField(
                placeholder: "e.g. 12.4",
                text: Binding(
                    get: { details.weightKg.value },
                    set: { setField(\BookingDogDetails.weightKg, $0) }
                ),
                keyboard: .decimalPad
            )
        }
    }

    // MARK: Walking sections

    @ViewBuilder
    private var walkSections: some View {
        DogDetailsSectionCard(
            title: "Lead & recall",
            icon: "figure.walk",
            isExpanded: $section2Expanded
        ) {
            VStack(alignment: .leading, spacing: 12) {
                DogDetailsFieldLabel(text: "Lead manners")
                DogDetailsChipsSingle(
                    options: WalkBookingDetails.leadMannersOptions,
                    selected: details.walk.leadManners.value,
                    onSelected: { setField(\BookingDogDetails.walk.leadManners, $0) }
                )

                Toggle(isOn: Binding(
                    get: { details.walk.offLeadAllowed.value },
                    set: { setField(\BookingDogDetails.walk.offLeadAllowed, $0) }
                )) {
                    Text("Off-lead permitted")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .tint(Color(hex: 0x7C4DFF))

                if details.walk.offLeadAllowed.value {
                    Text("By enabling off-lead, you confirm \(details.dogName.isEmpty ? "your dog" : details.dogName) has reliable recall and accept full liability for any incidents during off-lead time.")
                        .font(.caption)
                        .foregroundColor(.neutral60)

                    Toggle(isOn: Binding(
                        get: { details.walk.offLeadWaiverAccepted.value },
                        set: { newValue in
                            var copy = details
                            copy.walk.offLeadWaiverAccepted.set(newValue)
                            copy.walk.offLeadWaiverAt = newValue
                                ? Int64(Date().timeIntervalSince1970 * 1000)
                                : nil
                            details = copy
                        }
                    )) {
                        Text("I accept the off-lead waiver")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white)
                    }
                    .tint(Color(hex: 0x7C4DFF))

                    DogDetailsFieldLabel(text: "Recall reliability")
                    DogDetailsChipsSingle(
                        options: WalkBookingDetails.recallOptions,
                        selected: details.walk.recallReliability.value,
                        onSelected: { setField(\BookingDogDetails.walk.recallReliability, $0) }
                    )
                }
            }
        }

        DogDetailsSectionCard(
            title: "Other dogs & people",
            icon: "person.2.fill",
            isExpanded: $section3Expanded
        ) {
            VStack(alignment: .leading, spacing: 12) {
                DogDetailsFieldLabel(text: "Tolerance of other dogs")
                DogDetailsChipsSingle(
                    options: WalkBookingDetails.dogToleranceOptions,
                    selected: details.walk.dogTolerance.value,
                    onSelected: { setField(\BookingDogDetails.walk.dogTolerance, $0) }
                )
                DogDetailsFieldLabel(text: "Tolerance of strangers")
                DogDetailsChipsSingle(
                    options: WalkBookingDetails.strangerToleranceOptions,
                    selected: details.walk.strangerTolerance.value,
                    onSelected: { setField(\BookingDogDetails.walk.strangerTolerance, $0) }
                )
                DogDetailsFieldLabel(text: "Fear triggers")
                DogDetailsChipsMulti(
                    options: WalkBookingDetails.fearTriggerOptions,
                    selected: details.walk.fearTriggers.value,
                    onToggle: { triggerToggle(\BookingDogDetails.walk.fearTriggers, $0) }
                )
            }
        }

        DogDetailsSectionCard(
            title: "Logistics",
            icon: "key.fill",
            isExpanded: $section4Expanded
        ) {
            VStack(alignment: .leading, spacing: 12) {
                DogDetailsFieldLabel(text: "Pickup location")
                DogDetailsTextField(
                    placeholder: "Address or what3words",
                    text: Binding(
                        get: { details.walk.pickupAddress.value },
                        set: { setField(\BookingDogDetails.walk.pickupAddress, $0) }
                    )
                )
                DogDetailsFieldLabel(text: "Gate code")
                DogDetailsTextField(
                    placeholder: "Optional",
                    text: Binding(
                        get: { details.walk.gateCode.value },
                        set: { setField(\BookingDogDetails.walk.gateCode, $0) }
                    )
                )
                DogDetailsFieldLabel(text: "Keys / lockbox")
                DogDetailsTextField(
                    placeholder: "Optional — where to find them",
                    text: Binding(
                        get: { details.walk.keysOrLockbox.value },
                        set: { setField(\BookingDogDetails.walk.keysOrLockbox, $0) }
                    )
                )
                DogDetailsFieldLabel(text: "What's in the dog bag")
                DogDetailsChipsMulti(
                    options: WalkBookingDetails.dogBagOptions,
                    selected: details.walk.dogBag.value,
                    onToggle: { triggerToggle(\BookingDogDetails.walk.dogBag, $0) }
                )
            }
        }

        DogDetailsSectionCard(
            title: "Communication",
            icon: "bubble.left.and.bubble.right.fill",
            isExpanded: $section5Expanded
        ) {
            VStack(alignment: .leading, spacing: 12) {
                DogDetailsFieldLabel(text: "Call me if")
                DogDetailsChipsMulti(
                    options: WalkBookingDetails.callMeIfOptions,
                    selected: details.walk.callMeIf.value,
                    onToggle: { triggerToggle(\BookingDogDetails.walk.callMeIf, $0) }
                )
                DogDetailsFieldLabel(text: "Photos during walk")
                DogDetailsChipsSingle(
                    options: WalkBookingDetails.photoPolicyOptions,
                    selected: details.walk.photoPolicy.value,
                    onSelected: { setField(\BookingDogDetails.walk.photoPolicy, $0) }
                )
            }
        }
    }

    // MARK: Grooming sections

    @ViewBuilder
    private var groomingSections: some View {
        DogDetailsSectionCard(
            title: "Coat & body",
            icon: "scissors",
            isExpanded: $section2Expanded
        ) {
            VStack(alignment: .leading, spacing: 12) {
                DogDetailsFieldLabel(text: "Coat type")
                DogDetailsChipsMulti(
                    options: GroomingBookingDetails.coatTypeOptions,
                    selected: details.grooming.coatType.value,
                    onToggle: { triggerToggle(\BookingDogDetails.grooming.coatType, $0) }
                )
                DogDetailsFieldLabel(text: "Coat condition")
                DogDetailsChipsSingle(
                    options: GroomingBookingDetails.coatConditionOptions,
                    selected: details.grooming.coatCondition.value,
                    onSelected: { setField(\BookingDogDetails.grooming.coatCondition, $0) }
                )
                DogDetailsFieldLabel(text: "Last full groom")
                DatePicker("",
                    selection: Binding(
                        get: { details.grooming.lastGroomDate.value ?? Date() },
                        set: { setField(\BookingDogDetails.grooming.lastGroomDate, $0) }
                    ),
                    in: ...Date(),
                    displayedComponents: .date
                )
                .labelsHidden()
                .colorScheme(.dark)

                DogDetailsFieldLabel(text: "Skin sensitivities / allergies")
                DogDetailsTextArea(
                    placeholder: "Anything the groomer should avoid",
                    text: Binding(
                        get: { details.grooming.allergies.value },
                        set: { setField(\BookingDogDetails.grooming.allergies, $0) }
                    )
                )
            }
        }

        DogDetailsSectionCard(
            title: "Style preferences",
            icon: "paintbrush.fill",
            isExpanded: $section3Expanded
        ) {
            VStack(alignment: .leading, spacing: 12) {
                DogDetailsFieldLabel(text: "Preferred groom style")
                DogDetailsChipsSingle(
                    options: GroomingBookingDetails.groomStyleOptions,
                    selected: details.grooming.groomStyle.value,
                    onSelected: { setField(\BookingDogDetails.grooming.groomStyle, $0) }
                )
                DogDetailsFieldLabel(text: "Length preference")
                DogDetailsChipsSingle(
                    options: GroomingBookingDetails.lengthOptions,
                    selected: details.grooming.lengthPreference.value,
                    onSelected: { setField(\BookingDogDetails.grooming.lengthPreference, $0) }
                )
                DogDetailsFieldLabel(text: "Additional services")
                DogDetailsChipsMulti(
                    options: GroomingBookingDetails.additionalServiceOptions,
                    selected: details.grooming.additionalServices.value,
                    onToggle: { triggerToggle(\BookingDogDetails.grooming.additionalServices, $0) }
                )
            }
        }

        DogDetailsSectionCard(
            title: "Behaviour & handling",
            icon: "heart.text.square.fill",
            isExpanded: $section4Expanded
        ) {
            VStack(alignment: .leading, spacing: 12) {
                DogDetailsFieldLabel(text: "Behaviour at the groomer")
                DogDetailsChipsSingle(
                    options: GroomingBookingDetails.behaviourOptions,
                    selected: details.grooming.behaviour.value,
                    onSelected: { setField(\BookingDogDetails.grooming.behaviour, $0) }
                )
                DogDetailsFieldLabel(text: "Sensitive areas")
                DogDetailsChipsMulti(
                    options: GroomingBookingDetails.sensitiveAreaOptions,
                    selected: details.grooming.sensitiveAreas.value,
                    onToggle: { triggerToggle(\BookingDogDetails.grooming.sensitiveAreas, $0) }
                )
                DogDetailsFieldLabel(text: "Special handling notes")
                DogDetailsTextArea(
                    placeholder: "Anxiety triggers, prior reactions, anything to know",
                    text: Binding(
                        get: { details.grooming.handlingNotes.value },
                        set: { setField(\BookingDogDetails.grooming.handlingNotes, $0) }
                    )
                )
            }
        }
    }

    // MARK: Sitting sections

    @ViewBuilder
    private var sittingSections: some View {
        DogDetailsSectionCard(
            title: "Identity & vaccination",
            icon: "checkmark.shield.fill",
            isExpanded: $section2Expanded
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: Binding(
                    get: { details.sitting.vaccinationOK.value },
                    set: { setField(\BookingDogDetails.sitting.vaccinationOK, $0) }
                )) {
                    Text("Vaccination card up-to-date")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .tint(Color(hex: 0x7C4DFF))

                Toggle(isOn: Binding(
                    get: { details.sitting.neutered.value },
                    set: { setField(\BookingDogDetails.sitting.neutered, $0) }
                )) {
                    Text("Neutered / spayed")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .tint(Color(hex: 0x7C4DFF))

                DogDetailsFieldLabel(text: "Microchip number")
                DogDetailsTextField(
                    placeholder: "Optional — 15 digits",
                    text: Binding(
                        get: { details.sitting.microchipId.value },
                        set: { setField(\BookingDogDetails.sitting.microchipId, $0) }
                    ),
                    keyboard: .numberPad
                )
            }
        }

        DogDetailsSectionCard(
            title: "Access",
            icon: "key.fill",
            isExpanded: $section3Expanded
        ) {
            VStack(alignment: .leading, spacing: 12) {
                DogDetailsFieldLabel(text: "Access method")
                DogDetailsChipsSingle(
                    options: SittingBookingDetails.accessMethodOptions,
                    selected: details.sitting.accessMethod.value,
                    onSelected: { setField(\BookingDogDetails.sitting.accessMethod, $0) }
                )
                if details.sitting.accessMethod.value.lowercased().contains("lockbox") ||
                   details.sitting.accessMethod.value.lowercased().contains("other") {
                    DogDetailsFieldLabel(text: "Access notes")
                    DogDetailsTextArea(
                        placeholder: "Where, code, anything else",
                        text: Binding(
                            get: { details.sitting.accessNotes.value },
                            set: { setField(\BookingDogDetails.sitting.accessNotes, $0) }
                        )
                    )
                }
                DogDetailsFieldLabel(text: "Alarm code")
                DogDetailsTextField(
                    placeholder: "Optional",
                    text: Binding(
                        get: { details.sitting.alarmCode.value },
                        set: { setField(\BookingDogDetails.sitting.alarmCode, $0) }
                    )
                )
            }
        }

        DogDetailsSectionCard(
            title: "Feeding",
            icon: "fork.knife",
            isExpanded: $section4Expanded
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        DogDetailsFieldLabel(text: "Morning")
                        DogDetailsTextField(
                            placeholder: "e.g. 8am",
                            text: Binding(
                                get: { details.sitting.feedingMorning.value },
                                set: { setField(\BookingDogDetails.sitting.feedingMorning, $0) }
                            )
                        )
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        DogDetailsFieldLabel(text: "Evening")
                        DogDetailsTextField(
                            placeholder: "e.g. 6pm",
                            text: Binding(
                                get: { details.sitting.feedingEvening.value },
                                set: { setField(\BookingDogDetails.sitting.feedingEvening, $0) }
                            )
                        )
                    }
                }
                DogDetailsFieldLabel(text: "Mid-day feed (optional)")
                DogDetailsTextField(
                    placeholder: "e.g. 1pm",
                    text: Binding(
                        get: { details.sitting.feedingMidday.value },
                        set: { setField(\BookingDogDetails.sitting.feedingMidday, $0) }
                    )
                )
                DogDetailsFieldLabel(text: "Food location")
                DogDetailsTextField(
                    placeholder: "e.g. Kitchen cupboard, top shelf",
                    text: Binding(
                        get: { details.sitting.foodLocation.value },
                        set: { setField(\BookingDogDetails.sitting.foodLocation, $0) }
                    )
                )
                DogDetailsFieldLabel(text: "Amount per meal")
                DogDetailsTextField(
                    placeholder: "e.g. 1 cup dry, 1/4 tin wet",
                    text: Binding(
                        get: { details.sitting.amountPerMeal.value },
                        set: { setField(\BookingDogDetails.sitting.amountPerMeal, $0) }
                    )
                )
                Toggle(isOn: Binding(
                    get: { details.sitting.treatsAllowed.value },
                    set: { setField(\BookingDogDetails.sitting.treatsAllowed, $0) }
                )) {
                    Text("Treats allowed")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .tint(Color(hex: 0x7C4DFF))
                if details.sitting.treatsAllowed.value {
                    DogDetailsTextField(
                        placeholder: "What kind?",
                        text: Binding(
                            get: { details.sitting.treatNotes.value },
                            set: { setField(\BookingDogDetails.sitting.treatNotes, $0) }
                        )
                    )
                }
            }
        }

        DogDetailsSectionCard(
            title: "Medication",
            icon: "pills.fill",
            isExpanded: $section5Expanded
        ) {
            VStack(alignment: .leading, spacing: 12) {
                let meds = details.sitting.medications.value
                ForEach(Array(meds.enumerated()), id: \.element.id) { (index, _) in
                    medicationRow(index: index)
                }
                Button {
                    var copy = details
                    var current = copy.sitting.medications.value
                    current.append(SittingMedicationEntry())
                    copy.sitting.medications.set(current)
                    details = copy
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text(meds.isEmpty ? "Add a medication" : "Add another medication")
                            .font(.caption.bold())
                    }
                    .foregroundColor(Color(hex: 0xB388FF))
                }
                .buttonStyle(.plain)
            }
        }

        DogDetailsSectionCard(
            title: "House rules & emergency",
            icon: "house.fill",
            isExpanded: $section6Expanded
        ) {
            VStack(alignment: .leading, spacing: 12) {
                DogDetailsFieldLabel(text: "Allowed rooms")
                DogDetailsChipsMulti(
                    options: SittingBookingDetails.allowedRoomOptions,
                    selected: details.sitting.allowedRooms.value,
                    onToggle: { triggerToggle(\BookingDogDetails.sitting.allowedRooms, $0) }
                )
                DogDetailsFieldLabel(text: "Off-limits areas")
                DogDetailsTextField(
                    placeholder: "e.g. Upstairs, sofas",
                    text: Binding(
                        get: { details.sitting.offLimitsAreas.value },
                        set: { setField(\BookingDogDetails.sitting.offLimitsAreas, $0) }
                    )
                )
                DogDetailsFieldLabel(text: "Sleep location")
                DogDetailsTextField(
                    placeholder: "e.g. Crate in lounge, kitchen floor",
                    text: Binding(
                        get: { details.sitting.sleepLocation.value },
                        set: { setField(\BookingDogDetails.sitting.sleepLocation, $0) }
                    )
                )
                DogDetailsFieldLabel(text: "Bedtime ritual")
                DogDetailsTextArea(
                    placeholder: "e.g. Last wee at 10pm, treat, lights off",
                    text: Binding(
                        get: { details.sitting.bedtimeRitual.value },
                        set: { setField(\BookingDogDetails.sitting.bedtimeRitual, $0) }
                    )
                )
                DogDetailsFieldLabel(text: "Sounds / triggers to avoid")
                DogDetailsChipsMulti(
                    options: SittingBookingDetails.soundsToAvoidOptions,
                    selected: details.sitting.soundsToAvoid.value,
                    onToggle: { triggerToggle(\BookingDogDetails.sitting.soundsToAvoid, $0) }
                )

                Divider().background(Color.neutral40)

                DogDetailsFieldLabel(text: "Vet name")
                DogDetailsTextField(
                    placeholder: "Vet name",
                    text: Binding(
                        get: { details.sitting.vetName.value },
                        set: { setField(\BookingDogDetails.sitting.vetName, $0) }
                    )
                )
                DogDetailsFieldLabel(text: "Vet phone")
                DogDetailsTextField(
                    placeholder: "Phone",
                    text: Binding(
                        get: { details.sitting.vetPhone.value },
                        set: { setField(\BookingDogDetails.sitting.vetPhone, $0) }
                    ),
                    keyboard: .phonePad
                )
                DogDetailsFieldLabel(text: "Vet address")
                DogDetailsTextField(
                    placeholder: "Optional",
                    text: Binding(
                        get: { details.sitting.vetAddress.value },
                        set: { setField(\BookingDogDetails.sitting.vetAddress, $0) }
                    )
                )
                DogDetailsFieldLabel(text: "Insurance company")
                DogDetailsTextField(
                    placeholder: "Optional",
                    text: Binding(
                        get: { details.sitting.insuranceCompany.value },
                        set: { setField(\BookingDogDetails.sitting.insuranceCompany, $0) }
                    )
                )
                DogDetailsFieldLabel(text: "Insurance policy number")
                DogDetailsTextField(
                    placeholder: "Optional",
                    text: Binding(
                        get: { details.sitting.insurancePolicy.value },
                        set: { setField(\BookingDogDetails.sitting.insurancePolicy, $0) }
                    )
                )
                Toggle(isOn: Binding(
                    get: { details.sitting.emergencyAuth.value },
                    set: { setField(\BookingDogDetails.sitting.emergencyAuth, $0) }
                )) {
                    Text("Authorise emergency vet treatment")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .tint(Color(hex: 0x7C4DFF))
                if details.sitting.emergencyAuth.value {
                    DogDetailsFieldLabel(text: "Spend cap (£)")
                    DogDetailsTextField(
                        placeholder: "e.g. 500",
                        text: Binding(
                            get: { details.sitting.emergencyVetCapGBP.value },
                            set: { setField(\BookingDogDetails.sitting.emergencyVetCapGBP, $0) }
                        ),
                        keyboard: .decimalPad
                    )
                }
                DogDetailsFieldLabel(text: "Backup contact name")
                DogDetailsTextField(
                    placeholder: "Optional",
                    text: Binding(
                        get: { details.sitting.backupContactName.value },
                        set: { setField(\BookingDogDetails.sitting.backupContactName, $0) }
                    )
                )
                DogDetailsFieldLabel(text: "Backup contact phone")
                DogDetailsTextField(
                    placeholder: "Optional",
                    text: Binding(
                        get: { details.sitting.backupContactPhone.value },
                        set: { setField(\BookingDogDetails.sitting.backupContactPhone, $0) }
                    ),
                    keyboard: .phonePad
                )
            }
        }
    }

    private func medicationRow(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Medication \(index + 1)")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.neutral60)
                Spacer()
                Button {
                    var copy = details
                    var current = copy.sitting.medications.value
                    if current.indices.contains(index) {
                        current.remove(at: index)
                        copy.sitting.medications.set(current)
                        details = copy
                    }
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.caption)
                        .foregroundColor(.neutral60)
                }
                .buttonStyle(.plain)
            }
            DogDetailsTextField(
                placeholder: "Name",
                text: medBinding(index: index, keyPath: \SittingMedicationEntry.name)
            )
            HStack(spacing: 8) {
                DogDetailsTextField(
                    placeholder: "Time(s)",
                    text: medBinding(index: index, keyPath: \SittingMedicationEntry.times)
                )
                DogDetailsTextField(
                    placeholder: "Dosage",
                    text: medBinding(index: index, keyPath: \SittingMedicationEntry.dosage)
                )
            }
            Toggle(isOn: medBoolBinding(index: index, keyPath: \SittingMedicationEntry.withFood)) {
                Text("Give with food")
                    .font(.caption)
                    .foregroundColor(.neutral60)
            }
            .tint(Color(hex: 0x7C4DFF))
            DogDetailsTextArea(
                placeholder: "Instructions",
                text: medBinding(index: index, keyPath: \SittingMedicationEntry.notes)
            )
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.neutral10))
    }

    private func medBinding(index: Int, keyPath: WritableKeyPath<SittingMedicationEntry, String>) -> Binding<String> {
        Binding(
            get: {
                let arr = details.sitting.medications.value
                guard arr.indices.contains(index) else { return "" }
                return arr[index][keyPath: keyPath]
            },
            set: { newValue in
                var copy = details
                var arr = copy.sitting.medications.value
                guard arr.indices.contains(index) else { return }
                arr[index][keyPath: keyPath] = newValue
                copy.sitting.medications.set(arr)
                details = copy
            }
        )
    }

    private func medBoolBinding(index: Int, keyPath: WritableKeyPath<SittingMedicationEntry, Bool>) -> Binding<Bool> {
        Binding(
            get: {
                let arr = details.sitting.medications.value
                guard arr.indices.contains(index) else { return false }
                return arr[index][keyPath: keyPath]
            },
            set: { newValue in
                var copy = details
                var arr = copy.sitting.medications.value
                guard arr.indices.contains(index) else { return }
                arr[index][keyPath: keyPath] = newValue
                copy.sitting.medications.set(arr)
                details = copy
            }
        )
    }

    // MARK: Save-back toggle

    private var saveBackToggle: some View {
        let canSave = BookingDogDetailsLoader.hasProfileDiff(
            details: details,
            original: originalDog
        )
        return VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: Binding(
                get: { details.saveBackToProfile && canSave },
                set: { newValue in
                    var copy = details
                    copy.saveBackToProfile = newValue && canSave
                    details = copy
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(canSave
                         ? "Update \(details.dogName.isEmpty ? "this dog" : details.dogName)'s profile with these changes"
                         : "No profile changes to save")
                        .font(.subheadline.weight(canSave ? .semibold : .regular))
                        .foregroundColor(canSave ? .white : .neutral50)
                    Text("Saves breed, size, vet, allergies, microchip back to your dog profile so you don't have to type it again next time.")
                        .font(.caption2)
                        .foregroundColor(.neutral50)
                }
            }
            .tint(Color(hex: 0x7C4DFF))
            .disabled(!canSave)
            .opacity(canSave ? 1.0 : 0.6)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.neutral20))
    }

    // MARK: Helpers

    /// Toggle a chip in a Set-valued DirtyField at a given keyPath.
    /// Reads/writes via the @Binding's wrappedValue (Binding has no
    /// keyPath subscript, so we round-trip through a local copy).
    private func triggerToggle(
        _ keyPath: WritableKeyPath<BookingDogDetails, DirtyField<Set<String>>>,
        _ option: String
    ) {
        var copy = details
        var field = copy[keyPath: keyPath]
        var set = field.value
        if set.contains(option) {
            set.remove(option)
        } else {
            set.insert(option)
        }
        field.set(set)
        copy[keyPath: keyPath] = field
        details = copy
    }

    /// Write a value into a DirtyField at a given keyPath, marking it
    /// dirty so the profile preload won't clobber it on re-render. The
    /// @Binding `details` doesn't expose a keyPath subscript so we
    /// round-trip through a local copy on each set.
    private func setField<T: Equatable>(
        _ keyPath: WritableKeyPath<BookingDogDetails, DirtyField<T>>,
        _ value: T
    ) {
        var copy = details
        var field = copy[keyPath: keyPath]
        field.set(value)
        copy[keyPath: keyPath] = field
        details = copy
    }

    /// Convenience binding for a DirtyField<T> at a given keyPath. The
    /// setter goes through `setField` so dirty-flag semantics are
    /// preserved on every keystroke.
    private func fieldBinding<T: Equatable>(
        _ keyPath: WritableKeyPath<BookingDogDetails, DirtyField<T>>
    ) -> Binding<T> {
        Binding(
            get: { details[keyPath: keyPath].value },
            set: { setField(keyPath, $0) }
        )
    }
}
