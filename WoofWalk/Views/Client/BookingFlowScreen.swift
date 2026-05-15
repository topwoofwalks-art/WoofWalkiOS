import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import StripePaymentSheet

// MARK: - Booking Step

enum BookingStep: Int, CaseIterable, Identifiable {
    case selectService = 0
    case selectDogs
    case selectProvider
    case pickDateTime
    case addDetails
    case reviewConfirm

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .selectService: return "Service"
        case .selectDogs: return "Dogs"
        case .selectProvider: return "Provider"
        case .pickDateTime: return "Date & Time"
        case .addDetails: return "Details"
        case .reviewConfirm: return "Review"
        }
    }

    var icon: String {
        switch self {
        case .selectService: return "square.grid.2x2"
        case .selectDogs: return "dog.fill"
        case .selectProvider: return "person.fill"
        case .pickDateTime: return "calendar"
        case .addDetails: return "doc.text"
        case .reviewConfirm: return "checkmark.seal"
        }
    }

    var next: BookingStep? {
        BookingStep(rawValue: rawValue + 1)
    }

    var previous: BookingStep? {
        BookingStep(rawValue: rawValue - 1)
    }
}

// MARK: - Price Breakdown

struct BookingPriceBreakdown {
    var basePrice: Double = 0
    var additionalDogFee: Double = 0
    var durationAdjustment: Double = 0
    var platformFee: Double = 0
    var total: Double = 0

    var subtotal: Double {
        basePrice + additionalDogFee + durationAdjustment
    }
}

// MARK: - Booking Instructions

struct BookingInstructionsData {
    var specialInstructions: String = ""
    var accessInstructions: String = ""
    var feedingNotes: String = ""
    var emergencyContact: String = ""
}

// MARK: - Simple Dog for Selection

struct SelectableDog: Identifiable {
    let id: String
    let name: String
    let breed: String?
    let photoUrl: String?
}

// MARK: - Simple Provider for Selection

struct SelectableProvider: Identifiable {
    let id: String
    let name: String
    let photoUrl: String?
    let rating: Double
    let reviewCount: Int
    let distance: Double? // km
    let basePrice: Double
    let bio: String?
    let isVerified: Bool

    var formattedDistance: String {
        guard let d = distance else { return "-- km" }
        if d < 1 {
            return String(format: "%.0f m", d * 1000)
        }
        return String(format: "%.1f km", d)
    }

    var formattedPrice: String {
        CurrencyFormatter.shared.formatPrice(basePrice)
    }
}

// MARK: - Time Slot

struct TimeSlot: Identifiable, Hashable {
    let id: String
    let hour: Int
    let minute: Int

    var displayTime: String {
        let h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        let amPm = hour >= 12 ? "PM" : "AM"
        return String(format: "%d:%02d %@", h, minute, amPm)
    }
}

// MARK: - View Model

class BookingFlowViewModel: ObservableObject {
    @Published var currentStep: BookingStep = .selectService
    @Published var selectedService: BookingServiceType?
    @Published var selectedDogIds: Set<String> = []
    @Published var dogs: [SelectableDog] = []
    @Published var selectedProvider: SelectableProvider?
    @Published var providers: [SelectableProvider] = []
    @Published var selectedDate: Date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @Published var selectedTimeSlot: TimeSlot?

    // Multi-night boarding state — replaces selectedDate + selectedTimeSlot
    // for the boarding service vertical. Match Android's contract:
    //   - check-in defaults to 14:00 on checkInDate
    //   - check-out defaults to 11:00 on checkOutDate
    //   - both are required, checkOut must be strictly after checkIn,
    //     checkIn must be at least 24 hours from now
    // Server payload sends both as epoch millis under `boardingConfig`.
    @Published var boardingCheckInDate: Date?
    @Published var boardingCheckOutDate: Date?
    @Published var instructions = BookingInstructionsData()
    @Published var priceBreakdown = BookingPriceBreakdown()
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var bookingCreatedId: String?
    @Published var isSearchingProviders = false

    // R9: Catalogue → Client Wiring. Sub-config selection (walk duration,
    // grooming menu item + dog size, boarding room + nights, etc.).
    // `subSelectionPayload` matches the server's createClientBooking
    // contract; nil means the user hasn't picked or there's no sub-config
    // for this listing → fall back to provider.basePrice.
    @Published var subSelectionPayload: [String: Any]?
    @Published var subSelectionLabel: String?
    @Published var subSelectionPrice: Double?

    /// Payment method for the booking. "card" routes through Stripe;
    /// "cash" books with the provider taking cash and the platform
    /// commission debited from their wallet on confirm.
    @Published var paymentMethod: String = "card"

    /// Methods the selected provider accepts. Loaded from
    /// `organizations/{orgId}.paymentSettings.acceptedMethods` after a
    /// provider is picked, with a fallback to the legacy
    /// `organization_settings/{orgId}.payments.{acceptCard,acceptCash}`
    /// shape and a final default of `["card"]` when neither is present.
    /// Drives the picker on the review/confirm step: 2 entries → segmented
    /// picker; 1 entry → read-only line; never empty (we coerce to ["card"]).
    @Published var acceptedPaymentMethods: [String] = ["card"]

    // Cash-shortage notify CTA state. Surfaces when the booking submit
    // fails with `failed-precondition` and the message matches the wallet-
    // empty signal in functions/src/index.ts:2266 / :2545.
    @Published var showCashShortageSheet: Bool = false
    @Published var cashShortageRequestId: String?
    @Published var cashShortageAlreadyOpen: Bool = false

    // R10: rich dog-details capture for grooming / walking / sitting.
    // Spec: design_audit_2026_04_26_portal_services/06_booking_dog_details.md
    //
    // The form is preloaded once at addDetails-step entry from
    // `dogs/{dogId}` and follows a (value, isDirty) per-field guard so a
    // back-nav doesn't clobber the user's in-progress edits.
    /// Live, editable form state.
    @Published var dogDetails: BookingDogDetails = .init()
    /// Originally-loaded dog snapshot. Used as the diff baseline for the
    /// "Update [name]'s profile" save-back toggle and to detect whether
    /// anything's actually changed.
    @Published var dogProfileSnapshot: UnifiedDog?
    /// True when a profile fetch is in flight at step entry.
    @Published var dogDetailsLoading: Bool = false
    /// Drives the "Confirm size" caption when the loaded profile didn't
    /// have a size and we've defaulted to MEDIUM.
    @Published var dogDetailsSizeNudgeShown: Bool = false
    /// Soft-validation banner under the Continue button when breed/size
    /// are empty. Cleared as soon as the user fills them.
    @Published var dogDetailsValidationError: String?
    /// Inline-toast text for save-back failure (booking still succeeds).
    @Published var dogDetailsSaveBackToast: String?

    // MARK: - Recurring Bookings
    //
    // When the user opts into a series on the addDetails step, this
    // pattern is sent to `createClientBooking` under the `recurrence`
    // key. The CF creates a `booking_series` doc + materialises the
    // first 4 weeks of occurrences; the scheduled
    // `materialiseBookingSeries` CF extends the window daily.
    //
    // nil = one-off booking (no `recurrence` key on the payload).
    // Mirrors Android's `recurrenceEnabled` + `recurrenceFrequency`
    // pair on `UnifiedBookingFlowState`.
    @Published var recurrencePattern: RecurrencePattern?

    // Stripe PaymentSheet state. Mirrors Android's flow:
    //   - submit creates the booking (CF: createClientBooking)
    //   - if card + total > 0: request clientSecret (CF: processBookingPayment)
    //   - present PaymentSheet
    //   - on .completed: confirmPayment (CF: confirmPayment) → success alert
    //   - on .canceled / .failed: clear state, stay on review step
    /// Stripe PaymentIntent clientSecret returned from `processBookingPayment`.
    @Published var paymentClientSecret: String?
    /// Booking ID waiting for payment confirmation. We hold off setting
    /// `bookingCreatedId` (which drives the success alert) until the
    /// PaymentSheet completes successfully.
    @Published var pendingPaymentBookingId: String?
    /// Drives the PaymentSheet `.paymentSheet(isPresented:…)` modifier.
    /// Flipped true once we have a clientSecret in hand.
    @Published var presentPaymentSheet: Bool = false
    /// True while `processBookingPayment` is in flight, OR while the
    /// PaymentSheet is open. Used to gate the submit button copy / spinner
    /// without conflating with the booking-creation `isLoading` state.
    @Published var paymentInFlight: Bool = false

    private let db = Firestore.firestore()
    private var currentUserId: String? { Auth.auth().currentUser?.uid }

    // Available time slots (8 AM - 8 PM, half hour increments)
    let timeSlots: [TimeSlot] = {
        var slots: [TimeSlot] = []
        for hour in 8...19 {
            slots.append(TimeSlot(id: "\(hour):00", hour: hour, minute: 0))
            slots.append(TimeSlot(id: "\(hour):30", hour: hour, minute: 30))
        }
        slots.append(TimeSlot(id: "20:00", hour: 20, minute: 0))
        return slots
    }()

    // MARK: - Validation

    var canProceed: Bool {
        switch currentStep {
        case .selectService:
            return selectedService != nil
        case .selectDogs:
            return !selectedDogIds.isEmpty
        case .selectProvider:
            return selectedProvider != nil
        case .pickDateTime:
            if selectedService == .boarding {
                return isBoardingDateRangeValid
            }
            return selectedTimeSlot != nil && isDateTimeValid
        case .addDetails:
            // R10: grooming / walking / sitting verticals require breed +
            // size on the rich dog-details form. Boarding / daycare /
            // training keep the legacy free-text-only flow.
            switch selectedService {
            case .grooming, .walk, .meetGreet,
                 .petSitting, .inSitting, .outSitting:
                return dogDetails.isValidForVerticals
            default:
                return true
            }
        case .reviewConfirm:
            let hasDate = selectedService == .boarding
                ? (boardingCheckInDate != nil && boardingCheckOutDate != nil)
                : (selectedTimeSlot != nil)
            return selectedService != nil &&
                   !selectedDogIds.isEmpty &&
                   selectedProvider != nil &&
                   hasDate
        }
    }

    var isDateTimeValid: Bool {
        guard let slot = selectedTimeSlot else { return false }
        var components = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
        components.hour = slot.hour
        components.minute = slot.minute
        guard let dateTime = Calendar.current.date(from: components) else { return false }
        let minDateTime = Calendar.current.date(byAdding: .hour, value: 24, to: Date()) ?? Date()
        return dateTime > minDateTime
    }

    /// Boarding-only validation — both dates set, check-out strictly after
    /// check-in, check-in at least 24 hours from now. Matches Android's
    /// `BoardingBookingStep` rules in `UnifiedBookingFlowViewModel.kt`.
    var isBoardingDateRangeValid: Bool {
        guard let checkIn = boardingCheckInDate,
              let checkOut = boardingCheckOutDate else { return false }
        guard let checkInAt14 = Self.dateAtTime(checkIn, hour: 14, minute: 0) else { return false }
        let minDateTime = Calendar.current.date(byAdding: .hour, value: 24, to: Date()) ?? Date()
        return checkInAt14 > minDateTime && checkOut > checkIn
    }

    /// Number of nights for a boarding stay, or nil if either date is unset.
    /// Used by the review screen + price calc.
    var boardingNights: Int? {
        guard let checkIn = boardingCheckInDate,
              let checkOut = boardingCheckOutDate else { return nil }
        let cal = Calendar.current
        let inDay = cal.startOfDay(for: checkIn)
        let outDay = cal.startOfDay(for: checkOut)
        let nights = cal.dateComponents([.day], from: inDay, to: outDay).day ?? 0
        return max(nights, 0)
    }

    var selectedDateTime: Date? {
        if selectedService == .boarding {
            guard let checkIn = boardingCheckInDate else { return nil }
            return Self.dateAtTime(checkIn, hour: 14, minute: 0)
        }
        guard let slot = selectedTimeSlot else { return nil }
        var components = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
        components.hour = slot.hour
        components.minute = slot.minute
        return Calendar.current.date(from: components)
    }

    private static func dateAtTime(_ date: Date, hour: Int, minute: Int) -> Date? {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)
    }

    var minimumDate: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    }

    var maxDogsForService: Int {
        selectedService?.maxDogs ?? 4
    }

    // MARK: - Navigation

    func goToNextStep() {
        guard canProceed, let next = currentStep.next else { return }

        if next == .selectProvider {
            searchProviders()
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = next
        }

        if next == .addDetails {
            // R10: kick off profile preload for the first selected dog so
            // the form lands on rich, prefilled fields rather than blanks.
            loadDogDetailsIfNeeded()
        }

        if next == .reviewConfirm {
            calculatePrice()
        }
    }

    // MARK: - R10: Dog details preload + save-back

    /// One-shot fetch of the full UnifiedDog for the *first* selected dog
    /// (multi-dog bookings still capture details once for now — flagged
    /// as a Phase-2 enhancement in the spec). Honours the dirty-flag guard
    /// in `BookingDogDetailsLoader.prefill` so a back-nav into the step
    /// keeps the user's edits intact.
    func loadDogDetailsIfNeeded() {
        guard let service = selectedService else { return }
        guard let dogId = selectedDogIds.first, !dogId.isEmpty else { return }

        // If we've already loaded this dog and the snapshot matches, skip
        // re-fetch — the dirty-flag guard would no-op anyway, but this
        // saves a Firestore round-trip per back-nav.
        let snapshotMatches = (dogProfileSnapshot?.id ?? "") == dogId
        if snapshotMatches && dogDetails.dogId == dogId {
            return
        }

        // Reset form state when switching dogs (different selection between
        // back-nav cycles). Preserve dirty-flag semantics by only resetting
        // when the dog actually changed.
        if dogDetails.dogId != dogId {
            dogDetails = BookingDogDetails()
            dogDetails.dogId = dogId
            dogDetailsSizeNudgeShown = false
        }

        // Echo the lightweight name/breed from the SelectableDog into the
        // form synchronously so the UI doesn't flash blank while the full
        // doc loads.
        if let lite = dogs.first(where: { $0.id == dogId }) {
            dogDetails.dogName = lite.name
            if dogDetails.breed.value.isEmpty && !dogDetails.breed.isDirty {
                dogDetails.breed.prefill(lite.breed ?? "")
            }
        }

        dogDetailsLoading = true
        Task {
            let dog = await BookingDogDetailsLoader.loadDog(id: dogId)
            await MainActor.run {
                self.dogDetailsLoading = false
                guard let dog = dog else { return }
                self.dogProfileSnapshot = dog
                let hadSize = (dog.size?.isEmpty == false)
                BookingDogDetailsLoader.prefill(
                    &self.dogDetails,
                    from: dog,
                    serviceType: service
                )
                self.dogDetailsSizeNudgeShown = !hadSize
            }
        }
    }

    /// Diff the form against the originally-loaded dog and write the diff
    /// to `dogs/{dogId}`. Non-blocking — failures surface as a soft toast
    /// while the booking still proceeds. Called from `submitBooking`
    /// before the booking is created so the profile is in sync if the
    /// booking succeeds.
    func saveDogDetailsBackToProfile() async {
        guard dogDetails.saveBackToProfile,
              let original = dogProfileSnapshot,
              let dogId = dogDetails.dogId, !dogId.isEmpty else { return }
        let diff = BookingDogDetailsLoader.profileDiff(
            details: dogDetails,
            original: original
        )
        guard !diff.isEmpty else { return }
        do {
            try await BookingDogDetailsLoader.writeProfileDiff(
                dogId: dogId,
                diff: diff
            )
        } catch {
            print("[BookingFlow] saveDogDetailsBackToProfile failed: \(error.localizedDescription)")
            await MainActor.run {
                self.dogDetailsSaveBackToast = "Couldn't update profile, but your booking is in"
            }
        }
    }

    func goToPreviousStep() {
        guard let previous = currentStep.previous else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = previous
        }
    }

    // MARK: - Service Selection

    func selectService(_ service: BookingServiceType) {
        selectedService = service
        // Reset downstream selections when service changes
        selectedDogIds.removeAll()
        selectedProvider = nil
        selectedTimeSlot = nil
        subSelectionPayload = nil
        subSelectionLabel = nil
        subSelectionPrice = nil
        // Reset payment-method state too — the next provider's
        // acceptedMethods will repopulate this when picked. Defaulting
        // back to card-only avoids a stale cash-only list flashing on the
        // review step before the new provider's settings load.
        acceptedPaymentMethods = ["card"]
        paymentMethod = "card"
        // Recurring config is per-booking — switching service resets it
        // so the user re-confirms it for the new vertical (e.g. a
        // weekly walk doesn't bleed into a one-off boarding stay).
        recurrencePattern = nil
    }

    // Map UI ServiceType to BookingServiceType
    func selectServiceFromCard(_ serviceType: ServiceType) {
        let mapped: BookingServiceType
        switch serviceType {
        case .dailyWalks: mapped = .walk
        case .inHomeSitting: mapped = .inSitting
        case .daycare: mapped = .daycare
        case .overnightBoarding: mapped = .boarding
        case .grooming: mapped = .grooming
        case .training: mapped = .training
        }
        selectService(mapped)
    }

    /// Pre-select a provider by ID, fetching their details from Firestore.
    func preselectProvider(id providerId: String) {
        let db = Firestore.firestore()
        db.collection("businesses").document(providerId).getDocument { [weak self] snapshot, error in
            DispatchQueue.main.async {
                guard let self = self, let data = snapshot?.data() else { return }
                let provider = SelectableProvider(
                    id: providerId,
                    name: data["displayName"] as? String ?? data["name"] as? String ?? "Provider",
                    photoUrl: data["photoUrl"] as? String,
                    rating: (data["rating"] as? NSNumber)?.doubleValue ?? 0,
                    reviewCount: (data["reviewCount"] as? NSNumber)?.intValue ?? 0,
                    distance: (data["distance"] as? NSNumber)?.doubleValue,
                    basePrice: (data["basePrice"] as? NSNumber)?.doubleValue ?? 25.0,
                    bio: data["bio"] as? String,
                    isVerified: data["isVerified"] as? Bool ?? false
                )
                self.selectProvider(provider)
                if !self.providers.contains(where: { $0.id == providerId }) {
                    self.providers.insert(provider, at: 0)
                }
            }
        }
    }

    /// Set the chosen provider and refresh the accepted-payment-methods
    /// list from `organizations/{orgId}.paymentSettings.acceptedMethods`
    /// (with a legacy fallback). The provider-card tap and the deep-link
    /// pre-select path both flow through here so the picker on the review
    /// step is always in sync with whatever provider the user landed on.
    func selectProvider(_ provider: SelectableProvider) {
        selectedProvider = provider
        loadAcceptedPaymentMethods(forOrgId: provider.id)
    }

    /// Read the provider's accepted payment methods. Source of truth is
    /// `organizations/{orgId}.paymentSettings.acceptedMethods: [String]`
    /// (e.g. `["card"]`, `["cash"]`, or `["card","cash"]`). Falls back to
    /// the legacy `organization_settings/{orgId}.payments.acceptCash` /
    /// `.acceptCard` booleans for older docs, then to `["card"]` if
    /// neither is set. Never returns an empty list — that would lock the
    /// user out of submitting.
    ///
    /// On completion this also reconciles `paymentMethod` so the default
    /// matches the first accepted entry (the previous default of "card"
    /// would otherwise survive on a cash-only provider, which would then
    /// be rejected at submit).
    func loadAcceptedPaymentMethods(forOrgId orgId: String) {
        guard !orgId.isEmpty else {
            self.acceptedPaymentMethods = ["card"]
            self.paymentMethod = "card"
            return
        }
        let db = Firestore.firestore()
        db.collection("organizations").document(orgId).getDocument { [weak self] snapshot, _ in
            guard let self = self else { return }
            let data = snapshot?.data()
            // Primary: paymentSettings.acceptedMethods on the org doc.
            var methods: [String] = []
            if let settings = data?["paymentSettings"] as? [String: Any],
               let raw = settings["acceptedMethods"] as? [String] {
                methods = raw
                    .map { $0.lowercased() }
                    .filter { $0 == "card" || $0 == "cash" }
            }
            if methods.isEmpty {
                // Legacy fallback on the same doc — some older orgs put
                // `acceptCash` / `acceptCard` directly under `paymentSettings`.
                if let settings = data?["paymentSettings"] as? [String: Any] {
                    if (settings["acceptCard"] as? Bool) == true { methods.append("card") }
                    if (settings["acceptCash"] as? Bool) == true { methods.append("cash") }
                }
            }
            if methods.isEmpty {
                // Final fallback: organization_settings/{orgId}.payments.*.
                self.legacyLoadAcceptCardCash(orgId: orgId)
                return
            }
            self.applyAcceptedMethods(methods)
        }
    }

    /// Read `organization_settings/{orgId}.payments.acceptCash`/`.acceptCard`
    /// for orgs that haven't migrated to the consolidated `paymentSettings`
    /// shape. Defaults to `["card"]` if neither is present.
    private func legacyLoadAcceptCardCash(orgId: String) {
        let db = Firestore.firestore()
        db.collection("organization_settings").document(orgId).getDocument { [weak self] snapshot, _ in
            guard let self = self else { return }
            var methods: [String] = []
            if let payments = snapshot?.data()?["payments"] as? [String: Any] {
                if (payments["acceptCard"] as? Bool) == true { methods.append("card") }
                if (payments["acceptCash"] as? Bool) == true { methods.append("cash") }
            }
            if methods.isEmpty { methods = ["card"] }
            self.applyAcceptedMethods(methods)
        }
    }

    /// Push the resolved accepted-methods list to state on the main queue
    /// and reconcile the current selection so we never submit a method
    /// the provider doesn't accept.
    private func applyAcceptedMethods(_ methods: [String]) {
        // De-dupe while preserving order (card-first feels more natural
        // when both are accepted; the source-of-truth ordering wins).
        var seen = Set<String>()
        let deduped = methods.filter { seen.insert($0).inserted }
        let resolved = deduped.isEmpty ? ["card"] : deduped
        DispatchQueue.main.async {
            self.acceptedPaymentMethods = resolved
            if !resolved.contains(self.paymentMethod) {
                self.paymentMethod = resolved.first ?? "card"
            }
        }
    }

    // MARK: - Dog Selection

    func toggleDog(_ dogId: String) {
        if selectedDogIds.contains(dogId) {
            selectedDogIds.remove(dogId)
        } else if selectedDogIds.count < maxDogsForService {
            selectedDogIds.insert(dogId)
        }
    }

    func fetchUserDogs() {
        guard let userId = currentUserId else { return }
        isLoading = true

        db.collection("dogs")
            .whereField("primaryOwnerId", isEqualTo: userId)
            .whereField("isArchived", isEqualTo: false)
            .getDocuments { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    if let error = error {
                        print("[BookingFlow] Error fetching dogs: \(error.localizedDescription)")
                        return
                    }

                    self?.dogs = snapshot?.documents.compactMap { doc in
                        let data = doc.data()
                        return SelectableDog(
                            id: doc.documentID,
                            name: data["name"] as? String ?? "",
                            breed: data["breed"] as? String,
                            photoUrl: data["photoUrl"] as? String
                        )
                    } ?? []
                }
            }
    }

    // MARK: - Provider Search

    func searchProviders() {
        guard let service = selectedService else { return }
        isSearchingProviders = true

        db.collection("businesses")
            .whereField("services", arrayContains: service.rawValue)
            .whereField("acceptingNewClients", isEqualTo: true)
            .limit(to: 30)
            .getDocuments { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    self?.isSearchingProviders = false
                    if let error = error {
                        print("[BookingFlow] Error searching providers: \(error.localizedDescription)")
                        self?.providers = []
                        return
                    }

                    self?.providers = snapshot?.documents.compactMap { doc in
                        let data = doc.data()
                        return SelectableProvider(
                            id: doc.documentID,
                            name: data["displayName"] as? String ?? data["name"] as? String ?? "Provider",
                            photoUrl: data["photoUrl"] as? String,
                            rating: (data["rating"] as? NSNumber)?.doubleValue ?? 0,
                            reviewCount: (data["reviewCount"] as? NSNumber)?.intValue ?? 0,
                            distance: (data["distance"] as? NSNumber)?.doubleValue,
                            basePrice: (data["basePrice"] as? NSNumber)?.doubleValue ?? 25.0,
                            bio: data["bio"] as? String,
                            isVerified: data["isVerified"] as? Bool ?? false
                        )
                    } ?? []
                }
            }
    }

    // MARK: - Price Calculation

    func calculatePrice() {
        guard let service = selectedService,
              let provider = selectedProvider else { return }

        // R9: prefer the price resolved from the sub-config pick
        // (boarding/grooming/etc.) over the legacy provider basePrice.
        let basePrice = subSelectionPrice ?? provider.basePrice
        let extraDogsFee = selectedDogIds.count > 1 ? Double(selectedDogIds.count - 1) * 5.0 : 0.0
        // When a sub-config option is picked, duration is implicit in the
        // option (e.g. 30 vs 60 min walk) — skip the legacy default-duration
        // adjustment to avoid double-charging.
        let durationAdjustment: Double
        if subSelectionPrice != nil {
            durationAdjustment = 0
        } else {
            let defaultDuration = service.defaultDuration
            durationAdjustment = defaultDuration > 60
                ? Double(defaultDuration - 60) / 30.0 * 5.0
                : 0.0
        }
        let subtotal = basePrice + extraDogsFee + durationAdjustment
        let platformFee = subtotal * 0.10

        priceBreakdown = BookingPriceBreakdown(
            basePrice: basePrice,
            additionalDogFee: extraDogsFee,
            durationAdjustment: durationAdjustment,
            platformFee: platformFee,
            total: subtotal + platformFee
        )
    }

    // MARK: - Submit Booking

    func submitBooking() {
        guard let userId = currentUserId,
              let service = selectedService,
              let provider = selectedProvider,
              let dateTime = selectedDateTime else {
            errorMessage = "Please complete all required fields."
            return
        }

        isLoading = true
        errorMessage = nil

        let dogNames = dogs.filter { selectedDogIds.contains($0.id) }.map { $0.name }

        // Endpoint for the booking window. For boarding: check-out at 11:00.
        // For everything else: dateTime + service.defaultDuration minutes.
        // Android applies the same 14:00 / 11:00 contract in
        // UnifiedBookingFlowViewModel#submitBooking.
        let endTime: Date
        let boardingDatesPayload: (checkInMs: Int64, checkOutMs: Int64)?
        if service == .boarding,
           let checkInDate = boardingCheckInDate,
           let checkOutDate = boardingCheckOutDate,
           let checkInAt14 = Calendar.current.date(
               bySettingHour: 14, minute: 0, second: 0, of: checkInDate),
           let checkOutAt11 = Calendar.current.date(
               bySettingHour: 11, minute: 0, second: 0, of: checkOutDate) {
            endTime = checkOutAt11
            boardingDatesPayload = (
                checkInMs: Booking.toEpochMs(checkInAt14),
                checkOutMs: Booking.toEpochMs(checkOutAt11)
            )
        } else {
            let durationMinutes = service.defaultDuration
            endTime = Calendar.current.date(byAdding: .minute, value: durationMinutes, to: dateTime) ?? dateTime
            boardingDatesPayload = nil
        }

        let booking = Booking(
            clientId: userId,
            clientName: Auth.auth().currentUser?.displayName ?? "",
            businessId: provider.id,
            orgId: provider.id,
            organizationId: provider.id,
            dogName: dogNames.joined(separator: ", "),
            serviceType: service.rawValue,
            startTime: Booking.toEpochMs(dateTime),
            endTime: Booking.toEpochMs(endTime),
            status: BookingStatus.pending.rawValue,
            location: "",
            notes: instructions.specialInstructions.isEmpty ? nil : instructions.specialInstructions,
            price: priceBreakdown.total,
            specialInstructions: instructions.feedingNotes.isEmpty ? nil : instructions.feedingNotes,
            specialRequirements: instructions.accessInstructions.isEmpty ? nil : instructions.accessInstructions
        )

        let bookingRepo = BookingRepository()
        let subSelection = subSelectionPayload
        let subLabel = subSelectionLabel
        let method = paymentMethod
        let providerOrgId = provider.id
        let boardingDates = boardingDatesPayload
        // Recurring opt-in: forward the pattern when the user has
        // enabled it AND set a stop condition (end-date OR max
        // occurrences). The CF rejects an unbounded series with
        // `invalid-argument` and we surface that as `errorMessage` —
        // matches Android's `UnifiedBookingFlowViewModel#submitBooking`
        // which similarly defers to the server for stop-condition
        // validation. We skip the payload entirely (one-off booking)
        // when the user has the recurrence section collapsed (pattern
        // is nil), since Android's `recurrenceEnabled=false` path drops
        // the `recurrence` key wholesale.
        let recurrence: RecurrencePattern? = recurrencePattern

        // R10: pack the rich dog-details block when the vertical is
        // grooming / walking / sitting. Boarding / daycare / training
        // skip it (their detail capture lives elsewhere).
        let dogDetailsPayload: [String: Any]?
        let perVerticalConfig: (key: String, value: [String: Any])?
        switch service {
        case .grooming:
            dogDetailsPayload = dogDetails.toServerPayload(serviceType: service)
            perVerticalConfig = ("groomingConfigOverlay", dogDetails.grooming.toPayload())
        case .walk, .meetGreet:
            dogDetailsPayload = dogDetails.toServerPayload(serviceType: service)
            perVerticalConfig = ("walkConfigOverlay", dogDetails.walk.toPayload())
        case .petSitting, .inSitting, .outSitting:
            dogDetailsPayload = dogDetails.toServerPayload(serviceType: service)
            perVerticalConfig = ("petSittingConfigOverlay", dogDetails.sitting.toPayload())
        default:
            dogDetailsPayload = nil
            perVerticalConfig = nil
        }

        let total = priceBreakdown.total

        Task {
            // R10: write profile diff back if the user opted in. Run
            // before the booking call so a successful save shows on
            // the profile by the time the confirmation lands.
            await self.saveDogDetailsBackToProfile()

            do {
                let bookingId = try await bookingRepo.createBooking(
                    booking,
                    subSelection: subSelection,
                    subSelectionLabel: subLabel,
                    paymentMethod: method,
                    boardingDates: boardingDates,
                    dogDetails: dogDetailsPayload,
                    perVerticalOverlay: perVerticalConfig,
                    recurrence: recurrence
                )

                // Cash flow: provider takes payment in person — no Stripe.
                // Surface success immediately. (Mirrors Android's
                // `isCash` branch in UnifiedBookingFlowViewModel#submitBooking.)
                if method == "cash" || total <= 0 {
                    await MainActor.run {
                        self.isLoading = false
                        self.bookingCreatedId = bookingId
                    }
                    return
                }

                // Card flow: kick off Stripe PaymentIntent creation. We
                // intentionally DON'T set bookingCreatedId yet — that
                // drives the success alert, and we want the success alert
                // gated on PaymentSheet completion (Android does the same:
                // it transitions to the PAYMENT step and only emits
                // BookingUiState.BookingCreated after confirmPayment).
                await MainActor.run {
                    self.paymentInFlight = true
                }

                do {
                    let stripeService = StripePaymentService()
                    let secret = try await stripeService.requestClientSecret(bookingId: bookingId)
                    await MainActor.run {
                        self.isLoading = false
                        self.paymentClientSecret = secret
                        self.pendingPaymentBookingId = bookingId
                        self.presentPaymentSheet = true
                    }
                } catch {
                    // PaymentIntent creation failed. The booking doc is
                    // still created server-side (sitting in `pending`); we
                    // surface the error and let the user retry from the
                    // review step. Don't set bookingCreatedId.
                    await MainActor.run {
                        self.isLoading = false
                        self.paymentInFlight = false
                        self.errorMessage = "Couldn't start payment: \(error.localizedDescription)"
                    }
                }
                return
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    // Cash-shortage detection: when the CF rejects a cash
                    // booking because the provider's wallet balance is <=0,
                    // it throws Functions error code `failedPrecondition`
                    // with one of the wallet-empty signal strings. Don't
                    // show a generic alert — surface the notify sheet so
                    // the user can ping the business to top up.
                    if method == "cash",
                       BookingFlowViewModel.isWalletEmptySignal(error: error) {
                        self.cashShortageRequestId = nil
                        self.cashShortageAlreadyOpen = false
                        self.showCashShortageSheet = true
                        // Stash the orgId for the sheet via a side channel.
                        self.pendingCashShortageOrgId = providerOrgId
                    } else {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    // MARK: - Stripe PaymentSheet completion

    /// Handle the result of the PaymentSheet. Mirrors Android's
    /// `confirmPayment()` + `onPaymentFailed()` in UnifiedBookingFlowViewModel.
    ///
    /// - `.completed` → call `confirmPayment` server-side, then surface
    ///   the success alert (sets `bookingCreatedId`).
    /// - `.canceled` → user backed out of the sheet. Stay on review step,
    ///   no error. Booking doc remains `pending` server-side; user can
    ///   retry submit from the review step.
    /// - `.failed(error)` → Stripe-side payment failure. Surface error
    ///   message to the user; same recovery path as canceled.
    func confirmPayment(_ result: PaymentSheetResult) {
        switch result {
        case .completed:
            guard let secret = paymentClientSecret,
                  let bookingId = pendingPaymentBookingId,
                  let paymentIntentId = StripePaymentService.paymentIntentId(fromClientSecret: secret) else {
                // Shouldn't happen — completion implies we had both. Surface
                // a sentinel error so the user contacts support rather than
                // silently leaving the booking in an unconfirmed state.
                errorMessage = "Payment captured but confirm failed — contact support"
                clearPaymentState()
                return
            }

            let stripeService = StripePaymentService()
            Task {
                do {
                    try await stripeService.confirmOnServer(
                        bookingId: bookingId,
                        paymentIntentId: paymentIntentId
                    )
                    await MainActor.run {
                        self.bookingCreatedId = bookingId
                        self.clearPaymentState()
                    }
                } catch {
                    // Stripe charged the customer but our confirm-callable
                    // failed. The webhook on `payment_intent.succeeded`
                    // will eventually flip the booking server-side; tell
                    // the user to contact support so we don't double-charge
                    // on retry.
                    print("[BookingFlowViewModel] confirmOnServer failed: \(error.localizedDescription)")
                    await MainActor.run {
                        self.errorMessage = "Payment captured but confirm failed — contact support"
                        self.clearPaymentState()
                    }
                }
            }

        case .canceled:
            // User backed out. No error — they can re-submit. Don't surface
            // an alert (matches Android's silent dismiss path).
            presentPaymentSheet = false
            paymentInFlight = false

        case .failed(let error):
            errorMessage = "Payment failed: \(error.localizedDescription)"
            clearPaymentState()
        }
    }

    /// Reset all in-flight Stripe state. Called from terminal states
    /// (.completed → success, .failed → error) so a fresh submit starts clean.
    private func clearPaymentState() {
        paymentClientSecret = nil
        pendingPaymentBookingId = nil
        presentPaymentSheet = false
        paymentInFlight = false
    }

    // MARK: - Cash-shortage helpers

    /// Org id captured at submit-time, used by the notify sheet.
    var pendingCashShortageOrgId: String?

    /// Detect the wallet-empty rejection from `createClientBooking`. The CF
    /// throws `failed-precondition` from two sites:
    ///   1) functions/src/index.ts:2266 — "This provider cannot accept cash
    ///      bookings right now — their wallet balance is empty"
    ///   2) functions/src/index.ts:2545 — "Insufficient wallet balance to
    ///      accept this cash booking. Need £…"
    /// Both surface as `NSError` in `FunctionsErrorDomain`. We match either
    /// the error code (failedPrecondition) coupled with a wallet keyword
    /// in the message, OR the message alone if the SDK transcoded the
    /// error domain.
    static func isWalletEmptySignal(error: Error) -> Bool {
        let nsErr = error as NSError
        let message = (nsErr.userInfo[NSLocalizedDescriptionKey] as? String) ?? nsErr.localizedDescription
        let lower = message.lowercased()
        let hasWalletSignal = lower.contains("wallet") &&
            (lower.contains("empty") || lower.contains("insufficient") || lower.contains("top up") || lower.contains("balance"))
        // The CF throws BOTH `failed-precondition` and a wallet-keyword
        // message (functions/src/index.ts:2266 / :2545). Other failed-
        // precondition rejects (e.g. "Stripe not configured") would
        // false-positive if we matched on code alone, so require both.
        let isFunctionsFailedPrecondition = nsErr.domain == FunctionsErrorDomain
            && nsErr.code == FunctionsErrorCode.failedPrecondition.rawValue
        return isFunctionsFailedPrecondition && hasWalletSignal
    }

    /// Fire the `requestCashTopup` callable from the notify sheet.
    /// Sets `cashShortageRequestId` on success so the sheet flips to its
    /// success state. The CF is idempotent — `already-exists` (or
    /// `alreadyOpen: true` in the response) flips `cashShortageAlreadyOpen`.
    func submitCashShortageNotify(message: String?) async {
        guard let orgId = pendingCashShortageOrgId, !orgId.isEmpty else { return }
        let repo = CashTopupRepository()
        do {
            let id = try await repo.requestCashTopup(orgId: orgId, message: message)
            await MainActor.run {
                self.cashShortageRequestId = id
                self.cashShortageAlreadyOpen = false
            }
        } catch CashTopupError.alreadyOpen(let id) {
            await MainActor.run {
                self.cashShortageRequestId = id
                self.cashShortageAlreadyOpen = true
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    /// Flip to card and re-fire submitBooking. Wired to the secondary CTA
    /// on the cash-shortage sheet.
    func switchToCardAndResubmit() {
        paymentMethod = "card"
        showCashShortageSheet = false
        submitBooking()
    }
}

// MARK: - Main Booking Flow Screen

struct BookingFlowScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = BookingFlowViewModel()
    @State private var showSuccessAlert = false

    /// Stripe PaymentSheet instance, built lazily once we have a clientSecret.
    /// Held as @State so the same sheet survives across re-renders while
    /// the user interacts with it. Re-built whenever
    /// `viewModel.paymentClientSecret` changes (e.g. after a cancel + retry).
    @State private var paymentSheet: PaymentSheet?

    var preselectedService: ServiceType?
    var preselectedProviderId: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Step indicator
            stepIndicator

            // Step content
            TabView(selection: $viewModel.currentStep) {
                selectServiceStep.tag(BookingStep.selectService)
                selectDogsStep.tag(BookingStep.selectDogs)
                selectProviderStep.tag(BookingStep.selectProvider)
                pickDateTimeStep.tag(BookingStep.pickDateTime)
                addDetailsStep.tag(BookingStep.addDetails)
                reviewConfirmStep.tag(BookingStep.reviewConfirm)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)
            .allowsHitTesting(!viewModel.isLoading)

            // Bottom buttons
            if viewModel.currentStep != .reviewConfirm {
                bottomButtons
            }
        }
        .background(Color.neutral10)
        .onAppear {
            viewModel.fetchUserDogs()
            if let service = preselectedService {
                viewModel.selectServiceFromCard(service)
                viewModel.currentStep = .selectDogs
            }
            if let providerId = preselectedProviderId {
                viewModel.preselectProvider(id: providerId)
            }
        }
        .onChange(of: viewModel.bookingCreatedId) { newId in
            if newId != nil {
                showSuccessAlert = true
            }
        }
        .alert("Booking Confirmed!", isPresented: $showSuccessAlert) {
            Button(String(localized: "action_done")) {
                dismiss()
            }
        } message: {
            // Cash flow: payment happens in person, surface what's owed.
            // Card flow: PaymentSheet has already completed and the server
            // has confirmed the PaymentIntent — booking is paid, awaiting
            // the provider's confirm.
            if viewModel.paymentMethod == "cash" {
                let total = CurrencyFormatter.shared.formatPrice(viewModel.priceBreakdown.total)
                Text(String(format: String(localized: "booking_pay_now_summary_format"), total))
            } else {
                Text(String(localized: "booking_pay_received_summary"))
            }
        }
        .alert(String(localized: "generic_error_header"), isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(String(localized: "action_ok")) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $viewModel.showCashShortageSheet) {
            CashShortageNotifySheet(
                viewModel: viewModel,
                onDismiss: { viewModel.showCashShortageSheet = false }
            )
            .presentationDetents([.medium, .large])
        }
        // Stripe PaymentSheet — re-build whenever the clientSecret changes.
        // `merchantDisplayName` matches Android's Stripe PaymentSheet config.
        // `allowsDelayedPaymentMethods = false` mirrors Android's real-time
        // capture for booking flows (no SEPA / iDEAL multi-day settlement).
        .onChange(of: viewModel.paymentClientSecret) { newSecret in
            guard let secret = newSecret, !secret.isEmpty else {
                paymentSheet = nil
                return
            }
            var config = PaymentSheet.Configuration()
            config.merchantDisplayName = "WoofWalk"
            config.allowsDelayedPaymentMethods = false
            paymentSheet = PaymentSheet(
                paymentIntentClientSecret: secret,
                configuration: config
            )
        }
        // Attach the PaymentSheet modifier on a hidden zero-size sentinel
        // view so the modifier can take a non-optional `PaymentSheet`. We
        // only render this sentinel when we actually have a sheet to
        // present, so the modifier itself only exists when valid.
        .background(paymentSheetSentinel)
    }

    /// Hidden sentinel view that hosts the Stripe `.paymentSheet` modifier.
    /// Stripe's SwiftUI helper needs a non-optional `PaymentSheet`; this
    /// view only exists when one is available.
    @ViewBuilder
    private var paymentSheetSentinel: some View {
        if let sheet = paymentSheet {
            Color.clear
                .frame(width: 0, height: 0)
                .paymentSheet(
                    isPresented: $viewModel.presentPaymentSheet,
                    paymentSheet: sheet,
                    onCompletion: { result in
                        viewModel.confirmPayment(result)
                    }
                )
        } else {
            Color.clear.frame(width: 0, height: 0)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                if viewModel.currentStep == .selectService {
                    dismiss()
                } else {
                    viewModel.goToPreviousStep()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.bold())
                    .foregroundColor(.white)
            }

            Spacer()

            Text(viewModel.currentStep.title)
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.success40)
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 4) {
            ForEach(BookingStep.allCases) { step in
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(stepColor(for: step))
                            .frame(width: 28, height: 28)

                        if step.rawValue < viewModel.currentStep.rawValue {
                            Image(systemName: "checkmark")
                                .font(.caption2.bold())
                                .foregroundColor(.white)
                        } else {
                            Text("\(step.rawValue + 1)")
                                .font(.caption2.bold())
                                .foregroundColor(step == viewModel.currentStep ? .white : .neutral50)
                        }
                    }

                    Text(step.title)
                        .font(.system(size: 9))
                        .foregroundColor(step == viewModel.currentStep ? .white : .neutral50)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)

                if step.rawValue < BookingStep.allCases.count - 1 {
                    Rectangle()
                        .fill(step.rawValue < viewModel.currentStep.rawValue ? Color.success40 : Color.neutral30)
                        .frame(height: 2)
                        .frame(maxWidth: 20)
                        .padding(.bottom, 16) // align with circles
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.bookingNeutral15)
    }

    private func stepColor(for step: BookingStep) -> Color {
        if step.rawValue < viewModel.currentStep.rawValue {
            return .success40
        } else if step == viewModel.currentStep {
            return Color(hex: 0x7C4DFF)
        } else {
            return .neutral30
        }
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        HStack(spacing: 12) {
            if viewModel.currentStep != .selectService {
                Button {
                    viewModel.goToPreviousStep()
                } label: {
                    Text(String(localized: "action_back"))
                        .font(.body.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.neutral30)
                        )
                }
            }

            Button {
                viewModel.goToNextStep()
            } label: {
                Text(String(localized: "action_next"))
                    .font(.body.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(viewModel.canProceed
                                  ? Color(hex: 0x7C4DFF)
                                  : Color.neutral30)
                    )
            }
            .disabled(!viewModel.canProceed)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.bookingNeutral15)
    }

    // MARK: - Step 1: Select Service

    private var selectServiceStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(String(localized: "booking_step_service_title"))
                    .font(.title3.bold())
                    .foregroundColor(.white)

                Text(String(localized: "booking_step_service_subtitle"))
                    .font(.subheadline)
                    .foregroundColor(.neutral60)

                // Service grid using BookingServiceType directly
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                ], spacing: 12) {
                    ForEach(BookingServiceType.allCases, id: \.rawValue) { service in
                        serviceCard(service)
                    }
                }
            }
            .padding(16)
        }
    }

    private func serviceCard(_ service: BookingServiceType) -> some View {
        let isSelected = viewModel.selectedService == service
        return Button {
            viewModel.selectService(service)
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color(hex: 0x7C4DFF).opacity(0.3) : Color.neutral20)
                        .frame(width: 48, height: 48)

                    Image(systemName: service.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isSelected ? Color(hex: 0xB388FF) : .neutral60)
                }

                Text(service.displayName)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 110)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color(hex: 0x7C4DFF).opacity(0.1) : Color.neutral20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color(hex: 0x7C4DFF) : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 2: Select Dogs

    private var selectDogsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(String(localized: "booking_step_dogs_title"))
                    .font(.title3.bold())
                    .foregroundColor(.white)

                if let service = viewModel.selectedService {
                    Text("Select up to \(service.maxDogs) dog\(service.maxDogs == 1 ? "" : "s") for \(service.displayName).")
                        .font(.subheadline)
                        .foregroundColor(.neutral60)
                }

                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, minHeight: 100)
                } else if viewModel.dogs.isEmpty {
                    emptyDogsView
                } else {
                    ForEach(viewModel.dogs) { dog in
                        dogSelectionRow(dog)
                    }
                }
            }
            .padding(16)
        }
    }

    private var emptyDogsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "dog.fill")
                .font(.system(size: 40))
                .foregroundColor(.neutral50)

            Text(String(localized: "booking_step_dogs_empty_title"))
                .font(.headline)
                .foregroundColor(.white)

            Text(String(localized: "booking_step_dogs_empty_subtitle"))
                .font(.subheadline)
                .foregroundColor(.neutral60)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.neutral20)
        )
    }

    private func dogSelectionRow(_ dog: SelectableDog) -> some View {
        let isSelected = viewModel.selectedDogIds.contains(dog.id)
        return Button {
            viewModel.toggleDog(dog.id)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color(hex: 0x7C4DFF).opacity(0.3) : Color.neutral30)
                        .frame(width: 50, height: 50)

                    Image(systemName: "dog.fill")
                        .font(.title3)
                        .foregroundColor(isSelected ? Color(hex: 0xB388FF) : .neutral60)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(dog.name)
                        .font(.body.bold())
                        .foregroundColor(.white)

                    if let breed = dog.breed, !breed.isEmpty {
                        Text(breed)
                            .font(.caption)
                            .foregroundColor(.neutral60)
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(isSelected ? Color(hex: 0x7C4DFF) : Color.neutral30)
                        .frame(width: 28, height: 28)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color(hex: 0x7C4DFF).opacity(0.08) : Color.neutral20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color(hex: 0x7C4DFF) : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 3: Select Provider

    private var selectProviderStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(String(localized: "booking_step_provider_title"))
                    .font(.title3.bold())
                    .foregroundColor(.white)

                Text(String(localized: "booking_step_provider_subtitle"))
                    .font(.subheadline)
                    .foregroundColor(.neutral60)

                if viewModel.isSearchingProviders {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                        Text(String(localized: "booking_step_provider_searching"))
                            .font(.subheadline)
                            .foregroundColor(.neutral60)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else if viewModel.providers.isEmpty {
                    noProvidersView
                } else {
                    ForEach(viewModel.providers) { provider in
                        providerCard(provider)
                    }
                }
            }
            .padding(16)
        }
    }

    private var noProvidersView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.slash.fill")
                .font(.system(size: 40))
                .foregroundColor(.neutral50)

            Text(String(localized: "booking_step_provider_empty_title"))
                .font(.headline)
                .foregroundColor(.white)

            Text(String(localized: "booking_step_provider_empty_subtitle"))
                .font(.subheadline)
                .foregroundColor(.neutral60)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.neutral20)
        )
    }

    private func providerCard(_ provider: SelectableProvider) -> some View {
        let isSelected = viewModel.selectedProvider?.id == provider.id
        return Button {
            viewModel.selectProvider(provider)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(Color.neutral30)
                            .frame(width: 52, height: 52)

                        Image(systemName: "person.fill")
                            .font(.title3)
                            .foregroundColor(.neutral50)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(provider.name)
                                .font(.body.bold())
                                .foregroundColor(.white)

                            if provider.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }

                        HStack(spacing: 8) {
                            // Rating
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundColor(.yellow)
                                Text(String(format: "%.1f", provider.rating))
                                    .font(.caption)
                                    .foregroundColor(.white)
                                Text("(\(provider.reviewCount))")
                                    .font(.caption)
                                    .foregroundColor(.neutral50)
                            }

                            // Distance
                            if provider.distance != nil {
                                HStack(spacing: 2) {
                                    Image(systemName: "location.fill")
                                        .font(.caption2)
                                        .foregroundColor(.neutral50)
                                    Text(provider.formattedDistance)
                                        .font(.caption)
                                        .foregroundColor(.neutral60)
                                }
                            }
                        }
                    }

                    Spacer()

                    // Price
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(provider.formattedPrice)
                            .font(.body.bold())
                            .foregroundColor(.success40)
                        Text(String(localized: "booking_step_provider_base_price"))
                            .font(.caption2)
                            .foregroundColor(.neutral50)
                    }
                }

                if let bio = provider.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(.neutral60)
                        .lineLimit(2)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color(hex: 0x7C4DFF).opacity(0.08) : Color.neutral20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color(hex: 0x7C4DFF) : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 4: Pick Date & Time

    private var pickDateTimeStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if viewModel.selectedService == .boarding {
                    boardingDateRangeStep
                } else {
                    standardDateTimeStep
                }
            }
            .padding(16)
        }
    }

    /// Single-day date + time-slot UI for non-boarding services. Original
    /// pickDateTimeStep extracted so the boarding branch can render its
    /// own check-in / check-out picker without nesting.
    @ViewBuilder
    private var standardDateTimeStep: some View {
        Text(String(localized: "booking_step_when_title"))
            .font(.title3.bold())
            .foregroundColor(.white)

        Text(String(localized: "booking_step_when_lead_time"))
            .font(.subheadline)
            .foregroundColor(.neutral60)

        // Date picker
        VStack(alignment: .leading, spacing: 8) {
            Label("Date", systemImage: "calendar")
                .font(.subheadline.bold())
                .foregroundColor(.neutral60)

            DatePicker(
                "Select date",
                selection: $viewModel.selectedDate,
                in: viewModel.minimumDate...,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(Color(hex: 0x7C4DFF))
            .colorScheme(.dark)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.neutral20)
            )
        }

        // Time slots grid
        VStack(alignment: .leading, spacing: 8) {
            Label("Time", systemImage: "clock")
                .font(.subheadline.bold())
                .foregroundColor(.neutral60)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
            ], spacing: 8) {
                ForEach(viewModel.timeSlots) { slot in
                    timeSlotButton(slot)
                }
            }
        }

        if !viewModel.isDateTimeValid && viewModel.selectedTimeSlot != nil {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                Text(String(localized: "booking_step_when_too_soon"))
                    .font(.caption)
            }
            .foregroundColor(.orange)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.1))
            )
        }
    }

    /// Multi-night boarding date-range picker (parity with Android's
    /// `BoardingBookingStep`). Two date pickers — check-in and check-out —
    /// no time slots; check-in time is fixed at 14:00 and check-out at
    /// 11:00 to match the canonical home-boarding contract enforced
    /// server-side. Server expects check-in/check-out as epoch millis
    /// inside `boardingConfig`.
    @ViewBuilder
    private var boardingDateRangeStep: some View {
        Text(String(localized: "booking_step_boarding_title"))
            .font(.title3.bold())
            .foregroundColor(.white)

        Text(String(localized: "booking_step_boarding_subtitle"))
            .font(.subheadline)
            .foregroundColor(.neutral60)

        let checkInBinding = Binding<Date>(
            get: { viewModel.boardingCheckInDate ?? viewModel.minimumDate },
            set: { newValue in
                viewModel.boardingCheckInDate = newValue
                // If check-out is now <= check-in, push it forward by one
                // day so the pair stays internally consistent. User can
                // still adjust the check-out picker afterwards.
                if let out = viewModel.boardingCheckOutDate, out <= newValue {
                    viewModel.boardingCheckOutDate = Calendar.current.date(byAdding: .day, value: 1, to: newValue)
                }
            }
        )
        let checkOutMinimum: Date = {
            let base = viewModel.boardingCheckInDate ?? viewModel.minimumDate
            return Calendar.current.date(byAdding: .day, value: 1, to: base) ?? base
        }()
        let checkOutBinding = Binding<Date>(
            get: { viewModel.boardingCheckOutDate ?? checkOutMinimum },
            set: { viewModel.boardingCheckOutDate = $0 }
        )

        VStack(alignment: .leading, spacing: 8) {
            Label("Check-in", systemImage: "arrow.right.to.line.compact")
                .font(.subheadline.bold())
                .foregroundColor(.neutral60)
            DatePicker(
                "Check-in date",
                selection: checkInBinding,
                in: viewModel.minimumDate...,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(Color(hex: 0x7C4DFF))
            .colorScheme(.dark)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.neutral20)
            )
        }

        VStack(alignment: .leading, spacing: 8) {
            Label("Check-out", systemImage: "arrow.left.to.line.compact")
                .font(.subheadline.bold())
                .foregroundColor(.neutral60)
            DatePicker(
                "Check-out date",
                selection: checkOutBinding,
                in: checkOutMinimum...,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(Color(hex: 0x7C4DFF))
            .colorScheme(.dark)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.neutral20)
            )
        }

        if let nights = viewModel.boardingNights, nights > 0 {
            HStack(spacing: 6) {
                Image(systemName: "moon.stars.fill")
                    .font(.caption)
                Text("\(nights) night\(nights == 1 ? "" : "s")")
                    .font(.caption.bold())
            }
            .foregroundColor(Color(hex: 0xB388FF))
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: 0x7C4DFF).opacity(0.15))
            )
        }

        if viewModel.boardingCheckInDate != nil && viewModel.boardingCheckOutDate != nil
            && !viewModel.isBoardingDateRangeValid {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                Text(String(localized: "booking_step_boarding_invalid"))
                    .font(.caption)
            }
            .foregroundColor(.orange)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.1))
            )
        }
    }

    private func timeSlotButton(_ slot: TimeSlot) -> some View {
        let isSelected = viewModel.selectedTimeSlot?.id == slot.id
        return Button {
            viewModel.selectedTimeSlot = slot
        } label: {
            Text(slot.displayTime)
                .font(.caption.bold())
                .foregroundColor(isSelected ? .white : .neutral60)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color(hex: 0x7C4DFF) : Color.neutral20)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 5: Add Details

    private var addDetailsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(String(localized: "booking_step_details_title"))
                    .font(.title3.bold())
                    .foregroundColor(.white)

                Text(richDetailsHelpText)
                    .font(.subheadline)
                    .foregroundColor(.neutral60)

                // R9: catalogue sub-selection picker. Renders nothing if
                // the listing has no sub-config for this service type
                // (empty-state fallback → use provider.basePrice).
                if let provider = viewModel.selectedProvider,
                   let service = viewModel.selectedService,
                   let dateTime = viewModel.selectedDateTime {
                    R9SubSelectionPicker(
                        orgId: provider.id,
                        serviceType: service,
                        basePrice: provider.basePrice,
                        bookingStartTime: dateTime,
                        bookingEndTime: Calendar.current.date(byAdding: .minute, value: service.defaultDuration, to: dateTime) ?? dateTime
                    ) { selection in
                        if let sel = selection {
                            viewModel.subSelectionPayload = sel.payload
                            viewModel.subSelectionLabel = sel.label
                            viewModel.subSelectionPrice = sel.price
                        } else {
                            viewModel.subSelectionPayload = nil
                            viewModel.subSelectionLabel = nil
                            viewModel.subSelectionPrice = nil
                        }
                    }
                }

                // R10: rich dog-details capture for grooming / walking /
                // sitting. Other verticals fall through to the existing
                // free-text notes blocks.
                if isRichDetailsVertical, let service = viewModel.selectedService {
                    if viewModel.dogDetailsLoading {
                        HStack {
                            ProgressView().tint(.white)
                            Text("Loading \(viewModel.dogDetails.dogName.isEmpty ? "dog" : viewModel.dogDetails.dogName)'s profile…")
                                .font(.caption)
                                .foregroundColor(.neutral60)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    BookingDogDetailsView(
                        details: $viewModel.dogDetails,
                        serviceType: service,
                        originalDog: viewModel.dogProfileSnapshot,
                        isSizeNudgeShown: viewModel.dogDetailsSizeNudgeShown
                    )

                    if !viewModel.dogDetails.isValidForVerticals {
                        let breedEmpty = viewModel.dogDetails.breed.value
                            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        Text(breedEmpty
                             ? "Breed is required so your provider knows what to expect"
                             : "Pick a size — S / M / L / XL")
                            .font(.caption)
                            .foregroundColor(Color(hex: 0xFF7B7B))
                    }

                    Divider().background(Color.neutral20).padding(.vertical, 8)
                }

                // Recurring-bookings opt-in. Hidden for boarding —
                // multi-night stays don't fit a weekly/monthly cadence
                // (Android does the same in `UnifiedBookingFlowScreen`'s
                // recurrence section).
                if let baseDate = viewModel.selectedDateTime,
                   viewModel.selectedService != .boarding {
                    RecurrenceSelector(
                        baseDate: baseDate,
                        pattern: $viewModel.recurrencePattern
                    )
                }

                // Free-text catch-alls — kept for ALL verticals so the
                // user can still hand-write a note even when the structured
                // capture covers the bases.
                detailField(
                    label: "Anything else for your provider?",
                    icon: "text.bubble",
                    placeholder: "Optional — any special requests or care instructions...",
                    text: $viewModel.instructions.specialInstructions
                )

                if !isRichDetailsVertical {
                    detailField(
                        label: "Access Instructions",
                        icon: "key.fill",
                        placeholder: "Gate code, key location, parking info...",
                        text: $viewModel.instructions.accessInstructions
                    )

                    detailField(
                        label: "Feeding Notes",
                        icon: "fork.knife",
                        placeholder: "Feeding schedule, dietary restrictions...",
                        text: $viewModel.instructions.feedingNotes
                    )

                    detailField(
                        label: "Emergency Contact",
                        icon: "phone.fill",
                        placeholder: "Name and phone number...",
                        text: $viewModel.instructions.emergencyContact
                    )
                }
            }
            .padding(16)
        }
    }

    /// True for grooming / walking / sitting — drives whether the rich
    /// dog-details capture (spec doc 06) renders on the step.
    private var isRichDetailsVertical: Bool {
        switch viewModel.selectedService {
        case .grooming, .walk, .meetGreet,
             .petSitting, .inSitting, .outSitting:
            return true
        default:
            return false
        }
    }

    private var richDetailsHelpText: String {
        if isRichDetailsVertical {
            return "Tell your provider about your dog. Breed and size are required; everything else is optional but helps them give the best care."
        }
        return "Optional notes for your provider."
    }

    private func detailField(label: String, icon: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(label, systemImage: icon)
                .font(.subheadline.bold())
                .foregroundColor(.neutral60)

            TextEditor(text: text)
                .font(.body)
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 70, maxHeight: 120)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.neutral20)
                )
                .overlay(alignment: .topLeading) {
                    if text.wrappedValue.isEmpty {
                        Text(placeholder)
                            .font(.body)
                            .foregroundColor(.neutral40)
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    // MARK: - Step 6: Review & Confirm

    private var reviewConfirmStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(String(localized: "booking_step_review_title"))
                    .font(.title3.bold())
                    .foregroundColor(.white)

                // Service summary
                reviewSection(title: "Service", icon: "square.grid.2x2") {
                    if let service = viewModel.selectedService {
                        HStack {
                            Image(systemName: service.icon)
                                .foregroundColor(Color(hex: 0xB388FF))
                            Text(service.displayName)
                                .foregroundColor(.white)
                        }
                    }
                }

                // Dogs summary
                reviewSection(title: "Dogs", icon: "dog.fill") {
                    let selectedDogs = viewModel.dogs.filter { viewModel.selectedDogIds.contains($0.id) }
                    ForEach(selectedDogs) { dog in
                        HStack {
                            Image(systemName: "pawprint.fill")
                                .font(.caption)
                                .foregroundColor(.turquoise60)
                            Text(dog.name)
                                .foregroundColor(.white)
                            if let breed = dog.breed {
                                Text("(\(breed))")
                                    .font(.caption)
                                    .foregroundColor(.neutral50)
                            }
                        }
                    }
                }

                // Provider summary
                reviewSection(title: "Provider", icon: "person.fill") {
                    if let provider = viewModel.selectedProvider {
                        HStack {
                            Text(provider.name)
                                .foregroundColor(.white)
                            Spacer()
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundColor(.yellow)
                                Text(String(format: "%.1f", provider.rating))
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }

                // Date & Time summary — boarding shows the full check-in /
                // check-out range + nights count; everything else shows the
                // single-shot date+time pair.
                if viewModel.selectedService == .boarding,
                   let checkIn = viewModel.boardingCheckInDate,
                   let checkOut = viewModel.boardingCheckOutDate {
                    reviewSection(title: String(localized: "booking_step_boarding_title"), icon: "calendar") {
                        HStack {
                            Text(String(localized: "booking_review_check_in"))
                                .foregroundColor(.neutral60)
                            Spacer()
                            Text(checkIn, style: .date)
                                .foregroundColor(.white)
                            Text(String(localized: "booking_review_check_in_default"))
                                .foregroundColor(.neutral60)
                        }
                        HStack {
                            Text(String(localized: "booking_review_check_out"))
                                .foregroundColor(.neutral60)
                            Spacer()
                            Text(checkOut, style: .date)
                                .foregroundColor(.white)
                            Text(String(localized: "booking_review_check_out_default"))
                                .foregroundColor(.neutral60)
                        }
                        if let nights = viewModel.boardingNights, nights > 0 {
                            HStack {
                                Text(String(localized: "booking_review_total_nights"))
                                    .foregroundColor(.neutral60)
                                Spacer()
                                Text("\(nights)")
                                    .foregroundColor(.white)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                } else {
                    reviewSection(title: "Date & Time", icon: "calendar") {
                        if let dateTime = viewModel.selectedDateTime {
                            HStack {
                                Text(dateTime, style: .date)
                                    .foregroundColor(.white)
                                Spacer()
                                Text(dateTime, style: .time)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }

                // Recurring summary — shows ONLY when the user opted
                // into a series with a valid stop condition. Mirrors
                // Android's recurrence row on the review step.
                if let pattern = viewModel.recurrencePattern, pattern.hasStopCondition {
                    reviewSection(title: "Repeats", icon: "repeat") {
                        HStack {
                            Text(pattern.frequency.displayName)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        if let endDate = pattern.endDate {
                            HStack {
                                Text(String(localized: "booking_review_ends_on"))
                                    .foregroundColor(.neutral60)
                                Spacer()
                                Text(endDate, style: .date)
                                    .foregroundColor(.white)
                            }
                        } else if let count = pattern.maxOccurrences, count > 0 {
                            HStack {
                                Text(String(localized: "booking_review_total_occurrences"))
                                    .foregroundColor(.neutral60)
                                Spacer()
                                Text("\(count)")
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }

                // Instructions summary (if any)
                if !viewModel.instructions.specialInstructions.isEmpty ||
                   !viewModel.instructions.accessInstructions.isEmpty ||
                   !viewModel.instructions.feedingNotes.isEmpty ||
                   !viewModel.instructions.emergencyContact.isEmpty {
                    reviewSection(title: "Notes", icon: "doc.text") {
                        if !viewModel.instructions.specialInstructions.isEmpty {
                            reviewDetailLine("Instructions", viewModel.instructions.specialInstructions)
                        }
                        if !viewModel.instructions.accessInstructions.isEmpty {
                            reviewDetailLine("Access", viewModel.instructions.accessInstructions)
                        }
                        if !viewModel.instructions.feedingNotes.isEmpty {
                            reviewDetailLine("Feeding", viewModel.instructions.feedingNotes)
                        }
                        if !viewModel.instructions.emergencyContact.isEmpty {
                            reviewDetailLine("Emergency", viewModel.instructions.emergencyContact)
                        }
                    }
                }

                // Payment method picker (Phase 1 payments).
                paymentMethodPicker

                // Price breakdown
                priceBreakdownSection

                // Confirm button
                Button {
                    viewModel.submitBooking()
                } label: {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.body)
                            Text(String(localized: "booking_confirm_cta"))
                                .font(.body.bold())
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: 0x7C4DFF), Color(hex: 0xB388FF)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
                .disabled(viewModel.isLoading || !viewModel.canProceed)
                .opacity(viewModel.canProceed ? 1.0 : 0.5)
                .padding(.top, 8)
            }
            .padding(16)
        }
    }

    private func reviewSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.subheadline.bold())
                .foregroundColor(.neutral60)

            VStack(alignment: .leading, spacing: 6) {
                content()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.neutral20)
            )
        }
    }

    private func reviewDetailLine(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption.bold())
                .foregroundColor(.neutral50)
            Text(value)
                .font(.caption)
                .foregroundColor(.white)
        }
    }

    @ViewBuilder
    private var paymentMethodPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Payment method", systemImage: "creditcard")
                .font(.subheadline.bold())
                .foregroundColor(.neutral60)

            // When the provider only accepts one method we render a
            // read-only line — no picker, no choice. When both are
            // accepted, two radio cards. The list is never empty (the
            // loader coerces to ["card"] before publishing).
            if viewModel.acceptedPaymentMethods.count > 1 {
                HStack(spacing: 10) {
                    ForEach(viewModel.acceptedPaymentMethods, id: \.self) { method in
                        paymentChoiceButton(
                            label: paymentChoiceTitle(method),
                            icon: paymentChoiceIcon(method),
                            subtitle: paymentChoiceSubtitle(method),
                            value: method
                        )
                    }
                }
            } else {
                let only = viewModel.acceptedPaymentMethods.first ?? "card"
                HStack(spacing: 10) {
                    Image(systemName: paymentChoiceIcon(only))
                        .foregroundColor(.turquoise60)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(paymentChoiceTitle(only))
                            .font(.body.bold())
                            .foregroundColor(.white)
                        Text(paymentChoiceSubtitle(only))
                            .font(.caption)
                            .foregroundColor(.neutral60)
                    }
                    Spacer()
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.neutral20)
                )
            }
        }
    }

    /// Localised label + icon + helper-copy lookups, kept inline rather
    /// than as model-side helpers because the strings are UI-presentational
    /// (booking review step copy) and shouldn't leak into the VM.
    private func paymentChoiceTitle(_ method: String) -> String {
        switch method {
        case "cash": return "Pay in cash"
        default: return "Pay by card"
        }
    }

    private func paymentChoiceIcon(_ method: String) -> String {
        switch method {
        case "cash": return "banknote"
        default: return "creditcard.fill"
        }
    }

    private func paymentChoiceSubtitle(_ method: String) -> String {
        switch method {
        case "cash": return "Pay the provider directly on the day."
        default: return "Charged when booking is confirmed."
        }
    }

    private func paymentChoiceButton(label: String, icon: String, subtitle: String, value: String) -> some View {
        let isSelected = viewModel.paymentMethod == value
        return Button {
            viewModel.paymentMethod = value
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                    Text(label)
                        .font(.body.bold())
                }
                .foregroundColor(isSelected ? .white : .neutral60)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white.opacity(0.85) : .neutral50)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.turquoise60 : Color.neutral20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.turquoise60 : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var priceBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Price Breakdown", systemImage: "dollarsign.circle")
                .font(.subheadline.bold())
                .foregroundColor(.neutral60)

            VStack(spacing: 8) {
                // R9: echo the catalogue selection so the user can see
                // exactly what they're paying for (e.g. "Full Groom – Medium – £35").
                if let label = viewModel.subSelectionLabel, !label.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.turquoise60)
                        Text(label)
                            .font(.caption)
                            .foregroundColor(.white)
                            .lineLimit(2)
                        Spacer()
                    }
                    .padding(.bottom, 4)
                }

                priceRow(viewModel.subSelectionPrice != nil ? "Selected option" : "Base price",
                         viewModel.priceBreakdown.basePrice)

                if viewModel.priceBreakdown.additionalDogFee > 0 {
                    priceRow("Additional dogs", viewModel.priceBreakdown.additionalDogFee)
                }

                if viewModel.priceBreakdown.durationAdjustment > 0 {
                    priceRow("Duration adjustment", viewModel.priceBreakdown.durationAdjustment)
                }

                Divider().background(Color.neutral30)

                priceRow("Subtotal", viewModel.priceBreakdown.subtotal)
                priceRow("Platform fee (10%)", viewModel.priceBreakdown.platformFee)

                Divider().background(Color.neutral30)

                HStack {
                    Text(String(localized: "booking_review_total"))
                        .font(.body.bold())
                        .foregroundColor(.white)
                    Spacer()
                    Text(CurrencyFormatter.shared.formatPrice(viewModel.priceBreakdown.total))
                        .font(.title3.bold())
                        .foregroundColor(.success40)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.neutral20)
            )
        }
    }

    private func priceRow(_ label: String, _ amount: Double) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.neutral60)
            Spacer()
            Text(CurrencyFormatter.shared.formatPrice(amount))
                .font(.subheadline)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Color Extension for neutral15 (if not already defined elsewhere)

private extension Color {
    static let bookingNeutral15 = Color(hex: 0x1A1A2E)
}

// MARK: - Cash-shortage Notify Sheet

/// Modal sheet shown when a cash booking submit fails because the
/// provider's wallet balance is empty. Two states:
///   1) `cashShortageRequestId == nil` → form: optional note + "Notify
///      business" / "Pay by card instead" buttons.
///   2) `cashShortageRequestId != nil` → success state. Tells the user
///      we've pinged the provider and offers a "View conversation" link
///      via the deep-link route.
struct CashShortageNotifySheet: View {
    @ObservedObject var viewModel: BookingFlowViewModel
    var onDismiss: () -> Void

    @State private var note: String = ""
    @State private var isSubmitting: Bool = false
    @FocusState private var isNoteFocused: Bool

    private let noteCharLimit = 280

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let requestId = viewModel.cashShortageRequestId {
                    successState(requestId: requestId)
                } else {
                    formState
                }
            }
            .padding(20)
        }
        .background(Color.neutral10.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    // MARK: Form

    private var formState: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "banknote")
                    .font(.title)
                    .foregroundColor(.turquoise60)
                Text(String(localized: "booking_cash_unavailable_title"))
                    .font(.title3.bold())
                    .foregroundColor(.white)
                Text(String(localized: "booking_cash_unavailable_subtitle"))
                    .font(.subheadline)
                    .foregroundColor(.neutral60)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "booking_cash_unavailable_note_placeholder"))
                    .font(.caption.bold())
                    .foregroundColor(.neutral60)
                TextField("Optional", text: $note, axis: .vertical)
                    .lineLimit(2...5)
                    .focused($isNoteFocused)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.neutral20)
                    )
                    .foregroundColor(.white)
                    .onChange(of: note) { newValue in
                        if newValue.count > noteCharLimit {
                            note = String(newValue.prefix(noteCharLimit))
                        }
                    }
                Text("\(note.count)/\(noteCharLimit)")
                    .font(.caption2)
                    .foregroundColor(.neutral50)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Button {
                Task { await sendNotify() }
            } label: {
                HStack {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "paperplane.fill")
                        Text(String(localized: "booking_cash_unavailable_notify_cta"))
                            .font(.body.bold())
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.turquoise60)
                )
            }
            .disabled(isSubmitting)
            .buttonStyle(.plain)

            Button {
                viewModel.switchToCardAndResubmit()
            } label: {
                Text(String(localized: "booking_cash_unavailable_pay_card_cta"))
                    .font(.body.bold())
                    .foregroundColor(.turquoise60)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.turquoise60, lineWidth: 1.5)
                    )
            }
            .disabled(isSubmitting)
            .buttonStyle(.plain)

            Button(String(localized: "action_not_now"), action: onDismiss)
                .font(.caption)
                .foregroundColor(.neutral60)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    // MARK: Success

    private func successState(requestId: String) -> some View {
        // The sheet is presented above the NavigationStack, so we can't
        // push a NavigationLink directly from in here — it would be lost
        // when the sheet dismisses. Instead we broadcast the route via
        // `.deepLinkRouteRequested` (the same notification the FCM
        // handler uses) after dismissing. Root navigators that listen
        // will push onto the active stack.
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.largeTitle)
                .foregroundColor(.success40)

            Text(viewModel.cashShortageAlreadyOpen
                 ? "You've already sent a request — we'll ping you when they reply."
                 : "Sent! We'll let you know when they reply.")
                .font(.title3.bold())
                .foregroundColor(.white)

            Text(String(localized: "booking_cash_unavailable_confirmation"))
                .font(.subheadline)
                .foregroundColor(.neutral60)

            Button {
                NotificationCenter.default.post(
                    name: .deepLinkRouteRequested,
                    object: nil,
                    userInfo: ["route": AppRoute.clientCashRequest(requestId: requestId)]
                )
                onDismiss()
            } label: {
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                    Text(String(localized: "booking_cash_unavailable_view_conversation"))
                        .font(.body.bold())
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.turquoise60)
                )
            }
            .buttonStyle(.plain)

            Button(String(localized: "action_done"), action: onDismiss)
                .font(.body.bold())
                .foregroundColor(.neutral60)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
    }

    // MARK: Actions

    private func sendNotify() async {
        isSubmitting = true
        defer { isSubmitting = false }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        await viewModel.submitCashShortageNotify(message: trimmed.isEmpty ? nil : trimmed)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BookingFlowScreen()
    }
    .preferredColorScheme(.dark)
}
