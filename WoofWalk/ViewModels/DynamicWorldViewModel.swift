import Foundation
import Combine

@MainActor
class DynamicWorldViewModel: ObservableObject {
    @Published var enrichedData: DynamicWorldData?
    @Published var isLoading = false
    @Published var error: Error?

    private let service = DynamicWorldService.shared
    private var cancellables = Set<AnyCancellable>()

    func enrichField(
        fieldId: String,
        lat: Double,
        lng: Double,
        bbox: [Double]? = nil,
        forceRefresh: Bool = false
    ) async {
        isLoading = true
        error = nil

        do {
            let data = try await service.enrichSingleField(
                fieldId: fieldId,
                lat: lat,
                lng: lng,
                bbox: bbox,
                forceRefresh: forceRefresh
            )
            self.enrichedData = data
            print("[DW_VM] Successfully enriched field: \(fieldId)")
        } catch {
            self.error = error
            print("[DW_VM] Failed to enrich field: \(error.localizedDescription)")
        }

        isLoading = false
    }

    func loadCachedData(forFieldId fieldId: String) {
        do {
            if let cached = try service.getCachedData(forFieldId: fieldId) {
                self.enrichedData = cached
                print("[DW_VM] Loaded cached data for field: \(fieldId)")
            }
        } catch {
            print("[DW_VM] Failed to load cached data: \(error.localizedDescription)")
        }
    }

    func refreshIfExpired(
        fieldId: String,
        lat: Double,
        lng: Double,
        bbox: [Double]? = nil
    ) async {
        if let data = enrichedData, data.isExpired {
            print("[DW_VM] Data expired, refreshing...")
            await enrichField(
                fieldId: fieldId,
                lat: lat,
                lng: lng,
                bbox: bbox,
                forceRefresh: true
            )
        }
    }

    func clearCache() {
        do {
            try service.clearCache()
            enrichedData = nil
            print("[DW_VM] Cache cleared")
        } catch {
            self.error = error
            print("[DW_VM] Failed to clear cache: \(error.localizedDescription)")
        }
    }

    func clearExpiredCache() {
        do {
            try service.clearExpiredCache()
            print("[DW_VM] Expired cache cleared")
        } catch {
            print("[DW_VM] Failed to clear expired cache: \(error.localizedDescription)")
        }
    }
}
