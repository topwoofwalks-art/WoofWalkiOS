import SwiftUI
import FirebaseAuth
import FirebaseFirestore

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
        String(format: "$%.2f", basePrice)
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
    @Published var instructions = BookingInstructionsData()
    @Published var priceBreakdown = BookingPriceBreakdown()
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var bookingCreatedId: String?
    @Published var isSearchingProviders = false

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
            return selectedTimeSlot != nil && isDateTimeValid
        case .addDetails:
            return true // Details are optional
        case .reviewConfirm:
            return selectedService != nil &&
                   !selectedDogIds.isEmpty &&
                   selectedProvider != nil &&
                   selectedTimeSlot != nil
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

    var selectedDateTime: Date? {
        guard let slot = selectedTimeSlot else { return nil }
        var components = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
        components.hour = slot.hour
        components.minute = slot.minute
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

        if next == .reviewConfirm {
            calculatePrice()
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

        let basePrice = provider.basePrice
        let extraDogsFee = selectedDogIds.count > 1 ? Double(selectedDogIds.count - 1) * 5.0 : 0.0
        let defaultDuration = service.defaultDuration
        let durationAdjustment: Double = defaultDuration > 60
            ? Double(defaultDuration - 60) / 30.0 * 5.0
            : 0.0
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
        let durationMinutes = service.defaultDuration
        let endTime = Calendar.current.date(byAdding: .minute, value: durationMinutes, to: dateTime) ?? dateTime

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

        Task {
            do {
                let bookingId = try await bookingRepo.createBooking(booking)
                await MainActor.run {
                    self.isLoading = false
                    self.bookingCreatedId = bookingId
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Main Booking Flow Screen

struct BookingFlowScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = BookingFlowViewModel()
    @State private var showSuccessAlert = false

    var preselectedService: ServiceType?

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
        }
        .onChange(of: viewModel.bookingCreatedId) { _, newId in
            if newId != nil {
                showSuccessAlert = true
            }
        }
        .alert("Booking Confirmed!", isPresented: $showSuccessAlert) {
            Button("Done") {
                dismiss()
            }
        } message: {
            Text("Your booking has been submitted. The provider will confirm shortly.")
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
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
                    Text("Back")
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
                Text("Next")
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
                Text("What service do you need?")
                    .font(.title3.bold())
                    .foregroundColor(.white)

                Text("Choose the type of care for your dog.")
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
                Text("Which dogs?")
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

            Text("No dogs found")
                .font(.headline)
                .foregroundColor(.white)

            Text("Add a dog to your profile first.")
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
                Text("Choose a provider")
                    .font(.title3.bold())
                    .foregroundColor(.white)

                Text("Select a provider near you.")
                    .font(.subheadline)
                    .foregroundColor(.neutral60)

                if viewModel.isSearchingProviders {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                        Text("Searching nearby providers...")
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

            Text("No providers found")
                .font(.headline)
                .foregroundColor(.white)

            Text("Try a different service or check back later.")
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
            viewModel.selectedProvider = provider
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
                        Text("base")
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
                Text("Pick a date & time")
                    .font(.title3.bold())
                    .foregroundColor(.white)

                Text("Bookings require at least 24 hours lead time.")
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
                        Text("Selected time must be at least 24 hours from now.")
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
            .padding(16)
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
                Text("Additional details")
                    .font(.title3.bold())
                    .foregroundColor(.white)

                Text("Optional notes for your provider.")
                    .font(.subheadline)
                    .foregroundColor(.neutral60)

                detailField(
                    label: "Special Instructions",
                    icon: "text.bubble",
                    placeholder: "Any special requests or care instructions...",
                    text: $viewModel.instructions.specialInstructions
                )

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
            .padding(16)
        }
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
                Text("Review your booking")
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

                // Date & Time summary
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
                            Text("Confirm Booking")
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

    private var priceBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Price Breakdown", systemImage: "dollarsign.circle")
                .font(.subheadline.bold())
                .foregroundColor(.neutral60)

            VStack(spacing: 8) {
                priceRow("Base price", viewModel.priceBreakdown.basePrice)

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
                    Text("Total")
                        .font(.body.bold())
                        .foregroundColor(.white)
                    Spacer()
                    Text(String(format: "$%.2f", viewModel.priceBreakdown.total))
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
            Text(String(format: "$%.2f", amount))
                .font(.subheadline)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Color Extension for neutral15 (if not already defined elsewhere)

private extension Color {
    static let bookingNeutral15 = Color(hex: 0x1A1A2E)
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BookingFlowScreen()
    }
    .preferredColorScheme(.dark)
}
