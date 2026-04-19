import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

/// Reads + writes active medication schedules for a dog in the
/// `/dogs/{dogId}/medicationSchedules/{scheduleId}` subcollection.
///
/// Administration events are logged to MedicalRecords with
/// `type == .medicationLog` so the medical audit trail stays unified.
final class MedicationScheduleRepository {
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private let medicalRecordsRepository: MedicalRecordsRepository

    init(medicalRecordsRepository: MedicalRecordsRepository = MedicalRecordsRepository()) {
        self.medicalRecordsRepository = medicalRecordsRepository
    }

    private func subcollection(dogId: String) -> CollectionReference {
        db.collection("dogs").document(dogId).collection("medicationSchedules")
    }

    /// Real-time stream of medication schedules, active-first then by
    /// ascending `nextDueDate` (overdue at the top, as_needed at the
    /// bottom).
    func observeSchedules(dogId: String) -> AnyPublisher<[MedicationSchedule], Error> {
        let subject = PassthroughSubject<[MedicationSchedule], Error>()
        let listener = subcollection(dogId: dogId)
            .order(by: "isActive", descending: true)
            .order(by: "nextDueDate", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    subject.send(completion: .failure(error))
                    return
                }
                let schedules = snapshot?.documents.compactMap { doc -> MedicationSchedule? in
                    try? doc.data(as: MedicationSchedule.self)
                } ?? []
                subject.send(schedules)
            }
        return subject
            .handleEvents(receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }

    @discardableResult
    func addSchedule(dogId: String, schedule: MedicationSchedule) async throws -> String {
        guard auth.currentUser?.uid != nil else {
            throw NSError(
                domain: "MedicationScheduleRepository",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Not authenticated"]
            )
        }
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        var payload = schedule
        payload.dogId = dogId
        if payload.createdAt == 0 {
            payload.createdAt = now
        }
        payload.updatedAt = now
        let ref = try subcollection(dogId: dogId).addDocument(from: payload)
        return ref.documentID
    }

    func updateSchedule(dogId: String, scheduleId: String, schedule: MedicationSchedule) async throws {
        var payload = schedule
        payload.dogId = dogId
        payload.updatedAt = Int64(Date().timeIntervalSince1970 * 1000)
        try subcollection(dogId: dogId).document(scheduleId).setData(from: payload, merge: true)
    }

    /// Mark a dose as administered. Updates `lastAdministered` +
    /// `nextDueDate` on the schedule and appends a MEDICATION_LOG
    /// record to the medical-records audit.
    func markAdministered(
        dogId: String,
        schedule: MedicationSchedule,
        administeredAt: Int64? = nil
    ) async throws {
        let now = administeredAt ?? Int64(Date().timeIntervalSince1970 * 1000)
        let wasLate = schedule.isOverdue
        let next = schedule.calculateNextDueDate(
            administeredAt: now,
            isLateAdministration: wasLate
        )

        guard let scheduleId = schedule.id else {
            throw NSError(
                domain: "MedicationScheduleRepository",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Schedule has no id"]
            )
        }

        var updated = schedule
        updated.lastAdministered = now
        updated.nextDueDate = next
        updated.updatedAt = Int64(Date().timeIntervalSince1970 * 1000)
        try await updateSchedule(dogId: dogId, scheduleId: scheduleId, schedule: updated)

        let lateSuffix = wasLate ? " (late)" : ""
        let description = "Dose administered\(lateSuffix): \(schedule.dosage) \(schedule.dosageUnit)"
            .trimmingCharacters(in: .whitespaces)

        let logRecord = MedicalRecord(
            dogId: dogId,
            type: .medicationLog,
            title: schedule.name,
            description: description,
            recordedAt: now,
            metadata: [
                "scheduleId": scheduleId,
                "dosage": schedule.dosage,
                "dosageUnit": schedule.dosageUnit,
                "wasLate": String(wasLate)
            ]
        )
        _ = try await medicalRecordsRepository.addRecord(dogId: dogId, record: logRecord)
    }

    func deleteSchedule(dogId: String, scheduleId: String) async throws {
        try await subcollection(dogId: dogId).document(scheduleId).delete()
    }
}
