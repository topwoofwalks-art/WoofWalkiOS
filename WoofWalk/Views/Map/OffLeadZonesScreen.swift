import SwiftUI
import MapKit

struct OffLeadZonesScreen: View {
    @StateObject private var locationManager = LocationManager()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var selectedFilter: ZoneType? = nil

    private let sampleZones: [OffLeadZone] = [
        OffLeadZone(id: "z1", name: "Victoria Park", type: "offLead", coordinates: [
            [51.5365, -0.0425], [51.5375, -0.0395], [51.5355, -0.0385], [51.5345, -0.0415]
        ]),
        OffLeadZone(id: "z2", name: "Hampstead Heath Fields", type: "offLead", coordinates: [
            [51.5615, -0.1640], [51.5625, -0.1610], [51.5605, -0.1600], [51.5595, -0.1630]
        ]),
        OffLeadZone(id: "z3", name: "Regent's Park Inner Circle", type: "leadRequired", coordinates: [
            [51.5275, -0.1530], [51.5285, -0.1500], [51.5265, -0.1490], [51.5255, -0.1520]
        ]),
        OffLeadZone(id: "z4", name: "Hyde Park Meadow", type: "caution", coordinates: [
            [51.5080, -0.1650], [51.5090, -0.1620], [51.5070, -0.1610], [51.5060, -0.1640]
        ]),
    ]

    private var filteredZones: [OffLeadZone] {
        guard let filter = selectedFilter else { return sampleZones }
        return sampleZones.filter { $0.zoneType == filter }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter bar
            filterBar
                .padding(.horizontal)
                .padding(.vertical, 8)

            // Map
            Map(coordinateRegion: $region, annotationItems: filteredZones) { zone in
                MapAnnotation(coordinate: zone.center) {
                    zoneAnnotation(zone)
                }
            }
            .frame(maxHeight: .infinity)

            // Zone list
            zoneList
        }
        .navigationTitle("Off-Lead Zones")
        .onAppear {
            if let loc = locationManager.location {
                region.center = loc
            }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "All", type: nil)
                ForEach(ZoneType.allCases, id: \.self) { type in
                    filterChip(label: type.displayName, type: type, color: type.color)
                }
            }
        }
    }

    private func filterChip(label: String, type: ZoneType?, color: Color = .accentColor) -> some View {
        let isSelected = selectedFilter == type
        return Button { selectedFilter = type } label: {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? color : color.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Zone Annotation

    private func zoneAnnotation(_ zone: OffLeadZone) -> some View {
        VStack(spacing: 2) {
            Image(systemName: zone.zoneType.iconName)
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(zone.zoneType.color))
                .shadow(radius: 2)
            Text(zone.name)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4).fill(.regularMaterial))
        }
    }

    // MARK: - Zone List

    private var zoneList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(filteredZones.count) zones nearby")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.top, 10)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredZones) { zone in
                        zoneRow(zone)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 200)
        }
        .background(Color(.systemBackground))
    }

    private func zoneRow(_ zone: OffLeadZone) -> some View {
        HStack(spacing: 12) {
            Image(systemName: zone.zoneType.iconName)
                .font(.title3)
                .foregroundColor(zone.zoneType.color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(zone.name)
                    .font(.subheadline.weight(.medium))
                Text(zone.zoneType.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
        .onTapGesture {
            withAnimation {
                region.center = zone.center
                region.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            }
        }
    }
}
