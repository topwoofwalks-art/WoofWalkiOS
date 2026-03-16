import SwiftUI
import MapKit

struct DynamicWorldExampleView: View {
    @StateObject private var viewModel = DynamicWorldViewModel()
    @State private var selectedField: Field?

    let exampleFields = [
        Field(
            id: "pasture_1",
            name: "North Pasture",
            location: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        ),
        Field(
            id: "pasture_2",
            name: "South Meadow",
            location: CLLocationCoordinate2D(latitude: 40.7580, longitude: -73.9855)
        ),
        Field(
            id: "pasture_3",
            name: "East Field",
            location: CLLocationCoordinate2D(latitude: 40.7489, longitude: -73.9680)
        )
    ]

    var body: some View {
        NavigationView {
            List(exampleFields) { field in
                Button {
                    selectedField = field
                } label: {
                    FieldRowExample(field: field)
                }
            }
            .navigationTitle("Example Fields")
            .sheet(item: $selectedField) { field in
                FieldDetailExample(field: field)
            }
        }
    }
}

struct FieldRowExample: View {
    let field: Field

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(field.name)
                    .font(.headline)

                Text("Lat: \(field.location.latitude, specifier: "%.4f")")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Lng: \(field.location.longitude, specifier: "%.4f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
    }
}

struct FieldDetailExample: View {
    let field: Field
    @StateObject private var viewModel = DynamicWorldViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    fieldInfoSection

                    if viewModel.isLoading {
                        ProgressView("Analyzing field with Google Earth Engine...")
                            .padding()
                    } else if let error = viewModel.error {
                        errorSection(error: error)
                    } else if let data = viewModel.enrichedData {
                        enrichmentSection(data: data)
                    } else {
                        placeholderSection
                    }
                }
                .padding()
            }
            .navigationTitle(field.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await refreshData()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .task {
                await loadData()
            }
        }
    }

    private var fieldInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Field Information")
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Latitude")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.6f", field.location.latitude))
                        .font(.body)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Longitude")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.6f", field.location.longitude))
                        .font(.body)
                }
            }

            Map(coordinateRegion: .constant(
                MKCoordinateRegion(
                    center: field.location,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            ), annotationItems: [field]) { field in
                MapMarker(coordinate: field.location, tint: .blue)
            }
            .frame(height: 200)
            .cornerRadius(12)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    private func enrichmentSection(data: DynamicWorldData) -> some View {
        VStack(spacing: 16) {
            SuitabilityScoreView(
                suitability: data.livestockSuitability,
                lastUpdated: data.fetchedAt
            )
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)

            LandCoverChartView(probabilities: data.landCover)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)

            detailsGrid(data: data)

            recommendationsSection(data: data)
        }
    }

    private func detailsGrid(data: DynamicWorldData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analysis Details")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                DetailCard(
                    title: "Dominant Class",
                    value: data.dominantClass.capitalized,
                    icon: "leaf.fill",
                    color: .green
                )

                DetailCard(
                    title: "Confidence",
                    value: String(format: "%.0f%%", data.livestockSuitability.confidence * 100),
                    icon: "chart.bar.fill",
                    color: .blue
                )

                DetailCard(
                    title: "Grass Coverage",
                    value: String(format: "%.0f%%", data.landCover.grass * 100),
                    icon: "text.justify",
                    color: .green
                )

                DetailCard(
                    title: "Built Area",
                    value: String(format: "%.0f%%", data.landCover.built * 100),
                    icon: "building.2.fill",
                    color: .gray
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    private func recommendationsSection(data: DynamicWorldData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommendations")
                .font(.headline)

            ForEach(getRecommendations(for: data), id: \.self) { recommendation in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)

                    Text(recommendation)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    private func errorSection(error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Analysis Failed")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                Task {
                    await refreshData()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    private var placeholderSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)

            Text("Ready to Analyze")
                .font(.headline)

            Text("Tap the refresh button to analyze this field using satellite imagery.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Analyze Field") {
                Task {
                    await loadData()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    private func loadData() async {
        viewModel.loadCachedData(forFieldId: field.id)

        if viewModel.enrichedData == nil {
            await refreshData()
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

    private func getRecommendations(for data: DynamicWorldData) -> [String] {
        var recommendations: [String] = []

        let score = data.livestockSuitability.score

        if score >= 70 {
            recommendations.append("Excellent grazing conditions detected")
            recommendations.append("High grass coverage suitable for livestock")
        } else if score >= 50 {
            recommendations.append("Good conditions for moderate grazing")
            recommendations.append("Consider rotational grazing for best results")
        } else if score >= 30 {
            recommendations.append("Fair conditions, may need supplemental feed")
            recommendations.append("Monitor livestock carefully")
        } else {
            recommendations.append("Poor grazing conditions")
            recommendations.append("Consider alternative feeding strategies")
        }

        if data.landCover.water > 0.2 {
            recommendations.append("High water coverage - ensure livestock safety")
        }

        if data.landCover.built > 0.1 {
            recommendations.append("Built areas present - check for hazards")
        }

        if data.landCover.trees > 0.3 {
            recommendations.append("Good shade coverage available")
        }

        return recommendations
    }
}

struct DetailCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)

                Spacer()
            }

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct Field: Identifiable {
    let id: String
    let name: String
    let location: CLLocationCoordinate2D
    var dynamicWorldData: DynamicWorldData?
}

struct DynamicWorldExampleView_Previews: PreviewProvider {
    static var previews: some View {
        DynamicWorldExampleView()
    }
}
