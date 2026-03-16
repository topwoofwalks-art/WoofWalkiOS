import Foundation
import FirebaseFunctions

class DynamicWorldService {
    static let shared = DynamicWorldService()

    private let functions: Functions
    private let cacheManager: DynamicWorldCacheManager

    private init() {
        self.functions = Functions.functions()
        self.cacheManager = DynamicWorldCacheManager.shared
    }

    func enrichFields(
        _ fields: [FieldLocation],
        dateRange: DateRange? = nil,
        forceRefresh: Bool = false
    ) async throws -> FieldEnrichmentResponse {
        print("[DW_SERVICE] Enriching \(fields.count) fields with Dynamic World data")

        if !forceRefresh {
            let cachedFields = fields.compactMap { field -> EnrichedField? in
                guard let cached = try? cacheManager.getCachedData(forFieldId: field.fieldId),
                      !cached.isExpired else {
                    return nil
                }

                return EnrichedField(
                    fieldId: cached.fieldId,
                    probabilities: cached.landCover,
                    dominantClass: cached.dominantClass,
                    livestockSuitability: cached.livestockSuitability.score,
                    timestamp: Int64(cached.fetchedAt.timeIntervalSince1970 * 1000)
                )
            }

            if cachedFields.count == fields.count {
                print("[DW_SERVICE] Returning \(cachedFields.count) cached fields")
                return FieldEnrichmentResponse(
                    success: true,
                    fields: cachedFields,
                    count: cachedFields.count
                )
            }
        }

        let requestData: [String: Any] = [
            "fields": fields.map { field in
                var fieldDict: [String: Any] = [
                    "fieldId": field.fieldId,
                    "lat": field.lat,
                    "lng": field.lng
                ]
                if let bbox = field.bbox {
                    fieldDict["bbox"] = bbox
                }
                return fieldDict
            },
            "dateRange": dateRange.map { range in
                [
                    "start": range.start,
                    "end": range.end
                ]
            } as Any
        ]

        do {
            let result = try await functions.httpsCallable("enrichFieldsWithDynamicWorld")
                .call(requestData)

            guard let data = result.data as? [String: Any],
                  let success = data["success"] as? Bool,
                  let fieldsArray = data["fields"] as? [[String: Any]],
                  let count = data["count"] as? Int else {
                throw DynamicWorldError.invalidResponse
            }

            let enrichedFields = try fieldsArray.compactMap { fieldData -> EnrichedField? in
                try parseEnrichedField(fieldData)
            }

            for (field, enrichedField) in zip(fields, enrichedFields) {
                let dwData = enrichedField.toDynamicWorldData(
                    centerLat: field.lat,
                    centerLng: field.lng,
                    radiusMeters: nil
                )
                try? cacheManager.cacheData(dwData)
            }

            print("[DW_SERVICE] Successfully enriched \(enrichedFields.count) fields")

            return FieldEnrichmentResponse(
                success: success,
                fields: enrichedFields,
                count: count
            )
        } catch let error as DynamicWorldError {
            print("[DW_SERVICE] Enrichment error: \(error.localizedDescription)")
            throw error
        } catch {
            print("[DW_SERVICE] Failed to enrich fields: \(error.localizedDescription)")
            throw DynamicWorldError.enrichmentFailed(error.localizedDescription)
        }
    }

    func enrichSingleField(
        fieldId: String,
        lat: Double,
        lng: Double,
        bbox: [Double]? = nil,
        forceRefresh: Bool = false
    ) async throws -> DynamicWorldData {
        if !forceRefresh {
            if let cached = try? cacheManager.getCachedData(forFieldId: fieldId),
               !cached.isExpired {
                print("[DW_SERVICE] Returning cached data for field \(fieldId)")
                return cached
            }
        }

        let field = FieldLocation(fieldId: fieldId, lat: lat, lng: lng, bbox: bbox)
        let response = try await enrichFields([field], forceRefresh: forceRefresh)

        guard let enrichedField = response.fields.first else {
            throw DynamicWorldError.noDataReturned
        }

        return enrichedField.toDynamicWorldData(
            centerLat: lat,
            centerLng: lng,
            radiusMeters: nil
        )
    }

    func getCachedData(forFieldId fieldId: String) throws -> DynamicWorldData? {
        return try cacheManager.getCachedData(forFieldId: fieldId)
    }

    func clearCache() throws {
        try cacheManager.clearCache()
    }

    func clearExpiredCache() throws {
        try cacheManager.clearExpiredCache()
    }

    private func parseEnrichedField(_ data: [String: Any]) throws -> EnrichedField {
        guard let fieldId = data["fieldId"] as? String else {
            throw DynamicWorldError.invalidResponse
        }

        guard let probsData = data["probabilities"] as? [String: Any] else {
            throw DynamicWorldError.invalidResponse
        }

        let probabilities = LandCoverProbabilities(
            water: probsData["water"] as? Double ?? 0.0,
            trees: probsData["trees"] as? Double ?? 0.0,
            grass: probsData["grass"] as? Double ?? 0.0,
            floodedVegetation: probsData["floodedVegetation"] as? Double ?? 0.0,
            crops: probsData["crops"] as? Double ?? 0.0,
            shrubAndScrub: probsData["shrubAndScrub"] as? Double ?? 0.0,
            built: probsData["built"] as? Double ?? 0.0,
            bare: probsData["bare"] as? Double ?? 0.0,
            snowAndIce: probsData["snowAndIce"] as? Double ?? 0.0
        )

        let dominantClass = data["dominantClass"] as? String ?? probabilities.dominant.type
        let suitability = data["livestockSuitability"] as? Double
            ?? calculateLivestockSuitability(probabilities)
        let timestamp = data["timestamp"] as? Int64 ?? Int64(Date().timeIntervalSince1970 * 1000)

        return EnrichedField(
            fieldId: fieldId,
            probabilities: probabilities,
            dominantClass: dominantClass,
            livestockSuitability: suitability,
            timestamp: timestamp
        )
    }

    func calculateLivestockSuitability(_ probs: LandCoverProbabilities) -> Double {
        let grassWeight = 0.40
        let cropsWeight = 0.25
        let shrubWeight = 0.15
        let treesWeight = 0.10
        let builtPenalty = -0.50
        let waterPenalty = -0.30

        let score = (probs.grass * grassWeight) +
                   (probs.crops * cropsWeight) +
                   (probs.shrubAndScrub * shrubWeight) +
                   (probs.trees * treesWeight) +
                   (probs.built * builtPenalty) +
                   (probs.water * waterPenalty)

        return max(0.0, min(100.0, score * 100.0))
    }
}
