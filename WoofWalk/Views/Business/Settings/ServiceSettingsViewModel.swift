import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Model

/// In-memory model of one row in the service catalogue editor.
/// Mirrors Android's `ServicePricing` (settings model) shape so the data
/// flow through `service_listings` stays identical across platforms.
struct ServicePricingItem: Identifiable, Equatable {
    /// Firestore document id of the underlying `service_listings` doc.
    /// Empty string when no doc exists yet for this org+serviceType pair.
    var listingId: String
    /// Canonical service type (matches `BookingServiceType.rawValue`,
    /// e.g. "WALK", "GROOMING", "BOARDING").
    var serviceType: String
    var displayName: String
    var description: String
    var enabled: Bool
    var basePrice: Double
    var pricePerAdditionalDog: Double
    var duration: Int
    var maxDogs: Int

    var id: String { listingId.isEmpty ? "new-\(serviceType)" : listingId }

    /// Map a canonical serviceType + listing payload to a typed item.
    static func from(serviceType: String, listingId: String, data: [String: Any]) -> ServicePricingItem {
        let bookingType = BookingServiceType.from(rawValue: serviceType)
        let name = (data["name"] as? String)
            ?? (data["displayName"] as? String)
            ?? bookingType.displayName
        let description = data["description"] as? String ?? ""
        let isActive = (data["isActive"] as? Bool) ?? (data["enabled"] as? Bool) ?? false
        let basePrice = (data["basePrice"] as? NSNumber)?.doubleValue ?? 0.0
        let perAdditional = (data["pricePerAdditionalDog"] as? NSNumber)?.doubleValue ?? 0.0
        let duration = (data["duration"] as? NSNumber)?.intValue ?? bookingType.defaultDuration
        let maxDogs = ((data["maxPets"] as? NSNumber)?.intValue)
            ?? ((data["maxDogs"] as? NSNumber)?.intValue)
            ?? bookingType.maxDogs
        return ServicePricingItem(
            listingId: listingId,
            serviceType: serviceType,
            displayName: name,
            description: description,
            enabled: isActive,
            basePrice: basePrice,
            pricePerAdditionalDog: perAdditional,
            duration: duration,
            maxDogs: maxDogs
        )
    }
}

// MARK: - Repository

/// Repository for the per-org service catalogue stored in `service_listings`.
/// Only sparse `updateData(...)` is used — the wizard's nested sub-configs
/// (walkConfig, groomingConfig, boardingConfig, …) are never overwritten.
final class ServiceListingsRepository {
    private let db = Firestore.firestore()
    private let auth = Auth.auth()

    private var collection: CollectionReference {
        db.collection("service_listings")
    }

    /// Fetch all listings for an org. Mirrors Android's
    /// `fetchServiceListings(orgId)`.
    func fetchListings(orgId: String) async throws -> [ServicePricingItem] {
        let snapshot = try await collection
            .whereField("orgId", isEqualTo: orgId)
            .getDocuments()
        return snapshot.documents.map { doc in
            ServicePricingItem.from(
                serviceType: doc.data()["serviceType"] as? String ?? "",
                listingId: doc.documentID,
                data: doc.data()
            )
        }
        .filter { !$0.serviceType.isEmpty }
    }

    /// Sparse-patch a service listing. If `existing.listingId` is empty
    /// and there's no doc for orgId+serviceType yet, an R3-compliant
    /// document is created. Mirrors Android's `patchServiceListing(...)`.
    @discardableResult
    func patchListing(
        orgId: String,
        serviceType: String,
        existing: ServicePricingItem?,
        fields: [String: Any]
    ) async throws -> String {
        guard let uid = auth.currentUser?.uid else {
            throw NSError(
                domain: "ServiceListingsRepository",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Not authenticated"]
            )
        }

        // Fast path: in-memory listingId.
        if let existing, !existing.listingId.isEmpty {
            try await collection.document(existing.listingId).updateData(fields)
            return existing.listingId
        }

        // Fallback: locate by orgId + serviceType.
        let match = try await collection
            .whereField("orgId", isEqualTo: orgId)
            .whereField("serviceType", isEqualTo: serviceType)
            .limit(to: 1)
            .getDocuments()
            .documents
            .first

        if let match {
            try await match.reference.updateData(fields)
            return match.documentID
        }

        // Create with R3-compliant minimum shape.
        let bookingType = BookingServiceType.from(rawValue: serviceType)
        var base: [String: Any] = [
            "orgId": orgId,
            "serviceType": serviceType,
            "createdBy": uid,
            "isActive": existing?.enabled ?? true,
            "basePrice": existing?.basePrice ?? 0.0,
            "pricePerAdditionalDog": existing?.pricePerAdditionalDog ?? 0.0,
            "duration": Int(existing?.duration ?? bookingType.defaultDuration),
            "maxPets": Int(existing?.maxDogs ?? bookingType.maxDogs),
            "name": existing?.displayName ?? bookingType.displayName,
            "description": existing?.description ?? ""
        ]
        // Patch fields override defaults.
        for (key, value) in fields {
            base[key] = value
        }
        // Newer Firestore SDK exposes `addDocument(data:)` as a
        // throwing async (alongside the legacy completion-handler
        // variant). Awaiting it gives us the DocumentReference once
        // the local write is committed.
        let ref = try await collection.addDocument(data: base)
        return ref.documentID
    }
}

// MARK: - ViewModel

@MainActor
final class ServiceSettingsViewModel: ObservableObject {
    @Published var services: [ServicePricingItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let repository = ServiceListingsRepository()
    private let orgId: String

    init(orgId: String) {
        self.orgId = orgId
    }

    /// Convenience init that resolves orgId from the current Firebase user.
    /// Sole-trader businesses use uid as orgId — same convention as the
    /// existing iOS code (BusinessViewModel, DiscountManager).
    convenience init() {
        self.init(orgId: Auth.auth().currentUser?.uid ?? "")
    }

    func load() async {
        guard !orgId.isEmpty else {
            self.errorMessage = "No organization id"
            return
        }
        self.isLoading = true
        defer { self.isLoading = false }
        do {
            let fetched = try await repository.fetchListings(orgId: orgId)
            // Sort by canonical enum order so the list is stable.
            let order = BookingServiceType.allCases.map(\.rawValue)
            self.services = fetched.sorted { a, b in
                let ai = order.firstIndex(of: a.serviceType) ?? Int.max
                let bi = order.firstIndex(of: b.serviceType) ?? Int.max
                return ai < bi
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func toggle(_ service: ServicePricingItem, enabled: Bool) async {
        do {
            let listingId = try await repository.patchListing(
                orgId: orgId,
                serviceType: service.serviceType,
                existing: service,
                fields: ["isActive": enabled]
            )
            // Optimistic local update.
            if let idx = services.firstIndex(where: { $0.id == service.id }) {
                services[idx].enabled = enabled
                if services[idx].listingId.isEmpty {
                    services[idx].listingId = listingId
                }
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func updatePricing(
        _ service: ServicePricingItem,
        basePrice: Double,
        pricePerAdditionalDog: Double
    ) async {
        do {
            let listingId = try await repository.patchListing(
                orgId: orgId,
                serviceType: service.serviceType,
                existing: service,
                fields: [
                    "basePrice": basePrice,
                    "pricePerAdditionalDog": pricePerAdditionalDog
                ]
            )
            if let idx = services.firstIndex(where: { $0.id == service.id }) {
                services[idx].basePrice = basePrice
                services[idx].pricePerAdditionalDog = pricePerAdditionalDog
                if services[idx].listingId.isEmpty {
                    services[idx].listingId = listingId
                }
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
