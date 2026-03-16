import SwiftUI

struct MedicationFormView: View {
    @Binding var medication: MedicationScheduleEntry

    var body: some View {
        Form {
            Section("Medication") {
                TextField("Name", text: $medication.name)
                Picker("Category", selection: $medication.category) {
                    ForEach(MedicationScheduleEntry.categoryOptions, id: \.self) { cat in
                        Text(cat).tag(cat)
                    }
                }
            }

            Section("Dosage") {
                HStack {
                    TextField("Amount", text: $medication.dosage)
                        .keyboardType(.decimalPad)
                    Picker("Unit", selection: $medication.dosageUnit) {
                        Text("mg").tag("mg")
                        Text("ml").tag("ml")
                        Text("tablet").tag("tablet")
                        Text("drops").tag("drops")
                    }
                }
                Toggle("With Food", isOn: $medication.withFood)
            }

            Section("Schedule") {
                Picker("Frequency", selection: $medication.frequency) {
                    ForEach(MedicationScheduleEntry.frequencyOptions, id: \.self) { freq in
                        Text(freq.replacingOccurrences(of: "_", with: " ").capitalized).tag(freq)
                    }
                }

                Toggle("Active", isOn: $medication.isActive)
                Toggle("Reminders", isOn: $medication.remindersEnabled)
            }

            Section("Provider") {
                TextField("Prescribed By", text: $medication.prescribedBy)
                TextField("Pharmacy", text: $medication.pharmacy)
            }

            Section("Notes") {
                TextField("Notes", text: $medication.notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .navigationTitle(medication.name.isEmpty ? "New Medication" : medication.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
