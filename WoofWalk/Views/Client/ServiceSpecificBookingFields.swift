import SwiftUI

// MARK: - Service-Specific Booking Details Model

/// Sealed-class-style hierarchy for service-specific booking data,
/// matching Android's ServiceSpecificDetails sealed class.
enum ServiceSpecificDetails {
    case walk(WalkBookingDetails)
    case grooming(GroomingBookingDetails)
    case sitting(SittingBookingDetails)
    case boarding(BoardingBookingDetails)
    case daycare(DaycareBookingDetails)
    case training(TrainingBookingDetails)

    /// Factory: create default details for a given service type.
    static func defaultFor(_ serviceType: BookingServiceType) -> ServiceSpecificDetails {
        switch serviceType {
        case .walk:      return .walk(WalkBookingDetails())
        case .grooming:  return .grooming(GroomingBookingDetails())
        case .inSitting, .outSitting, .petSitting:
                         return .sitting(SittingBookingDetails())
        case .boarding:  return .boarding(BoardingBookingDetails())
        case .daycare:   return .daycare(DaycareBookingDetails())
        case .training:  return .training(TrainingBookingDetails())
        case .meetGreet: return .walk(WalkBookingDetails())
        }
    }
}

struct WalkBookingDetails {
    var pickupLocation: String = ""
    var walkPace: String = "Moderate"
    var routePreference: String = "No preference"
    var durationMinutes: Int = 30
}

struct GroomingBookingDetails {
    var groomType: String = "Full Groom"
    var coatCondition: String = "Good"
    var additionalServices: Set<String> = []
    var handlingNotes: String = ""
    var durationMinutes: Int = 60
}

struct SittingBookingDetails {
    var checkIn: Date = Date()
    var checkOut: Date = Date()
    var accessMethod: String = "Will Be Home"
    var accessNotes: String = ""
    var feedingMorningTime: String = ""
    var feedingEveningTime: String = ""
    var foodLocation: String = ""
    var amountPerMeal: String = ""
    var medicationName: String = ""
    var medicationTime: String = ""
    var medicationDosage: String = ""
    var medicationInstructions: String = ""
    var houseRules: String = ""
    var emergencyAuth: Bool = false
}

struct BoardingBookingDetails {
    var checkInDate: Date = Date()
    var checkOutDate: Date = Date()
    var roomType: String = "Standard"
    var mealsPerDay: Int = 2
    var foodProvidedBy: String = "Owner"
    var dietaryRestrictions: String = ""
    var exercisePreference: String = "Moderate"
    var separationAnxiety: Bool = false
    var crateTrained: Bool = false
    var goodWithOtherDogs: Bool = false
    var vaccinationVerified: Bool = false
}

struct DaycareBookingDetails {
    var dropOffTime: String = ""
    var pickUpTime: String = ""
    var activityPreference: String = "Balanced"
    var socialization: String = "Loves other dogs"
    var weeklyDays: Set<String> = []
    var bringOwnFood: Bool = false
}

struct TrainingBookingDetails {
    var focusAreas: Set<String> = []
    var currentLevel: String = "No Training"
    var methodPreference: String = "No Preference"
    var goals: String = ""
    var sessionType: String = "Private 1-on-1"
}

// MARK: - Dispatcher View

/// Renders the correct service-specific booking fields based on the current details.
struct ServiceSpecificBookingFieldsView: View {
    @Binding var details: ServiceSpecificDetails

    var body: some View {
        switch details {
        case .walk(let d):
            WalkSpecificFields(details: d) { updated in
                details = .walk(updated)
            }
        case .grooming(let d):
            GroomingSpecificFields(details: d) { updated in
                details = .grooming(updated)
            }
        case .sitting(let d):
            SittingSpecificFields(details: d) { updated in
                details = .sitting(updated)
            }
        case .boarding(let d):
            BoardingSpecificFields(details: d) { updated in
                details = .boarding(updated)
            }
        case .daycare(let d):
            DaycareSpecificFields(details: d) { updated in
                details = .daycare(updated)
            }
        case .training(let d):
            TrainingSpecificFields(details: d) { updated in
                details = .training(updated)
            }
        }
    }
}

// MARK: - Shared Helpers

private struct SectionCardView<Content: View>: View {
    let title: String
    let icon: String
    let content: () -> Content

    init(title: String, icon: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(AppColors.Dark.primary)
                    .frame(width: 20)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.Dark.onSurface)
            }

            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.Dark.surfaceVariant.opacity(0.35))
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}

private struct FieldLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(AppColors.Dark.onSurfaceVariant)
            .padding(.bottom, 4)
    }
}

private struct SingleSelectChipsView: View {
    let options: [String]
    let selected: String
    let onSelected: (String) -> Void

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selected
                Button {
                    onSelected(option)
                } label: {
                    HStack(spacing: 4) {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.caption2)
                        }
                        Text(option)
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(isSelected ? AppColors.Dark.primaryContainer : AppColors.Dark.surfaceVariant)
                    )
                    .foregroundColor(isSelected ? AppColors.Dark.onPrimaryContainer : AppColors.Dark.onSurfaceVariant)
                }
            }
        }
    }
}

private struct MultiSelectChipsView: View {
    let options: [String]
    let selected: Set<String>
    let onToggle: (String) -> Void

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(options, id: \.self) { option in
                let isSelected = selected.contains(option)
                Button {
                    onToggle(option)
                } label: {
                    HStack(spacing: 4) {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.caption2)
                        }
                        Text(option)
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(isSelected ? AppColors.Dark.primaryContainer : AppColors.Dark.surfaceVariant)
                    )
                    .foregroundColor(isSelected ? AppColors.Dark.onPrimaryContainer : AppColors.Dark.onSurfaceVariant)
                }
            }
        }
    }
}

private struct RadioGroup: View {
    let options: [String]
    let selected: String
    let onSelected: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(options, id: \.self) { option in
                Button {
                    onSelected(option)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: option == selected ? "largecircle.fill.circle" : "circle")
                            .font(.body)
                            .foregroundColor(option == selected ? AppColors.Dark.primary : AppColors.Dark.onSurfaceVariant)
                        Text(option)
                            .font(.subheadline)
                            .foregroundColor(AppColors.Dark.onSurface)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

private struct CheckboxRow: View {
    let label: String
    @Binding var isChecked: Bool

    var body: some View {
        Button {
            isChecked.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .foregroundColor(isChecked ? AppColors.Dark.primary : AppColors.Dark.onSurfaceVariant)
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(AppColors.Dark.onSurface)
            }
            .padding(.vertical, 2)
        }
    }
}

/// Simple flow layout for chips
private struct FlowLayout: Layout {
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

// MARK: - 1. Walk-Specific Fields

private struct WalkSpecificFields: View {
    let details: WalkBookingDetails
    let onUpdate: (WalkBookingDetails) -> Void

    var body: some View {
        SectionCardView(title: "Walk Details", icon: "figure.walk") {
            FieldLabel(text: "Pickup location")
            TextField("Address or landmark", text: binding(\.pickupLocation))
                .textFieldStyle(.roundedBorder)

            FieldLabel(text: "Walk pace")
            SingleSelectChipsView(
                options: ["Leisurely", "Moderate", "Brisk"],
                selected: details.walkPace,
                onSelected: { onUpdate(mutating { $0.walkPace = $1 }, $0) }
            )

            FieldLabel(text: "Route preference")
            SingleSelectChipsView(
                options: ["Park", "Residential", "Trail", "No preference"],
                selected: details.routePreference,
                onSelected: { onUpdate(mutating { $0.routePreference = $1 }, $0) }
            )

            FieldLabel(text: "Duration")
            SingleSelectChipsView(
                options: ["15 min", "30 min", "45 min", "60 min"],
                selected: durationLabel,
                onSelected: { label in
                    let mins = Int(label.replacingOccurrences(of: " min", with: "")) ?? 30
                    var d = details
                    d.durationMinutes = mins
                    onUpdate(d)
                }
            )
        }
    }

    private var durationLabel: String {
        "\(details.durationMinutes) min"
    }

    private func binding(_ keyPath: WritableKeyPath<WalkBookingDetails, String>) -> Binding<String> {
        Binding(
            get: { details[keyPath: keyPath] },
            set: { val in
                var d = details
                d[keyPath: keyPath] = val
                onUpdate(d)
            }
        )
    }

    private func mutating(_ transform: (inout WalkBookingDetails, String) -> Void, _ value: String) -> WalkBookingDetails {
        var d = details
        transform(&d, value)
        return d
    }
}

// MARK: - 2. Grooming-Specific Fields

private struct GroomingSpecificFields: View {
    let details: GroomingBookingDetails
    let onUpdate: (GroomingBookingDetails) -> Void

    var body: some View {
        SectionCardView(title: "Grooming Details", icon: "scissors") {
            FieldLabel(text: "Groom type")
            SingleSelectChipsView(
                options: ["Bath Only", "Full Groom", "Puppy Introduction", "Nail Trim", "Deluxe Package"],
                selected: details.groomType,
                onSelected: { type in
                    var d = details; d.groomType = type; onUpdate(d)
                }
            )

            FieldLabel(text: "Coat condition")
            SingleSelectChipsView(
                options: ["Good", "Matted", "Heavily Matted"],
                selected: details.coatCondition,
                onSelected: { val in
                    var d = details; d.coatCondition = val; onUpdate(d)
                }
            )

            FieldLabel(text: "Additional services")
            let additionalOptions = ["Nail Trim", "Ear Clean", "Teeth Brush", "Anal Glands"]
            ForEach(additionalOptions, id: \.self) { service in
                checkboxRow(service)
            }

            FieldLabel(text: "Special handling notes")
            TextField("Sensitive areas, behaviour notes, etc.", text: stringBinding(\.handlingNotes), axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)

            FieldLabel(text: "Estimated duration")
            SingleSelectChipsView(
                options: ["1 hr", "1.5 hrs", "2 hrs", "3 hrs", "4 hrs"],
                selected: durationLabel,
                onSelected: { label in
                    let mins: Int
                    switch label {
                    case "1 hr": mins = 60
                    case "1.5 hrs": mins = 90
                    case "2 hrs": mins = 120
                    case "3 hrs": mins = 180
                    case "4 hrs": mins = 240
                    default: mins = 60
                    }
                    var d = details; d.durationMinutes = mins; onUpdate(d)
                }
            )
        }
    }

    private var durationLabel: String {
        switch details.durationMinutes {
        case 60: return "1 hr"
        case 90: return "1.5 hrs"
        case 120: return "2 hrs"
        case 180: return "3 hrs"
        case 240: return "4 hrs"
        default: return "1 hr"
        }
    }

    private func checkboxRow(_ service: String) -> some View {
        Button {
            var d = details
            if d.additionalServices.contains(service) {
                d.additionalServices.remove(service)
            } else {
                d.additionalServices.insert(service)
            }
            onUpdate(d)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: details.additionalServices.contains(service) ? "checkmark.square.fill" : "square")
                    .foregroundColor(details.additionalServices.contains(service) ? AppColors.Dark.primary : AppColors.Dark.onSurfaceVariant)
                Text(service)
                    .font(.subheadline)
                    .foregroundColor(AppColors.Dark.onSurface)
            }
            .padding(.vertical, 2)
        }
    }

    private func stringBinding(_ keyPath: WritableKeyPath<GroomingBookingDetails, String>) -> Binding<String> {
        Binding(
            get: { details[keyPath: keyPath] },
            set: { val in var d = details; d[keyPath: keyPath] = val; onUpdate(d) }
        )
    }
}

// MARK: - 3. Sitting-Specific Fields

private struct SittingSpecificFields: View {
    let details: SittingBookingDetails
    let onUpdate: (SittingBookingDetails) -> Void

    var body: some View {
        SectionCardView(title: "In-Home Sitting Details", icon: "house.fill") {
            FieldLabel(text: "Check-in")
            DatePicker("Check-in", selection: dateBinding(\.checkIn), displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()

            FieldLabel(text: "Check-out")
            DatePicker("Check-out", selection: dateBinding(\.checkOut), displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()

            Divider()

            FieldLabel(text: "Access method")
            let accessOptions = ["Key Under Mat", "Lockbox Code", "Will Be Home", "Other"]
            Picker("Access method", selection: stringBinding(\.accessMethod)) {
                ForEach(accessOptions, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)

            if details.accessMethod == "Lockbox Code" || details.accessMethod == "Other" {
                TextField(
                    details.accessMethod == "Lockbox Code" ? "Enter lockbox code" : "Describe access method",
                    text: stringBinding(\.accessNotes)
                )
                .textFieldStyle(.roundedBorder)
            }

            Divider()

            FieldLabel(text: "Feeding schedule")
            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text("Morning feed").font(.caption).foregroundColor(AppColors.Dark.onSurfaceVariant)
                    TextField("e.g. 8am", text: stringBinding(\.feedingMorningTime))
                        .textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading) {
                    Text("Evening feed").font(.caption).foregroundColor(AppColors.Dark.onSurfaceVariant)
                    TextField("e.g. 6pm", text: stringBinding(\.feedingEveningTime))
                        .textFieldStyle(.roundedBorder)
                }
            }

            TextField("Food location (e.g. Kitchen cupboard)", text: stringBinding(\.foodLocation))
                .textFieldStyle(.roundedBorder)

            TextField("Amount per meal (e.g. 1 cup dry food)", text: stringBinding(\.amountPerMeal))
                .textFieldStyle(.roundedBorder)

            Divider()

            FieldLabel(text: "Medication (if applicable)")
            TextField("Medication name", text: stringBinding(\.medicationName))
                .textFieldStyle(.roundedBorder)

            if !details.medicationName.trimmingCharacters(in: .whitespaces).isEmpty {
                HStack(spacing: 12) {
                    TextField("Time (e.g. 8am)", text: stringBinding(\.medicationTime))
                        .textFieldStyle(.roundedBorder)
                    TextField("Dosage (e.g. 1 tablet)", text: stringBinding(\.medicationDosage))
                        .textFieldStyle(.roundedBorder)
                }
                TextField("Instructions (e.g. Give with food)", text: stringBinding(\.medicationInstructions), axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...3)
            }

            Divider()

            FieldLabel(text: "House rules")
            TextField("Allowed rooms, off-limits areas, garden access, etc.", text: stringBinding(\.houseRules), axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)

            Toggle(isOn: boolBinding(\.emergencyAuth)) {
                Text("I authorise emergency veterinary treatment if required")
                    .font(.subheadline)
                    .foregroundColor(AppColors.Dark.onSurface)
            }
            .tint(AppColors.Dark.primary)
        }
    }

    private func stringBinding(_ keyPath: WritableKeyPath<SittingBookingDetails, String>) -> Binding<String> {
        Binding(
            get: { details[keyPath: keyPath] },
            set: { val in var d = details; d[keyPath: keyPath] = val; onUpdate(d) }
        )
    }

    private func dateBinding(_ keyPath: WritableKeyPath<SittingBookingDetails, Date>) -> Binding<Date> {
        Binding(
            get: { details[keyPath: keyPath] },
            set: { val in var d = details; d[keyPath: keyPath] = val; onUpdate(d) }
        )
    }

    private func boolBinding(_ keyPath: WritableKeyPath<SittingBookingDetails, Bool>) -> Binding<Bool> {
        Binding(
            get: { details[keyPath: keyPath] },
            set: { val in var d = details; d[keyPath: keyPath] = val; onUpdate(d) }
        )
    }
}

// MARK: - 4. Boarding-Specific Fields

private struct BoardingSpecificFields: View {
    let details: BoardingBookingDetails
    let onUpdate: (BoardingBookingDetails) -> Void

    var body: some View {
        SectionCardView(title: "Boarding Details", icon: "bed.double.fill") {
            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text("Check-in").font(.caption).foregroundColor(AppColors.Dark.onSurfaceVariant)
                    DatePicker("", selection: dateBinding(\.checkInDate), displayedComponents: .date)
                        .labelsHidden()
                }
                VStack(alignment: .leading) {
                    Text("Check-out").font(.caption).foregroundColor(AppColors.Dark.onSurfaceVariant)
                    DatePicker("", selection: dateBinding(\.checkOutDate), displayedComponents: .date)
                        .labelsHidden()
                }
            }

            FieldLabel(text: "Room type")
            SingleSelectChipsView(
                options: ["Standard", "Deluxe", "Suite", "Shared"],
                selected: details.roomType,
                onSelected: { val in var d = details; d.roomType = val; onUpdate(d) }
            )

            Divider()

            FieldLabel(text: "Meals per day")
            SingleSelectChipsView(
                options: ["1", "2", "3"],
                selected: "\(details.mealsPerDay)",
                onSelected: { val in var d = details; d.mealsPerDay = Int(val) ?? 2; onUpdate(d) }
            )

            FieldLabel(text: "Food provided by")
            SingleSelectChipsView(
                options: ["Owner", "Facility"],
                selected: details.foodProvidedBy,
                onSelected: { val in var d = details; d.foodProvidedBy = val; onUpdate(d) }
            )

            TextField("Dietary restrictions / allergies", text: stringBinding(\.dietaryRestrictions))
                .textFieldStyle(.roundedBorder)

            Divider()

            FieldLabel(text: "Exercise preference")
            SingleSelectChipsView(
                options: ["Low", "Moderate", "High"],
                selected: details.exercisePreference,
                onSelected: { val in var d = details; d.exercisePreference = val; onUpdate(d) }
            )

            Divider()

            FieldLabel(text: "Behaviour notes")
            toggleRow("Separation anxiety", binding: boolBinding(\.separationAnxiety))
            toggleRow("Crate trained", binding: boolBinding(\.crateTrained))
            toggleRow("Good with other dogs", binding: boolBinding(\.goodWithOtherDogs))

            toggleRow("Vaccination records verified", binding: boolBinding(\.vaccinationVerified))
        }
    }

    private func toggleRow(_ label: String, binding: Binding<Bool>) -> some View {
        Button {
            binding.wrappedValue.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: binding.wrappedValue ? "checkmark.square.fill" : "square")
                    .foregroundColor(binding.wrappedValue ? AppColors.Dark.primary : AppColors.Dark.onSurfaceVariant)
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(AppColors.Dark.onSurface)
            }
            .padding(.vertical, 2)
        }
    }

    private func stringBinding(_ keyPath: WritableKeyPath<BoardingBookingDetails, String>) -> Binding<String> {
        Binding(
            get: { details[keyPath: keyPath] },
            set: { val in var d = details; d[keyPath: keyPath] = val; onUpdate(d) }
        )
    }

    private func dateBinding(_ keyPath: WritableKeyPath<BoardingBookingDetails, Date>) -> Binding<Date> {
        Binding(
            get: { details[keyPath: keyPath] },
            set: { val in var d = details; d[keyPath: keyPath] = val; onUpdate(d) }
        )
    }

    private func boolBinding(_ keyPath: WritableKeyPath<BoardingBookingDetails, Bool>) -> Binding<Bool> {
        Binding(
            get: { details[keyPath: keyPath] },
            set: { val in var d = details; d[keyPath: keyPath] = val; onUpdate(d) }
        )
    }
}

// MARK: - 5. Daycare-Specific Fields

private struct DaycareSpecificFields: View {
    let details: DaycareBookingDetails
    let onUpdate: (DaycareBookingDetails) -> Void

    var body: some View {
        SectionCardView(title: "Daycare Details", icon: "sun.and.horizon.fill") {
            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text("Drop-off time").font(.caption).foregroundColor(AppColors.Dark.onSurfaceVariant)
                    TextField("e.g. 8:00 AM", text: stringBinding(\.dropOffTime))
                        .textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading) {
                    Text("Pickup time").font(.caption).foregroundColor(AppColors.Dark.onSurfaceVariant)
                    TextField("e.g. 5:00 PM", text: stringBinding(\.pickUpTime))
                        .textFieldStyle(.roundedBorder)
                }
            }

            FieldLabel(text: "Activity preference")
            SingleSelectChipsView(
                options: ["Play-focused", "Balanced", "Rest-focused"],
                selected: details.activityPreference,
                onSelected: { val in var d = details; d.activityPreference = val; onUpdate(d) }
            )

            FieldLabel(text: "Socialisation")
            SingleSelectChipsView(
                options: ["Loves other dogs", "Selective", "Prefers solo"],
                selected: details.socialization,
                onSelected: { val in var d = details; d.socialization = val; onUpdate(d) }
            )

            Divider()

            FieldLabel(text: "Recurring schedule")
            let days = ["Mon", "Tue", "Wed", "Thu", "Fri"]
            MultiSelectChipsView(
                options: days,
                selected: details.weeklyDays,
                onToggle: { day in
                    var d = details
                    if d.weeklyDays.contains(day) {
                        d.weeklyDays.remove(day)
                    } else {
                        d.weeklyDays.insert(day)
                    }
                    onUpdate(d)
                }
            )

            Toggle(isOn: boolBinding(\.bringOwnFood)) {
                Text("Bring own food")
                    .font(.subheadline)
                    .foregroundColor(AppColors.Dark.onSurface)
            }
            .tint(AppColors.Dark.primary)
        }
    }

    private func stringBinding(_ keyPath: WritableKeyPath<DaycareBookingDetails, String>) -> Binding<String> {
        Binding(
            get: { details[keyPath: keyPath] },
            set: { val in var d = details; d[keyPath: keyPath] = val; onUpdate(d) }
        )
    }

    private func boolBinding(_ keyPath: WritableKeyPath<DaycareBookingDetails, Bool>) -> Binding<Bool> {
        Binding(
            get: { details[keyPath: keyPath] },
            set: { val in var d = details; d[keyPath: keyPath] = val; onUpdate(d) }
        )
    }
}

// MARK: - 6. Training-Specific Fields

private struct TrainingSpecificFields: View {
    let details: TrainingBookingDetails
    let onUpdate: (TrainingBookingDetails) -> Void

    var body: some View {
        SectionCardView(title: "Training Details", icon: "star.fill") {
            FieldLabel(text: "Training focus")
            MultiSelectChipsView(
                options: ["Obedience", "Behaviour Modification", "Puppy Basics", "Sports", "Trick Training", "Reactivity"],
                selected: details.focusAreas,
                onToggle: { area in
                    var d = details
                    if d.focusAreas.contains(area) {
                        d.focusAreas.remove(area)
                    } else {
                        d.focusAreas.insert(area)
                    }
                    onUpdate(d)
                }
            )

            FieldLabel(text: "Dog's current level")
            RadioGroup(
                options: ["No Training", "Basic Commands", "Intermediate", "Advanced"],
                selected: details.currentLevel,
                onSelected: { val in var d = details; d.currentLevel = val; onUpdate(d) }
            )

            FieldLabel(text: "Training method preference")
            RadioGroup(
                options: ["Positive Reinforcement", "Balanced", "No Preference"],
                selected: details.methodPreference,
                onSelected: { val in var d = details; d.methodPreference = val; onUpdate(d) }
            )

            FieldLabel(text: "Specific goals")
            TextField("e.g. Stop jumping on visitors, recall in the park", text: stringBinding(\.goals), axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)

            FieldLabel(text: "Session type")
            SingleSelectChipsView(
                options: ["Private 1-on-1", "Small Group", "Board & Train"],
                selected: details.sessionType,
                onSelected: { val in var d = details; d.sessionType = val; onUpdate(d) }
            )
        }
    }

    private func stringBinding(_ keyPath: WritableKeyPath<TrainingBookingDetails, String>) -> Binding<String> {
        Binding(
            get: { details[keyPath: keyPath] },
            set: { val in var d = details; d[keyPath: keyPath] = val; onUpdate(d) }
        )
    }
}
