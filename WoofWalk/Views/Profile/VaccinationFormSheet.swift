import SwiftUI

/// Add / edit sheet for a single vaccination record on a dog.
///
/// Mirrors the Android `AddVaccinationDialog` + web portal form shipped
/// in v7.5.0:
///   - Picker of common UK vaccines, with a "Custom…" escape hatch.
///   - Administered-date / expiry-date pickers; expiry auto-fills to
///     administered + preset interval (Rabies = 36 months, others = 12).
///   - Optional vet, batch number, notes (→ `description` on the record).
///   - Save calls `MedicalRecordsRepository.addRecord(dogId:record:)` on
///     create and `.updateRecord(dogId:recordId:record:)` on edit. The
///     actual save + reminder scheduling is handled by the parent via
///     `onSave`, so this view stays Firestore-agnostic.
struct VaccinationFormSheet: View {

    /// Vaccine presets — name + re-vaccination interval in months.
    /// Matches `VaccinationReminder.VACCINATION_SCHEDULES` on Android
    /// (v7.5.0).
    struct Preset: Hashable {
        let name: String
        let intervalMonths: Int
    }

    static let presets: [Preset] = [
        Preset(name: "Distemper", intervalMonths: 12),
        Preset(name: "Parvovirus", intervalMonths: 12),
        Preset(name: "Hepatitis", intervalMonths: 12),
        Preset(name: "Leptospirosis", intervalMonths: 12),
        Preset(name: "Kennel Cough", intervalMonths: 12),
        Preset(name: "Bordetella", intervalMonths: 12),
        Preset(name: "Rabies", intervalMonths: 36),
        Preset(name: "Parainfluenza", intervalMonths: 12)
    ]

    static let customSentinel = "__custom__"

    @Environment(\.dismiss) private var dismiss

    /// `nil` → add mode; non-nil → edit mode (record id drives update).
    let existing: MedicalRecord?

    /// Async save callback. Parent writes to Firestore and schedules the
    /// reminder; this sheet just gathers input and hands back the
    /// populated `MedicalRecord`. Errors propagate back as a thrown
    /// error so we can render `errorMessage`.
    let onSave: (MedicalRecord) async throws -> Void

    // MARK: - Form state

    @State private var selectedPresetName: String
    @State private var customName: String
    @State private var administeredDate: Date
    @State private var expiresDate: Date
    @State private var manuallyEditedExpiry: Bool
    @State private var veterinarian: String
    @State private var batchNumber: String
    @State private var notes: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        existing: MedicalRecord? = nil,
        onSave: @escaping (MedicalRecord) async throws -> Void
    ) {
        self.existing = existing
        self.onSave = onSave

        // Seed the form fields from the existing record if editing.
        let initialName = existing?.vaccinationName ?? existing?.title ?? ""
        let preset = Self.presets.first(where: { $0.name == initialName })
        _selectedPresetName = State(
            initialValue: preset?.name ?? (initialName.isEmpty ? (Self.presets.first?.name ?? "") : Self.customSentinel)
        )
        _customName = State(
            initialValue: (preset == nil && !initialName.isEmpty) ? initialName : ""
        )

        let now = Date()
        let administered: Date = {
            if let ms = existing?.administeredAt {
                return Date(timeIntervalSince1970: TimeInterval(ms) / 1000.0)
            }
            return now
        }()
        _administeredDate = State(initialValue: administered)

        let expires: Date = {
            if let ms = existing?.expiresAt {
                return Date(timeIntervalSince1970: TimeInterval(ms) / 1000.0)
            }
            // Default expiry = administered + first preset's interval.
            let months = preset?.intervalMonths ?? Self.presets.first?.intervalMonths ?? 12
            return Calendar.current.date(byAdding: .month, value: months, to: administered) ?? administered
        }()
        _expiresDate = State(initialValue: expires)

        // If editing, the user has presumably already reviewed the expiry;
        // treat it as manually-set so auto-fill doesn't stomp on it.
        _manuallyEditedExpiry = State(initialValue: existing != nil)

        _veterinarian = State(initialValue: existing?.veterinarian ?? "")
        _batchNumber = State(initialValue: existing?.batchNumber ?? "")
        _notes = State(initialValue: existing?.description ?? "")
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            Form {
                vaccineSection
                datesSection
                optionalFieldsSection

                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(existing == nil ? "Add Vaccination" : "Edit Vaccination")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isSaving ? "Saving…" : "Save") {
                        Task { await handleSave() }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
        }
    }

    // MARK: - Sections

    private var vaccineSection: some View {
        Section("Vaccine") {
            Picker("Vaccine", selection: $selectedPresetName) {
                ForEach(Self.presets, id: \.name) { preset in
                    Text(preset.name).tag(preset.name)
                }
                Text("Custom…").tag(Self.customSentinel)
            }
            .onChange(of: selectedPresetName) { newValue in
                handlePresetChange(to: newValue)
            }

            if selectedPresetName == Self.customSentinel {
                TextField("Vaccine name", text: $customName)
                    .textInputAutocapitalization(.words)
            }
        }
    }

    private var datesSection: some View {
        Section("Dates") {
            DatePicker(
                "Administered",
                selection: $administeredDate,
                displayedComponents: .date
            )
            .onChange(of: administeredDate) { _ in
                if !manuallyEditedExpiry {
                    autofillExpiry()
                }
            }

            DatePicker(
                "Expires",
                selection: Binding(
                    get: { expiresDate },
                    set: { newValue in
                        expiresDate = newValue
                        manuallyEditedExpiry = true
                    }
                ),
                displayedComponents: .date
            )
        }
    }

    private var optionalFieldsSection: some View {
        Section("Optional") {
            TextField("Veterinarian", text: $veterinarian)
                .textInputAutocapitalization(.words)
            TextField("Batch number", text: $batchNumber)
                .textInputAutocapitalization(.characters)
                .disableAutocorrection(true)
            TextField("Notes", text: $notes, axis: .vertical)
                .lineLimit(3, reservesSpace: false)
        }
    }

    // MARK: - Computed

    /// The final vaccine name — either the picker preset or the custom
    /// text field, trimmed.
    private var resolvedVaccineName: String {
        if selectedPresetName == Self.customSentinel {
            return customName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return selectedPresetName
    }

    private var canSave: Bool {
        !resolvedVaccineName.isEmpty
    }

    private var currentIntervalMonths: Int {
        Self.presets.first(where: { $0.name == selectedPresetName })?.intervalMonths ?? 12
    }

    // MARK: - Actions

    private func handlePresetChange(to newValue: String) {
        // Switching presets re-applies the interval (unless the user has
        // already manually touched the expiry, in which case we leave it).
        if !manuallyEditedExpiry {
            autofillExpiry()
        }
    }

    private func autofillExpiry() {
        guard selectedPresetName != Self.customSentinel else { return }
        if let candidate = Calendar.current.date(
            byAdding: .month,
            value: currentIntervalMonths,
            to: administeredDate
        ) {
            expiresDate = candidate
        }
    }

    @MainActor
    private func handleSave() async {
        errorMessage = nil
        guard canSave else {
            errorMessage = "Please enter a vaccine name"
            return
        }
        isSaving = true
        defer { isSaving = false }

        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let administeredMs = Int64(administeredDate.timeIntervalSince1970 * 1000)
        let expiresMs = Int64(expiresDate.timeIntervalSince1970 * 1000)
        let trimmedVet = veterinarian.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBatch = batchNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        var record = existing ?? MedicalRecord()
        record.type = .vaccination
        record.title = resolvedVaccineName
        record.vaccinationName = resolvedVaccineName
        record.description = trimmedNotes
        record.administeredAt = administeredMs
        record.expiresAt = expiresMs
        record.veterinarian = trimmedVet.isEmpty ? nil : trimmedVet
        record.batchNumber = trimmedBatch.isEmpty ? nil : trimmedBatch
        record.updatedAt = now
        if existing == nil {
            record.recordedAt = now
        }

        do {
            try await onSave(record)
            dismiss()
        } catch {
            errorMessage = "Save failed: \(error.localizedDescription)"
        }
    }
}
