import SwiftUI

struct MedicationFormView: View {
    @Binding var medication: MedicationScheduleEntry

    private var frequencyDays: Int? {
        MedicationSchedulerService.frequencyToDays(medication.frequency, customDays: medication.customFrequencyDays)
    }

    private var isOverdue: Bool {
        guard let days = frequencyDays else { return false }
        return MedicationSchedulerService.isLateDose(lastAdministeredMs: medication.lastAdministered, frequency: days)
    }

    private var daysLateCount: Int {
        guard let days = frequencyDays else { return 0 }
        return MedicationSchedulerService.daysLate(lastAdministeredMs: medication.lastAdministered, frequency: days)
    }

    var body: some View {
        Form {
            Section("Medication") {
                TextField("Name", text: $medication.name)
                Picker("Category", selection: $medication.category) {
                    ForEach(MedicationScheduleEntry.categoryOptions, id: \.self) { cat in
                        Text(cat).tag(cat)
                    }
                }
                .onChange(of: medication.category) { newCategory in
                    if !newCategory.isEmpty {
                        medication.frequency = MedicationSchedulerService.defaultFrequency(for: newCategory)
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

            Section {
                Picker("Frequency", selection: $medication.frequency) {
                    ForEach(MedicationScheduleEntry.frequencyOptions, id: \.self) { freq in
                        Text(freq.replacingOccurrences(of: "_", with: " ").capitalized).tag(freq)
                    }
                }

                if medication.frequency == "custom" {
                    HStack {
                        Text("Every")
                        TextField("days", value: Binding(
                            get: { medication.customFrequencyDays ?? 30 },
                            set: { medication.customFrequencyDays = $0 }
                        ), format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .frame(width: 60)
                        Text("days")
                            .foregroundColor(.secondary)
                    }
                }

                Toggle("Active", isOn: $medication.isActive)
                Toggle("Reminders", isOn: $medication.remindersEnabled)
            } header: {
                HStack {
                    Text("Schedule")
                    Spacer()
                    if !medication.category.isEmpty, let days = frequencyDays {
                        Text("Default: \(days)d")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Next dose countdown
            if let days = frequencyDays {
                Section("Next Dose") {
                    HStack {
                        Label {
                            Text(MedicationSchedulerService.countdownLabel(
                                lastAdministeredMs: medication.lastAdministered,
                                frequency: days
                            ))
                        } icon: {
                            Image(systemName: isOverdue ? "exclamationmark.triangle.fill" : "calendar.badge.clock")
                                .foregroundColor(isOverdue ? .red : .turquoise60)
                        }

                        Spacer()

                        if isOverdue {
                            Text("Late!")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.red))
                        }
                    }

                    if isOverdue && !medication.category.isEmpty {
                        Text(MedicationSchedulerService.lateMessage(for: medication.category, daysLate: daysLateCount))
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    if medication.lastAdministered != nil {
                        Button {
                            medication.lastAdministered = Int64(Date().timeIntervalSince1970 * 1000)
                            if let freq = frequencyDays {
                                medication.nextDueDate = Int64(
                                    MedicationSchedulerService.nextDueDate(
                                        lastAdministered: Date(), frequency: freq
                                    ).timeIntervalSince1970 * 1000
                                )
                            }
                        } label: {
                            Label("Record Dose Given Now", systemImage: "checkmark.circle")
                        }
                    } else {
                        Button {
                            medication.lastAdministered = Int64(Date().timeIntervalSince1970 * 1000)
                            if let freq = frequencyDays {
                                medication.nextDueDate = Int64(
                                    MedicationSchedulerService.nextDueDate(
                                        lastAdministered: Date(), frequency: freq
                                    ).timeIntervalSince1970 * 1000
                                )
                            }
                        } label: {
                            Label("Record First Dose", systemImage: "plus.circle")
                        }
                    }
                }
            }

            // Dose history
            if medication.lastAdministered != nil {
                Section("Dose History") {
                    doseHistoryRow(label: "Last administered", timestampMs: medication.lastAdministered)

                    if let nextMs = medication.nextDueDate {
                        doseHistoryRow(label: "Next due", timestampMs: nextMs)
                    }

                    if let startMs = medication.startDate {
                        doseHistoryRow(label: "Started", timestampMs: startMs)
                    }
                }
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
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var navigationTitle: String {
        if medication.name.isEmpty {
            return "New Medication"
        }
        if isOverdue {
            return "\(medication.name) (Overdue)"
        }
        return medication.name
    }

    @ViewBuilder
    private func doseHistoryRow(label: String, timestampMs: Int64?) -> some View {
        if let ms = timestampMs {
            let date = Date(timeIntervalSince1970: Double(ms) / 1000.0)
            HStack {
                Text(label)
                    .foregroundColor(.secondary)
                Spacer()
                Text(date, style: .date)
                    .font(.subheadline)
            }
        }
    }
}
