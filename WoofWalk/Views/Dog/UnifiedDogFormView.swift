import SwiftUI

struct UnifiedDogFormView: View {
    @StateObject private var viewModel: UnifiedDogFormViewModel
    @Environment(\.dismiss) private var dismiss

    let isEditing: Bool
    let onSave: (DogProfile) -> Void

    init(dog: DogProfile? = nil, onSave: @escaping (DogProfile) -> Void) {
        self.isEditing = dog != nil
        self.onSave = onSave
        _viewModel = StateObject(wrappedValue: UnifiedDogFormViewModel(dog: dog))
    }

    var body: some View {
        NavigationView {
            Form {
                basicInfoSection
                physicalSection
                behaviorSection
                medicalSection
                medicationsSection
                vetSection
            }
            .navigationTitle(isEditing ? "Edit Dog" : "Add Dog")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(viewModel.toDogProfile())
                        dismiss()
                    }
                    .disabled(viewModel.name.isEmpty)
                }
            }
        }
    }

    // MARK: - Basic Info
    private var basicInfoSection: some View {
        Section("Basic Info") {
            TextField("Name", text: $viewModel.name)
            TextField("Breed", text: $viewModel.breed)

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

    // MARK: - Physical
    private var physicalSection: some View {
        Section("Physical") {
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
        }
    }

    // MARK: - Behavior
    private var behaviorSection: some View {
        Section("Behavior") {
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
        }
    }

    // MARK: - Medical
    private var medicalSection: some View {
        Section("Medical") {
            TextField("Allergies", text: $viewModel.allergies)
            TextField("Medical Conditions", text: $viewModel.medicalConditions)
            TextField("Special Needs", text: $viewModel.specialNeeds)
            TextField("Dietary Restrictions", text: $viewModel.dietaryRestrictions)
        }
    }

    // MARK: - Medications
    private var medicationsSection: some View {
        Section {
            ForEach($viewModel.medicationSchedules) { $med in
                NavigationLink {
                    MedicationFormView(medication: $med)
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(med.name.isEmpty ? "New Medication" : med.name)
                                .font(.subheadline)
                            Text(med.frequency)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if med.isActive {
                            Circle().fill(Color.green).frame(width: 8, height: 8)
                        }
                    }
                }
            }
            .onDelete { viewModel.medicationSchedules.remove(atOffsets: $0) }

            Button(action: { viewModel.addMedication() }) {
                Label("Add Medication", systemImage: "plus.circle")
            }
        } header: {
            Text("Medications")
        }
    }

    // MARK: - Vet
    private var vetSection: some View {
        Section("Vet Details") {
            TextField("Practice Name", text: $viewModel.vetPracticeName)
            TextField("Vet Name", text: $viewModel.vetName)
            TextField("Phone", text: $viewModel.vetPhone)
                .keyboardType(.phonePad)
            TextField("Address", text: $viewModel.vetAddress)
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
