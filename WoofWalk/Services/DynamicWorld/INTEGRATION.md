# Dynamic World Integration Guide

Quick start guide for integrating Dynamic World enrichment into WoofWalk iOS.

## Quick Integration

### 1. Add to Field Model

```swift
import Foundation

struct Field: Identifiable, Codable {
    let id: String
    let name: String
    let location: CLLocationCoordinate2D
    var dynamicWorldData: DynamicWorldData?

    var needsEnrichment: Bool {
        guard let data = dynamicWorldData else { return true }
        return data.isExpired || data.daysUntilExpiry < 7
    }
}
```

### 2. Field Detail View

```swift
import SwiftUI
import MapKit

struct FieldDetailView: View {
    let field: Field
    @StateObject private var viewModel = DynamicWorldViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                MapView(coordinate: field.location)
                    .frame(height: 200)

                if viewModel.isLoading {
                    ProgressView("Analyzing field...")
                } else if let error = viewModel.error {
                    ErrorView(error: error) {
                        await loadData()
                    }
                } else if let data = viewModel.enrichedData {
                    DynamicWorldDetailView(data: data)
                }
            }
        }
        .navigationTitle(field.name)
        .task {
            await loadData()
        }
        .refreshable {
            await refreshData()
        }
    }

    private func loadData() async {
        viewModel.loadCachedData(forFieldId: field.id)

        if viewModel.enrichedData == nil || field.needsEnrichment {
            await viewModel.enrichField(
                fieldId: field.id,
                lat: field.location.latitude,
                lng: field.location.longitude
            )
        }
    }

    private func refreshData() async {
        await viewModel.enrichField(
            fieldId: field.id,
            lat: field.location.latitude,
            lng: field.location.longitude,
            forceRefresh: true
        )
    }
}
```

### 3. Field List with Indicators

```swift
struct FieldListView: View {
    let fields: [Field]

    var body: some View {
        List(fields) { field in
            NavigationLink(destination: FieldDetailView(field: field)) {
                FieldRow(field: field)
            }
        }
        .navigationTitle("Fields")
    }
}

struct FieldRow: View {
    let field: Field

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(field.name)
                    .font(.headline)

                if let data = field.dynamicWorldData {
                    HStack(spacing: 8) {
                        SuitabilityBadge(score: data.livestockSuitability.score)

                        Text(data.dominantClass.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            if field.needsEnrichment {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .foregroundColor(.orange)
            }
        }
    }
}

struct SuitabilityBadge: View {
    let score: Double

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(ratingColor)
                .frame(width: 8, height: 8)

            Text(String(format: "%.0f", score))
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(ratingColor.opacity(0.2))
        .cornerRadius(8)
    }

    private var ratingColor: Color {
        switch score {
        case 0..<30: return .red
        case 30..<50: return .orange
        case 50..<70: return .yellow
        case 70...100: return .green
        default: return .gray
        }
    }
}
```

### 4. Map Overlay with Suitability

```swift
import MapKit

struct FieldMapView: View {
    let fields: [Field]
    @State private var region = MKCoordinateRegion()

    var body: some View {
        Map(coordinateRegion: $region, annotationItems: fields) { field in
            MapAnnotation(coordinate: field.location) {
                FieldMarker(field: field)
            }
        }
    }
}

struct FieldMarker: View {
    let field: Field

    var body: some View {
        ZStack {
            Circle()
                .fill(markerColor)
                .frame(width: 40, height: 40)
                .shadow(radius: 4)

            if let score = field.dynamicWorldData?.livestockSuitability.score {
                Text(String(format: "%.0f", score))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            } else {
                Image(systemName: "questionmark")
                    .foregroundColor(.white)
            }
        }
    }

    private var markerColor: Color {
        guard let score = field.dynamicWorldData?.livestockSuitability.score else {
            return .gray
        }

        switch score {
        case 0..<30: return .red
        case 30..<50: return .orange
        case 50..<70: return .yellow
        case 70...100: return .green
        default: return .gray
        }
    }
}
```

### 5. Background Enrichment

```swift
class FieldEnrichmentManager {
    static let shared = FieldEnrichmentManager()
    private let service = DynamicWorldService.shared

    func enrichFieldsInBackground(_ fields: [Field]) async {
        let needsEnrichment = fields.filter { $0.needsEnrichment }

        guard !needsEnrichment.isEmpty else {
            print("[ENRICHMENT] All fields up to date")
            return
        }

        print("[ENRICHMENT] Enriching \(needsEnrichment.count) fields in background")

        let fieldLocations = needsEnrichment.map { field in
            FieldLocation(
                fieldId: field.id,
                lat: field.location.latitude,
                lng: field.location.longitude
            )
        }

        do {
            let response = try await service.enrichFields(fieldLocations)
            print("[ENRICHMENT] Successfully enriched \(response.count) fields")

            NotificationCenter.default.post(
                name: .fieldsEnriched,
                object: nil,
                userInfo: ["count": response.count]
            )
        } catch {
            print("[ENRICHMENT] Failed: \(error.localizedDescription)")
        }
    }

    func scheduleBackgroundEnrichment() {
        Task {
            try? await Task.sleep(nanoseconds: 60_000_000_000)
            try? service.clearExpiredCache()
        }
    }
}

extension Notification.Name {
    static let fieldsEnriched = Notification.Name("fieldsEnriched")
}
```

### 6. App Launch Setup

```swift
@main
struct WoofWalkApp: App {
    init() {
        setupDynamicWorld()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func setupDynamicWorld() {
        Task {
            try? DynamicWorldService.shared.clearExpiredCache()
        }
    }
}
```

### 7. Settings Screen

```swift
struct SettingsView: View {
    @State private var cacheStats: (count: Int, sizeBytes: Int64, oldestDate: Date?)?

    var body: some View {
        Form {
            Section("Dynamic World Cache") {
                if let stats = cacheStats {
                    LabeledContent("Cached Fields", value: "\(stats.count)")
                    LabeledContent("Cache Size", value: formatBytes(stats.sizeBytes))

                    if let oldest = stats.oldestDate {
                        LabeledContent("Oldest Entry", value: formatDate(oldest))
                    }

                    Button("Clear Cache", role: .destructive) {
                        clearCache()
                    }

                    Button("Clear Expired Only") {
                        clearExpired()
                    }
                }
            }
        }
        .onAppear {
            loadCacheStats()
        }
    }

    private func loadCacheStats() {
        cacheStats = DynamicWorldCacheManager.shared.getCacheStats()
    }

    private func clearCache() {
        try? DynamicWorldService.shared.clearCache()
        loadCacheStats()
    }

    private func clearExpired() {
        try? DynamicWorldService.shared.clearExpiredCache()
        loadCacheStats()
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func formatDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
}
```

## Advanced Features

### Custom Suitability Weights

```swift
extension DynamicWorldService {
    func calculateCustomSuitability(
        _ probs: LandCoverProbabilities,
        weights: SuitabilityWeights
    ) -> Double {
        let score = (probs.grass * weights.grass) +
                   (probs.crops * weights.crops) +
                   (probs.shrubAndScrub * weights.shrub) +
                   (probs.trees * weights.trees) +
                   (probs.built * weights.built) +
                   (probs.water * weights.water)

        return max(0.0, min(100.0, score * 100.0))
    }
}

struct SuitabilityWeights {
    let grass: Double
    let crops: Double
    let shrub: Double
    let trees: Double
    let built: Double
    let water: Double

    static let livestock = SuitabilityWeights(
        grass: 0.40,
        crops: 0.25,
        shrub: 0.15,
        trees: 0.10,
        built: -0.50,
        water: -0.30
    )

    static let wildlife = SuitabilityWeights(
        grass: 0.25,
        crops: 0.10,
        shrub: 0.20,
        trees: 0.35,
        built: -0.60,
        water: 0.10
    )
}
```

### Historical Comparison

```swift
struct FieldHistoryView: View {
    let fieldId: String
    @State private var historicalData: [DynamicWorldData] = []

    var body: some View {
        List {
            ForEach(historicalData, id: \.fetchedAt) { data in
                VStack(alignment: .leading) {
                    Text(data.fetchedAt.formatted())
                        .font(.headline)

                    HStack {
                        SuitabilityBadge(score: data.livestockSuitability.score)
                        Text(data.dominantClass.capitalized)
                    }
                }
            }
        }
        .navigationTitle("Field History")
    }
}
```

### Batch Processing Progress

```swift
struct BatchEnrichmentView: View {
    let fields: [Field]
    @State private var progress = 0.0
    @State private var isProcessing = false

    var body: some View {
        VStack(spacing: 20) {
            ProgressView(value: progress, total: Double(fields.count))

            Text("\(Int(progress)) / \(fields.count) fields enriched")

            Button("Start Batch Enrichment") {
                Task {
                    await enrichBatch()
                }
            }
            .disabled(isProcessing)
        }
    }

    private func enrichBatch() async {
        isProcessing = true
        progress = 0

        for field in fields {
            do {
                _ = try await DynamicWorldService.shared.enrichSingleField(
                    fieldId: field.id,
                    lat: field.location.latitude,
                    lng: field.location.longitude
                )
                progress += 1
            } catch {
                print("Failed to enrich field: \(error)")
            }
        }

        isProcessing = false
    }
}
```

## Testing

```swift
import XCTest

class DynamicWorldTests: XCTestCase {
    func testSuitabilityCalculation() {
        let service = DynamicWorldService.shared

        let probs = LandCoverProbabilities(
            grass: 0.50,
            crops: 0.20,
            trees: 0.10,
            shrubAndScrub: 0.15,
            built: 0.03,
            water: 0.02
        )

        let score = service.calculateLivestockSuitability(probs)

        XCTAssertGreaterThanOrEqual(score, 0)
        XCTAssertLessThanOrEqual(score, 100)
        XCTAssertGreaterThan(score, 60)
    }

    func testCaching() async throws {
        let service = DynamicWorldService.shared

        try service.clearCache()

        let data = DynamicWorldData(
            fieldId: "test_field",
            centerLat: 40.7128,
            centerLng: -74.0060,
            landCover: LandCoverProbabilities(grass: 0.5),
            livestockSuitability: LivestockSuitability(
                score: 75.0,
                primaryType: "grass",
                confidence: 0.8
            ),
            dominantClass: "grass"
        )

        try DynamicWorldCacheManager.shared.cacheData(data)

        let cached = try service.getCachedData(forFieldId: "test_field")

        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.fieldId, "test_field")
    }
}
```

## Troubleshooting

### No Data Returned
- Verify Firebase Function is deployed
- Check function logs in Firebase Console
- Ensure service account has Earth Engine access

### Cache Not Working
- Check cache directory permissions
- Verify disk space available
- Clear cache and retry

### Slow Performance
- Enable batch processing for multiple fields
- Reduce region size (bbox parameter)
- Implement pagination for large field lists

## Performance Tips

1. **Preload on WiFi**: Schedule enrichment when on WiFi
2. **Batch Requests**: Group nearby fields in single request
3. **Cache Aggressively**: 30-day expiration is optimal
4. **Background Refresh**: Update stale data during idle time
5. **Progressive Loading**: Show cached data immediately, update in background
