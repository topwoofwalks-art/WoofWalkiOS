import SwiftUI

struct UnifiedDogFormView: View {
    @StateObject private var viewModel: UnifiedDogFormViewModel
    @Environment(\.dismiss) private var dismiss

    let isEditing: Bool
    let onSave: (DogProfile) -> Void

    // One-shot submit guard. After the first Save tap we hand a profile up
    // and dismiss; this prevents a second tap during the dismiss-animation
    // window from kicking off a duplicate add.
    @State private var hasSubmitted = false

    // Collapsible section state
    @State private var showPhysical = true
    @State private var showBehavior = true
    @State private var showMedical = true
    @State private var showMedications = true
    @State private var showVet = false

    init(dog: DogProfile? = nil, onSave: @escaping (DogProfile) -> Void) {
        self.isEditing = dog != nil
        self.onSave = onSave
        _viewModel = StateObject(wrappedValue: UnifiedDogFormViewModel(dog: dog))
    }

    var body: some View {
        NavigationView {
            Form {
                basicInfoSection
                collapsiblePhysicalSection
                collapsibleBehaviorSection
                collapsibleMedicalSection
                collapsibleMedicationsSection
                collapsibleVetSection
            }
            .navigationTitle(isEditing ? "Edit Dog" : "Add Dog")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard !hasSubmitted else { return }
                        hasSubmitted = true
                        onSave(viewModel.toDogProfile())
                        dismiss()
                    }
                    .disabled(viewModel.name.isEmpty || hasSubmitted)
                }
            }
        }
    }

    // MARK: - Basic Info (always expanded)
    private var basicInfoSection: some View {
        Section("Basic Info") {
            // Photo placeholder with dashed border
            if viewModel.name.isEmpty || true { // Always show photo area for now
                photoPlaceholder
            }

            TextField("Name", text: $viewModel.name)
            BreedAutocomplete(selectedBreed: $viewModel.breed)

            DOBPicker(selectedDate: $viewModel.birthdate, label: "Date of Birth")

            Picker("Sex", selection: $viewModel.sex) {
                Text("Not specified").tag("")
                Text("Male").tag("Male")
                Text("Female").tag("Female")
            }

            Toggle("Neutered/Spayed", isOn: $viewModel.neutered)

            TextField("Color", text: $viewModel.color)
        }
    }

    // MARK: - Photo Placeholder
    private var photoPlaceholder: some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                    .foregroundColor(.secondary.opacity(0.4))
                    .frame(height: 120)

                VStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                        .font(.title2)
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("Add Photo")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    // MARK: - Physical (collapsible)
    private var collapsiblePhysicalSection: some View {
        Section {
            DisclosureGroup(isExpanded: $showPhysical) {
                Picker("Size", selection: $viewModel.size) {
                    Text("Not specified").tag("")
                    Text("Small").tag("Small")
                    Text("Medium").tag("Medium")
                    Text("Large").tag("Large")
                    Text("Extra Large").tag("Extra Large")
                }

                HStack {
                    Text("Weight")
                    Spacer()
                    TextField("kg", value: $viewModel.weight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("kg")
                        .foregroundColor(.secondary)
                }

                TextField("Microchip ID", text: $viewModel.microchipId)
            } label: {
                Label("Physical", systemImage: "ruler")
                    .font(.headline)
            }
        }
    }

    // MARK: - Behavior (collapsible)
    private var collapsibleBehaviorSection: some View {
        Section {
            DisclosureGroup(isExpanded: $showBehavior) {
                Picker("Temperament", selection: $viewModel.temperament) {
                    Text("Friendly").tag("Friendly")
                    Text("Calm").tag("Calm")
                    Text("Energetic").tag("Energetic")
                    Text("Shy").tag("Shy")
                    Text("Protective").tag("Protective")
                    Text("Anxious").tag("Anxious")
                }

                Toggle("Nervous/Reactive Dog", isOn: $viewModel.nervousDog)

                if viewModel.nervousDog {
                    TextField("Warning Note", text: $viewModel.warningNote, axis: .vertical)
                        .lineLimit(2...4)
                }

                TextField("Behavioral Notes", text: $viewModel.behavioralNotes, axis: .vertical)
                    .lineLimit(2...4)
            } label: {
                Label("Behavior", systemImage: "pawprint")
                    .font(.headline)
            }
        }
    }

    // MARK: - Medical (collapsible)
    private var collapsibleMedicalSection: some View {
        Section {
            DisclosureGroup(isExpanded: $showMedical) {
                TextField("Allergies", text: $viewModel.allergies)
                TextField("Medical Conditions", text: $viewModel.medicalConditions)
                TextField("Special Needs", text: $viewModel.specialNeeds)
                TextField("Dietary Restrictions", text: $viewModel.dietaryRestrictions)
            } label: {
                Label("Medical", systemImage: "cross.case")
                    .font(.headline)
            }
        }
    }

    // MARK: - Medications (collapsible)
    private var collapsibleMedicationsSection: some View {
        Section {
            DisclosureGroup(isExpanded: $showMedications) {
                ForEach($viewModel.medicationSchedules) { $med in
                    NavigationLink {
                        MedicationFormView(medication: $med)
                    } label: {
                        medicationRow(med)
                    }
                }
                .onDelete { viewModel.medicationSchedules.remove(atOffsets: $0) }

                Button(action: { viewModel.addMedication() }) {
                    Label("Add Medication", systemImage: "plus.circle")
                }
            } label: {
                HStack {
                    Label("Medications", systemImage: "pills")
                        .font(.headline)
                    Spacer()
                    if overdueCount > 0 {
                        Text("\(overdueCount) overdue")
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.red))
                    }
                }
            }
        }
    }

    private func medicationRow(_ med: MedicationScheduleEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(med.name.isEmpty ? "New Medication" : med.name)
                    .font(.subheadline)

                if let days = MedicationSchedulerService.frequencyToDays(med.frequency, customDays: med.customFrequencyDays) {
                    Text(MedicationSchedulerService.countdownLabel(lastAdministeredMs: med.lastAdministered, frequency: days))
                        .font(.caption)
                        .foregroundColor(isMedOverdue(med) ? .red : .secondary)
                } else {
                    Text(med.frequency.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()

            if isMedOverdue(med) {
                Text("Late!")
                    .font(.caption2.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.red))
            } else if med.isActive {
                Circle().fill(Color.green).frame(width: 8, height: 8)
            }
        }
    }

    private func isMedOverdue(_ med: MedicationScheduleEntry) -> Bool {
        guard let days = MedicationSchedulerService.frequencyToDays(med.frequency, customDays: med.customFrequencyDays) else { return false }
        return MedicationSchedulerService.isLateDose(lastAdministeredMs: med.lastAdministered, frequency: days)
    }

    private var overdueCount: Int {
        viewModel.medicationSchedules.filter { isMedOverdue($0) }.count
    }

    // MARK: - Vet (collapsible, collapsed by default)
    private var collapsibleVetSection: some View {
        Section {
            DisclosureGroup(isExpanded: $showVet) {
                TextField("Practice Name", text: $viewModel.vetPracticeName)
                TextField("Vet Name", text: $viewModel.vetName)
                TextField("Phone", text: $viewModel.vetPhone)
                    .keyboardType(.phonePad)
                TextField("Address", text: $viewModel.vetAddress)
            } label: {
                Label("Vet Details", systemImage: "stethoscope")
                    .font(.headline)
            }
        }
    }
}

// MARK: - DOB Picker
struct DOBPicker: View {
    @Binding var selectedDate: Date?
    let label: String
    @State private var showPicker = false
    @State private var tempDate = Date()

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Button(action: { showPicker = true }) {
                if let date = selectedDate {
                    Text(date, style: .date)
                        .foregroundColor(.primary)
                } else {
                    Text("Set")
                        .foregroundColor(.turquoise60)
                }
            }
        }
        .sheet(isPresented: $showPicker) {
            NavigationView {
                DatePicker("Date of Birth", selection: $tempDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .padding()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showPicker = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                selectedDate = tempDate
                                showPicker = false
                            }
                        }
                    }
                    .navigationTitle("Date of Birth")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}
