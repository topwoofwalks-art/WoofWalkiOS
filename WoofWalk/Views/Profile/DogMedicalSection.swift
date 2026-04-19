import SwiftUI
import Combine

/// Owner-only medical section rendered on `DogDetailView`. Subscribes
/// to the `/dogs/{dogId}/medicalRecords` subcollection and
/// `/dogs/{dogId}/medicationSchedules` subcollection so additions by
/// a co-owner on another device appear live.
///
/// Firestore rules gate the subcollection reads to owner / co-owner /
/// org-member-with-canViewMedical — an unprivileged viewer would get a
/// permission-denied error rather than silent data; we surface that as
/// an empty UI instead of crashing.
struct DogMedicalSection: View {
    let dogId: String
    var isOwner: Bool = true

    @StateObject private var vm = MedicalSectionViewModel()

    var body: some View {
        guard isOwner else { return AnyView(EmptyView()) }
        return AnyView(content)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Medical")
                .font(.headline)
                .fontWeight(.bold)

            if vm.isLoading {
                ProgressView()
            } else {
                vaccinationsBlock
                Divider()
                medicationSchedulesBlock
                Divider()
                otherRecordsBlock
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
        .onAppear { vm.start(dogId: dogId) }
        .onDisappear { vm.stop() }
    }

    // MARK: - Vaccinations

    private var vaccinationsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Vaccinations", systemImage: "syringe")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(vm.vaccinations.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if vm.vaccinations.isEmpty {
                Text("None recorded")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(vm.vaccinations) { record in
                    vaccinationRow(record)
                }
            }
        }
    }

    private func vaccinationRow(_ record: MedicalRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.title.isEmpty ? (record.vaccinationName ?? "Vaccination") : record.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                if let vet = record.veterinarian, !vet.isEmpty {
                    Text("By \(vet)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if let expires = record.expiresAt {
                let date = Date(timeIntervalSince1970: TimeInterval(expires) / 1000.0)
                let overdue = date < Date()
                Text(overdue ? "Overdue" : dateLabel(date))
                    .font(.caption)
                    .foregroundColor(overdue ? .red : .secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Medication schedules

    private var medicationSchedulesBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Medications", systemImage: "pills")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(vm.activeMedications.count) active")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if vm.activeMedications.isEmpty {
                Text("No active medications")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(vm.activeMedications) { schedule in
                    medicationRow(schedule)
                }
            }
        }
    }

    private func medicationRow(_ schedule: MedicationSchedule) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(schedule.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("\(schedule.dosage) \(schedule.dosageUnit) • \(schedule.frequency)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if schedule.isOverdue {
                    Text("Overdue")
                        .font(.caption)
                        .foregroundColor(.red)
                } else if let next = schedule.nextDueDate {
                    Text(dateLabel(Date(timeIntervalSince1970: TimeInterval(next) / 1000.0)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if isOwner {
                    Button("Log dose") {
                        Task { await vm.markAdministered(dogId: dogId, schedule: schedule) }
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Other records

    private var otherRecordsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Other records", systemImage: "doc.text")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(vm.otherRecords.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if vm.otherRecords.isEmpty {
                Text("No other medical records")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(vm.otherRecords) { record in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        if !record.description.isEmpty {
                            Text(record.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Helpers

    private func dateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

@MainActor
final class MedicalSectionViewModel: ObservableObject {
    @Published var vaccinations: [MedicalRecord] = []
    @Published var activeMedications: [MedicationSchedule] = []
    @Published var otherRecords: [MedicalRecord] = []
    @Published var isLoading = false

    private let medicalRepo = MedicalRecordsRepository()
    private let scheduleRepo = MedicationScheduleRepository()
    private var cancellables = Set<AnyCancellable>()

    func start(dogId: String) {
        isLoading = true
        cancellables.removeAll()

        medicalRepo.observeRecords(dogId: dogId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure = completion { self?.isLoading = false }
                },
                receiveValue: { [weak self] records in
                    self?.vaccinations = records.filter { $0.type == .vaccination }
                    self?.otherRecords = records.filter { r in
                        r.type != .vaccination && r.type != .medicationLog
                    }
                    self?.isLoading = false
                }
            )
            .store(in: &cancellables)

        scheduleRepo.observeSchedules(dogId: dogId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] schedules in
                    self?.activeMedications = schedules.filter { $0.isActive }
                }
            )
            .store(in: &cancellables)
    }

    func stop() {
        cancellables.removeAll()
    }

    func markAdministered(dogId: String, schedule: MedicationSchedule) async {
        do {
            try await scheduleRepo.markAdministered(dogId: dogId, schedule: schedule)
        } catch {
            print("[MedicalSection] markAdministered failed: \(error.localizedDescription)")
        }
    }
}
