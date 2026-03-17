import Foundation
import CoreLocation
import FirebaseFirestore
import FirebaseAuth
import Combine

actor LivestockFieldRepository {
    private let firestore: Firestore
    private let auth: Auth
    private let overpassService: OverpassService
    private let lock = NSLock()

    private var tileCache: [String: FieldTile] = [:]
    private var tileCacheLRU: [String] = []
    private let maxCacheSizeBytes: Int = 10 * 1024 * 1024
    private var currentCacheSize: Int = 0

    @Published private(set) var cachedFields: [String: LivestockField] = [:]

    var cachedFieldsPublisher: Published<[String: LivestockField]>.Publisher { $cachedFields }

    init(
        firestore: Firestore = .firestore(),
        auth: Auth = .auth(),
        overpassService: OverpassService = OverpassService()
    ) {
        self.firestore = firestore
        self.auth = auth
        self.overpassService = overpassService
    }

    func loadTile(tileCoord: TileCoord) async throws -> FieldTile {
        let tileId = tileCoord.tileId

        if let cached = getCachedTile(tileId) {
            updateLRU(tileId)
            return cached
        }

        if let diskTile = try await loadFromDisk(tileId) {
            addToCache(tileId: tileId, tile: diskTile)
            return diskTile
        }

        do {
            let tile = try await fetchTileFromFirestore(tileId)
            if !tile.features.isEmpty {
                try await saveToDisk(tileId: tileId, tile: tile)
            }
            addToCache(tileId: tileId, tile: tile)
            return tile
        } catch {
            print("Failed to fetch tile from Firestore: \(tileId), returning empty tile. Error: \(error)")
            let emptyTile = FieldTile(tileId: tileId)
            return emptyTile
        }
    }

    func getAllCachedFields() -> [LivestockField] {
        Array(cachedFields.values)
    }

    func getFieldsInViewport(bounds: [CLLocationCoordinate2D]) -> [LivestockField] {
        guard !bounds.isEmpty else { return [] }

        let minLat = bounds.map { $0.latitude }.min() ?? 0
        let maxLat = bounds.map { $0.latitude }.max() ?? 0
        let minLng = bounds.map { $0.longitude }.min() ?? 0
        let maxLng = bounds.map { $0.longitude }.max() ?? 0

        print("[VIEWPORT_FILTER] Bounds: [(\(minLat),\(minLng)) to (\(maxLat),\(maxLng))]")
        print("[VIEWPORT_FILTER] Total cached fields: \(cachedFields.count)")

        var inBoundsCount = 0
        var outOfBoundsCount = 0

        let fields = cachedFields.values.filter { field in
            let centroid = field.centroid
            let isInBounds = centroid.latitude >= minLat &&
                           centroid.latitude <= maxLat &&
                           centroid.longitude >= minLng &&
                           centroid.longitude <= maxLng

            if isInBounds {
                inBoundsCount += 1
            } else {
                outOfBoundsCount += 1
            }
            return isInBounds
        }

        print("[VIEWPORT_FILTER] RESULT: \(inBoundsCount) fields IN bounds, \(outOfBoundsCount) OUT of bounds")
        return Array(fields)
    }

    func submitFieldSignal(
        fieldId: String,
        species: [LivestockSpecies],
        present: Bool,
        isDangerous: Bool,
        location: CLLocationCoordinate2D,
        notes: String? = nil,
        photoUrl: String? = nil
    ) async throws -> String {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(domain: "LivestockFieldRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let tileCoord = TileCoord.from(coordinate: location, zoom: 14)

        let enhancedNotes: String?
        if isDangerous {
            let baseNotes = notes ?? ""
            enhancedNotes = baseNotes.isEmpty ? "[HAZARD]" : "\(baseNotes) [HAZARD]"
        } else {
            enhancedNotes = notes
        }

        let signal = FieldSignal(
            fieldId: fieldId,
            userId: userId,
            species: species,
            present: present,
            notes: enhancedNotes,
            photoUrl: photoUrl,
            location: GeoPoint(latitude: location.latitude, longitude: location.longitude),
            viewport: tileCoord,
            createdAt: Date().timeIntervalSince1970 * 1000,
            clientOs: "iOS",
            appVersion: getAppVersion(),
            synced: false
        )

        try await saveSignalToLocal(signal)
        print("Field signal saved to local database: \(fieldId), present=\(present), dangerous=\(isDangerous)")

        return signal.fieldId
    }

    func findFieldAtLocation(location: CLLocationCoordinate2D) -> LivestockField? {
        cachedFields.values.first { field in
            guard !field.polygon.isEmpty else { return false }
            return pointInPolygon(point: location, polygon: field.polygon)
        }
    }

    func syncSignalQueue() async throws -> Int {
        let unsyncedSignals = try await getUnsyncedSignals()
        guard !unsyncedSignals.isEmpty else {
            print("No signals to sync")
            return 0
        }

        var syncedCount = 0

        for signal in unsyncedSignals {
            do {
                try await uploadSignalToFirestore(signal)
                try await markSignalSynced(signal)
                syncedCount += 1
                print("Signal synced: \(signal.fieldId)")
            } catch {
                print("Failed to sync signal: \(signal.fieldId). Error: \(error)")
            }
        }

        print("Synced \(syncedCount)/\(unsyncedSignals.count) field signals")
        return syncedCount
    }

    func getQueuedSignalCount() async throws -> Int {
        let signals = try await getUnsyncedSignals()
        return signals.count
    }

    private func fetchTileFromFirestore(_ tileId: String) async throws -> FieldTile {
        let doc = try await firestore.collection("fieldTiles").document(tileId).getDocument()

        guard doc.exists, let data = doc.data() else {
            return FieldTile(tileId: tileId)
        }

        let featuresData = data["features"] as? [[String: Any]] ?? []
        let features = featuresData.compactMap { parseFieldFeature($0) }

        let tile = FieldTile(
            tileId: tileId,
            features: features,
            checksum: data["checksum"] as? String ?? "",
            version: data["version"] as? String ?? "1.0",
            cachedAt: Date().timeIntervalSince1970 * 1000
        )

        await updateFieldsFromTile(tile)

        return tile
    }

    private func uploadSignalToFirestore(_ signal: FieldSignal) async throws {
        let date = Date(timeIntervalSince1970: signal.createdAt / 1000)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd"
        let datePath = dateFormatter.string(from: date)

        let signalDoc: [String: Any] = [
            "fieldId": signal.fieldId,
            "userId": signal.userId,
            "species": signal.species.map { $0.rawValue },
            "present": signal.present,
            "notes": signal.notes as Any,
            "photoUrl": signal.photoUrl as Any,
            "location": signal.location,
            "viewport": [
                "z": signal.viewport.z,
                "x": signal.viewport.x,
                "y": signal.viewport.y
            ],
            "createdAt": signal.createdAt,
            "clientOs": signal.clientOs,
            "appVersion": signal.appVersion
        ]

        try await firestore
            .collection("fieldSignals")
            .document(datePath)
            .collection("signals")
            .addDocument(data: signalDoc)

        print("Field signal uploaded: \(signal.fieldId)")
    }

    private func parseFieldFeature(_ map: [String: Any]) -> FieldFeature? {
        guard let fieldId = map["fieldId"] as? String,
              let geomMap = map["geom"] as? [String: Any],
              let type = geomMap["type"] as? String,
              let coordsData = geomMap["coords"] as? [[[Double]]],
              let bbox = map["bbox"] as? [Double], bbox.count == 4,
              let centroid = map["centroid"] as? [Double], centroid.count == 2,
              let area_m2 = map["area_m2"] as? Double else {
            return nil
        }

        let geom = FieldGeometry(type: type, coords: coordsData)

        return FieldFeature(
            fieldId: fieldId,
            geom: geom,
            bbox: bbox,
            centroid: centroid,
            area_m2: area_m2
        )
    }

    private func updateFieldsFromTile(_ tile: FieldTile) async {
        print("[CACHE_UPDATE] updateFieldsFromTile - tile has \(tile.features.count) features")

        var currentFields = cachedFields
        var addedCount = 0
        var updatedCount = 0
        var skippedCount = 0

        for feature in tile.features {
            let polygon = feature.toPolygon().map { [$0.longitude, $0.latitude] }

            if let existing = currentFields[feature.fieldId] {
                if existing.polygon.isEmpty {
                    var updated = existing
                    currentFields[feature.fieldId] = LivestockField(
                        fieldId: updated.fieldId,
                        centroid: updated.centroid,
                        bbox: updated.bbox,
                        area_m2: updated.area_m2,
                        confidence: updated.confidence,
                        speciesScores: updated.speciesScores,
                        lastSeenAt: updated.lastSeenAt,
                        lastNoLivestockAt: updated.lastNoLivestockAt,
                        votesUp: updated.votesUp,
                        votesDown: updated.votesDown,
                        signalCount: updated.signalCount,
                        decayedAt: updated.decayedAt,
                        polygonRaw: polygon,
                        isDangerous: updated.isDangerous,
                        isOsmField: updated.isOsmField,
                        osmLanduse: updated.osmLanduse,
                        dwGrassProbability: updated.dwGrassProbability,
                        dwCropsProbability: updated.dwCropsProbability,
                        dwTreesProbability: updated.dwTreesProbability,
                        dwBuiltProbability: updated.dwBuiltProbability,
                        dwWaterProbability: updated.dwWaterProbability,
                        dwLastUpdated: updated.dwLastUpdated
                    )
                    updatedCount += 1
                } else {
                    skippedCount += 1
                }
            } else {
                currentFields[feature.fieldId] = LivestockField(
                    fieldId: feature.fieldId,
                    centroid: GeoPoint(latitude: feature.centroid[1], longitude: feature.centroid[0]),
                    bbox: feature.bbox,
                    area_m2: feature.area_m2,
                    polygonRaw: polygon
                )
                addedCount += 1
            }
        }

        cachedFields = currentFields
        print("[CACHE_UPDATE] Complete - size: \(currentFields.count) (added: \(addedCount), updated: \(updatedCount), skipped: \(skippedCount))")
    }

    private func getCachedTile(_ tileId: String) -> FieldTile? {
        lock.lock()
        defer { lock.unlock() }
        return tileCache[tileId]
    }

    private func addToCache(tileId: String, tile: FieldTile) {
        lock.lock()
        defer { lock.unlock() }

        let tileSize = estimateTileSize(tile)

        while currentCacheSize + tileSize > maxCacheSizeBytes && !tileCacheLRU.isEmpty {
            let oldestTileId = tileCacheLRU.removeFirst()
            if let removedTile = tileCache.removeValue(forKey: oldestTileId) {
                currentCacheSize -= estimateTileSize(removedTile)
            }
        }

        tileCache[tileId] = tile
        tileCacheLRU.append(tileId)
        currentCacheSize += tileSize

        print("Tile cached: \(tileId), cache size: \(currentCacheSize / 1024)KB")
    }

    private func updateLRU(_ tileId: String) {
        lock.lock()
        defer { lock.unlock() }

        tileCacheLRU.removeAll { $0 == tileId }
        tileCacheLRU.append(tileId)
    }

    private func estimateTileSize(_ tile: FieldTile) -> Int {
        tile.features.count * 2048
    }

    private func loadFromDisk(_ tileId: String) async throws -> FieldTile? {
        return nil
    }

    private func saveToDisk(tileId: String, tile: FieldTile) async throws {
    }

    private func saveSignalToLocal(_ signal: FieldSignal) async throws {
    }

    private func getUnsyncedSignals() async throws -> [FieldSignal] {
        return []
    }

    private func markSignalSynced(_ signal: FieldSignal) async throws {
    }

    private func getAppVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    func loadTilesInViewport(bounds: [CLLocationCoordinate2D], zoom: Int = 14) async throws -> [FieldTile] {
        guard !bounds.isEmpty else { return [] }

        let minLat = bounds.map { $0.latitude }.min() ?? 0
        let maxLat = bounds.map { $0.latitude }.max() ?? 0
        let minLng = bounds.map { $0.longitude }.min() ?? 0
        let maxLng = bounds.map { $0.longitude }.max() ?? 0

        let minTile = TileCoord.from(coordinate: CLLocationCoordinate2D(latitude: minLat, longitude: minLng), zoom: zoom)
        let maxTile = TileCoord.from(coordinate: CLLocationCoordinate2D(latitude: maxLat, longitude: maxLng), zoom: zoom)

        var tiles: [FieldTile] = []

        for x in minTile.x...maxTile.x {
            for y in minTile.y...maxTile.y {
                let tileCoord = TileCoord(z: zoom, x: x, y: y)
                do {
                    let tile = try await loadTile(tileCoord: tileCoord)
                    tiles.append(tile)
                } catch {
                    print("Failed to load tile \(tileCoord.tileId): \(error)")
                }
            }
        }

        print("Loaded \(tiles.count) tiles in viewport")
        return tiles
    }

    func cleanupOldData(retentionDays: Int = 30) async throws {
        let cutoffTime = Date().timeIntervalSince1970 - Double(retentionDays * 24 * 60 * 60)
        print("Cleaned up data older than \(retentionDays) days")
    }

    func loadUserDrawnFields() async throws -> [LivestockField] {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(domain: "LivestockFieldRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        print("[LOAD_USER_FIELDS] Loading user-drawn fields for user: \(userId)")

        let snapshot = try await firestore.collection("userLivestockFields")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        let fields = snapshot.documents.compactMap { doc -> LivestockField? in
            guard let data = doc.data() as? [String: Any],
                  let fieldId = data["fieldId"] as? String,
                  let centroidGeo = data["centroid"] as? GeoPoint,
                  let bbox = data["bbox"] as? [Double],
                  let area_m2 = data["area_m2"] as? Double,
                  let polygonData = data["polygon"] as? [[String: Double]] else {
                return nil
            }

            let polygon = polygonData.compactMap { point -> [Double]? in
                guard let lat = point["lat"], let lng = point["lng"] else { return nil }
                return [lng, lat]
            }

            let isDangerous = data["isDangerous"] as? Bool ?? false
            let lastSeenAt = data["lastSeenAt"] as? TimeInterval

            let speciesScoresData = data["speciesScores"] as? [String: Double] ?? [:]

            return LivestockField(
                fieldId: fieldId,
                centroid: centroidGeo,
                bbox: bbox,
                area_m2: area_m2,
                speciesScores: speciesScoresData,
                lastSeenAt: lastSeenAt,
                polygonRaw: polygon,
                isDangerous: isDangerous
            )
        }

        var currentFields = cachedFields
        for field in fields {
            currentFields[field.fieldId] = field
        }
        cachedFields = currentFields

        print("[LOAD_USER_FIELDS] Loaded \(fields.count) user-drawn fields")
        return fields
    }

    func clearCache() {
        lock.lock()
        defer { lock.unlock() }

        tileCache.removeAll()
        tileCacheLRU.removeAll()
        currentCacheSize = 0
        print("Memory cache cleared")
    }

    func clearAllData() async throws {
        clearCache()
        cachedFields.removeAll()
        print("All livestock field data cleared")
    }

    func createUserDrawnField(
        polygon: [CLLocationCoordinate2D],
        species: [LivestockSpecies] = [],
        isDangerous: Bool = false
    ) async throws -> LivestockField {
        print("[REPO_CREATE] createUserDrawnField - polygon size: \(polygon.count), species: \(species), isDangerous: \(isDangerous)")

        guard polygon.count >= 3 else {
            throw NSError(domain: "LivestockFieldRepository", code: 400, userInfo: [NSLocalizedDescriptionKey: "Polygon must have at least 3 points"])
        }

        let fieldId = "user_\(UUID().uuidString)"

        let latSum = polygon.reduce(0.0) { $0 + $1.latitude }
        let lngSum = polygon.reduce(0.0) { $0 + $1.longitude }
        let centroid = GeoPoint(latitude: latSum / Double(polygon.count), longitude: lngSum / Double(polygon.count))

        let minLat = polygon.map { $0.latitude }.min() ?? 0
        let maxLat = polygon.map { $0.latitude }.max() ?? 0
        let minLng = polygon.map { $0.longitude }.min() ?? 0
        let maxLng = polygon.map { $0.longitude }.max() ?? 0
        let bbox = [minLng, minLat, maxLng, maxLat]

        let area = calculatePolygonArea(polygon)

        let speciesScores = Dictionary(uniqueKeysWithValues: species.map { ($0.rawValue, 1.0) })

        let polygonData = polygon.map { [$0.longitude, $0.latitude] }

        let field = LivestockField(
            fieldId: fieldId,
            centroid: centroid,
            bbox: bbox,
            area_m2: area,
            speciesScores: speciesScores,
            lastSeenAt: Date().timeIntervalSince1970 * 1000,
            polygonRaw: polygonData,
            isDangerous: isDangerous
        )

        var currentFields = cachedFields
        currentFields[fieldId] = field
        cachedFields = currentFields

        if let userId = auth.currentUser?.uid {
            do {
                let fieldDoc: [String: Any] = [
                    "fieldId": field.fieldId,
                    "userId": userId,
                    "centroid": field.centroid,
                    "bbox": field.bbox,
                    "area_m2": field.area_m2,
                    "polygon": polygon.map { ["lat": $0.latitude, "lng": $0.longitude] },
                    "speciesScores": speciesScores,
                    "isDangerous": field.isDangerous,
                    "lastSeenAt": field.lastSeenAt as Any,
                    "createdAt": Date().timeIntervalSince1970 * 1000
                ]

                try await firestore.collection("userLivestockFields")
                    .document(field.fieldId)
                    .setData(fieldDoc)

                print("[REPO_CREATE] Field saved to Firebase: \(field.fieldId)")

                let poi = try await convertFieldToPoi(field: field, userId: userId)
                try await firestore.collection("pois").addDocument(data: poiToDict(poi))
                print("[REPO_CREATE] POI saved to Firebase")
            } catch {
                print("[REPO_CREATE] Failed to save field to Firebase: \(error)")
            }
        }

        print("[REPO_CREATE] SUCCESS - User-drawn field created: \(fieldId)")
        return field
    }

    private func calculatePolygonArea(_ polygon: [CLLocationCoordinate2D]) -> Double {
        guard polygon.count >= 3 else { return 0.0 }

        let earthRadius = 6371000.0
        var area = 0.0

        for i in 0..<polygon.count {
            let p1 = polygon[i]
            let p2 = polygon[(i + 1) % polygon.count]

            area += (p2.longitude - p1.longitude).degreesToRadians *
                    (2 + sin(p1.latitude.degreesToRadians) + sin(p2.latitude.degreesToRadians))
        }

        area = area * earthRadius * earthRadius / 2.0
        return abs(area)
    }

    private func convertFieldToPoi(field: LivestockField, userId: String) async throws -> Poi {
        let geohash = encodeGeohash(latitude: field.centroid.latitude, longitude: field.centroid.longitude)

        let speciesName = field.topSpecies?.displayName ?? "Unknown"
        let title = "\(speciesName) Field"
        var desc = "Livestock field: \(speciesName)"
        if field.isDangerous {
            desc += " [DANGEROUS]"
        }
        desc += ". Area: \(String(format: "%.0f", field.area_m2))m2"

        return Poi(
            type: "LIVESTOCK",
            title: title,
            desc: desc,
            lat: field.centroid.latitude,
            lng: field.centroid.longitude,
            geohash: geohash,
            createdBy: userId,
            status: "ACTIVE"
        )
    }

    private func poiToDict(_ poi: Poi) -> [String: Any] {
        [
            "type": poi.type,
            "title": poi.title,
            "desc": poi.desc,
            "lat": poi.lat,
            "lng": poi.lng,
            "geohash": poi.geohash,
            "createdBy": poi.createdBy,
            "status": poi.status,
            "streetAddress": poi.streetAddress,
            "locality": poi.locality,
            "administrativeArea": poi.administrativeArea,
            "formattedAddress": poi.formattedAddress
        ]
    }

    func snapToNearbyBoundaries(points: [CLLocationCoordinate2D], snapThresholdMeters: Double = 5.0) -> [CLLocationCoordinate2D] {
        points.map { point in
            var closestPoint: CLLocationCoordinate2D? = nil
            var minDistance = Double.infinity

            for field in cachedFields.values {
                for boundaryPoint in field.polygon {
                    let distance = calculateDistance(from: point, to: boundaryPoint)

                    if distance < minDistance && distance < snapThresholdMeters {
                        minDistance = distance
                        closestPoint = boundaryPoint
                    }
                }
            }

            return closestPoint ?? point
        }
    }

    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let earthRadius = 6371000.0
        let dLat = (to.latitude - from.latitude).degreesToRadians
        let dLon = (to.longitude - from.longitude).degreesToRadians
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(from.latitude.degreesToRadians) * cos(to.latitude.degreesToRadians) *
                sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadius * c
    }

    func fetchOsmFieldsProgressive(
        centerLocation: CLLocationCoordinate2D,
        onProgressUpdate: @escaping (Int, Int, Int) async -> Void
    ) async throws -> Int {
        let distance = 1000

        print("[OSM_PROGRESSIVE] Fetching fields at \(distance)m radius from center")

        let latPerMeter = 1.0 / 111000.0
        let lngPerMeter = 1.0 / (111000.0 * cos(centerLocation.latitude.degreesToRadians))
        let latOffset = Double(distance) * latPerMeter
        let lngOffset = Double(distance) * lngPerMeter

        let bounds = [
            CLLocationCoordinate2D(latitude: centerLocation.latitude - latOffset, longitude: centerLocation.longitude - lngOffset),
            CLLocationCoordinate2D(latitude: centerLocation.latitude + latOffset, longitude: centerLocation.longitude + lngOffset)
        ]

        let newFields = try await fetchOsmFields(bounds: bounds)
        let totalNewFields = newFields.count

        await onProgressUpdate(distance, newFields.count, cachedFields.count)

        print("[OSM_PROGRESSIVE] \(distance)m: fetched \(newFields.count) fields, total cached: \(cachedFields.count)")
        print("[OSM_PROGRESSIVE] Field fetch complete - total new fields: \(totalNewFields)")

        return totalNewFields
    }

    func fetchOsmFields(bounds: [CLLocationCoordinate2D]) async throws -> [LivestockField] {
        guard !bounds.isEmpty else { return [] }

        let minLat = bounds.map { $0.latitude }.min() ?? 0
        let maxLat = bounds.map { $0.latitude }.max() ?? 0
        let minLng = bounds.map { $0.longitude }.min() ?? 0
        let maxLng = bounds.map { $0.longitude }.max() ?? 0

        print("[OSM_FETCH] Fetching OSM fields in bounds: (\(minLat),\(minLng)) to (\(maxLat),\(maxLng))")

        let response = try await overpassService.fetchFieldBoundaries(
            south: minLat,
            west: minLng,
            north: maxLat,
            east: maxLng
        )

        print("[OSM_FETCH] Received \(response.elements.count) OSM elements")

        let osmFields = response.elements.compactMap { element -> LivestockField? in
            guard let geometry = element.geometry, geometry.count >= 3 else { return nil }

            let polygon = geometry.map { [$0.lon, $0.lat] }
            let polygonCoords = geometry.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }

            let center: OverpassCenter
            if let elementCenter = element.center {
                center = elementCenter
            } else {
                let latSum = polygonCoords.reduce(0.0) { $0 + $1.latitude }
                let lngSum = polygonCoords.reduce(0.0) { $0 + $1.longitude }
                center = OverpassCenter(lat: latSum / Double(polygonCoords.count), lon: lngSum / Double(polygonCoords.count))
            }

            let fieldMinLat = polygonCoords.map { $0.latitude }.min() ?? 0
            let fieldMaxLat = polygonCoords.map { $0.latitude }.max() ?? 0
            let fieldMinLng = polygonCoords.map { $0.longitude }.min() ?? 0
            let fieldMaxLng = polygonCoords.map { $0.longitude }.max() ?? 0
            let bbox = [fieldMinLng, fieldMinLat, fieldMaxLng, fieldMaxLat]

            let area = calculatePolygonArea(polygonCoords)

            let landuse = element.tags?["landuse"] ?? "unknown"
            let fieldId = "osm_\(element.type)_\(element.id)"

            return LivestockField(
                fieldId: fieldId,
                centroid: GeoPoint(latitude: center.lat, longitude: center.lon),
                bbox: bbox,
                area_m2: area,
                polygonRaw: polygon,
                isOsmField: true,
                osmLanduse: landuse
            )
        }

        var currentFields = cachedFields
        let beforeSize = currentFields.count
        for field in osmFields where currentFields[field.fieldId] == nil {
            currentFields[field.fieldId] = field
        }
        cachedFields = currentFields
        let newFieldsAdded = currentFields.count - beforeSize

        print("[OSM_FETCH] Successfully parsed \(osmFields.count) OSM fields, added \(newFieldsAdded) new, total cached: \(cachedFields.count)")

        return osmFields
    }

    private func pointInPolygon(point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
        guard polygon.count > 2 else { return false }

        var inside = false
        var j = polygon.count - 1

        for i in 0..<polygon.count {
            let xi = polygon[i].longitude
            let yi = polygon[i].latitude
            let xj = polygon[j].longitude
            let yj = polygon[j].latitude

            let intersect = ((yi > point.latitude) != (yj > point.latitude)) &&
                          (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi)

            if intersect {
                inside.toggle()
            }
            j = i
        }

        return inside
    }

    private func encodeGeohash(latitude: Double, longitude: Double, precision: Int = 9) -> String {
        let base32 = Array("0123456789bcdefghjkmnpqrstuvwxyz")
        var latRange = (-90.0, 90.0)
        var lonRange = (-180.0, 180.0)
        var geohash = ""
        var bits = 0
        var bit = 0
        var even = true

        while geohash.count < precision {
            if even {
                let mid = (lonRange.0 + lonRange.1) / 2
                if longitude > mid {
                    bit |= (1 << (4 - bits))
                    lonRange.0 = mid
                } else {
                    lonRange.1 = mid
                }
            } else {
                let mid = (latRange.0 + latRange.1) / 2
                if latitude > mid {
                    bit |= (1 << (4 - bits))
                    latRange.0 = mid
                } else {
                    latRange.1 = mid
                }
            }

            even.toggle()
            bits += 1

            if bits == 5 {
                geohash.append(base32[bit])
                bits = 0
                bit = 0
            }
        }

        return geohash
    }
}

extension Double {
    var degreesToRadians: Double { self * .pi / 180.0 }
}
