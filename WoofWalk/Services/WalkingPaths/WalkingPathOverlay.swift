import SwiftUI
import MapKit

struct WalkingPathOverlay: View {
    let paths: [WalkingPath]
    @State private var selectedPath: WalkingPath?

    var body: some View {
        ForEach(paths) { path in
            PathPolyline(path: path)
                .stroke(pathColor(for: path), style: pathStyle(for: path))
                .onTapGesture {
                    selectedPath = path
                }
        }
        .sheet(item: $selectedPath) { path in
            PathDetailSheet(path: path)
        }
    }

    private func pathColor(for path: WalkingPath) -> Color {
        switch path.pathType {
        case .footway, .path, .pedestrian:
            return .blue
        case .cycleway:
            return .green
        case .steps:
            return .purple
        case .track, .bridleway:
            return .brown
        default:
            return .gray.opacity(0.5)
        }
    }

    private func pathStyle(for path: WalkingPath) -> StrokeStyle {
        switch path.pathType {
        case .footway, .path, .pedestrian:
            return StrokeStyle(lineWidth: 3, lineCap: .round, dash: [5, 3])
        case .cycleway:
            return StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [3, 2])
        case .steps:
            return StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 2])
        case .track, .bridleway:
            return StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [8, 4])
        default:
            return StrokeStyle(lineWidth: 2, lineCap: .round, dash: [10, 5])
        }
    }
}

struct PathPolyline: Shape {
    let path: WalkingPath

    func path(in rect: CGRect) -> Path {
        var swiftUIPath = Path()

        guard let firstCoord = path.coordinates.first else {
            return swiftUIPath
        }

        let mapPoint = MKMapPoint(firstCoord.clLocationCoordinate2D)
        swiftUIPath.move(to: CGPoint(x: mapPoint.x, y: mapPoint.y))

        for coord in path.coordinates.dropFirst() {
            let mapPoint = MKMapPoint(coord.clLocationCoordinate2D)
            swiftUIPath.addLine(to: CGPoint(x: mapPoint.x, y: mapPoint.y))
        }

        return swiftUIPath
    }
}

struct PathDetailSheet: View {
    let path: WalkingPath
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("Path Information") {
                    DetailRow(label: "Type", value: path.pathType.displayName)

                    if let name = path.name {
                        DetailRow(label: "Name", value: name)
                    }

                    DetailRow(
                        label: "Length",
                        value: String(format: "%.0f m", path.length)
                    )

                    if let surface = path.surface {
                        DetailRow(label: "Surface", value: surface.capitalized)
                    }
                }

                Section("Accessibility") {
                    if let wheelchair = path.osmTags["wheelchair"] {
                        DetailRow(label: "Wheelchair", value: wheelchair.capitalized)
                    }

                    if let stroller = path.osmTags["stroller"] {
                        DetailRow(label: "Stroller", value: stroller.capitalized)
                    }

                    if let width = path.osmTags["width"] {
                        DetailRow(label: "Width", value: "\(width) m")
                    }
                }

                Section("Quality") {
                    HStack {
                        Text("Path Score")
                        Spacer()
                        Text(String(format: "%.1f", path.qualityScore))
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Pedestrian Priority")
                        Spacer()
                        Text(path.isPedestrian ? "Yes" : "No")
                            .foregroundColor(path.isPedestrian ? .green : .secondary)
                    }
                }

                if let access = path.accessRestrictions {
                    Section("Access") {
                        Text(access.capitalized)
                            .foregroundColor(.orange)
                    }
                }
            }
            .navigationTitle("Path Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#if false
// DetailRow is defined elsewhere - wrapped to avoid invalid redeclaration
struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}
#endif

struct WalkingPathLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Path Types")
                .font(.headline)
                .padding(.bottom, 4)

            LegendItem(color: .blue, label: "Footpath / Pedestrian", dash: [5, 3])
            LegendItem(color: .green, label: "Cycle Path", dash: [3, 2])
            LegendItem(color: .brown, label: "Track / Bridleway", dash: [8, 4])
            LegendItem(color: .purple, label: "Steps", dash: [2, 2])
            LegendItem(color: .gray, label: "Road", dash: [10, 5])
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    let dash: [CGFloat]

    var body: some View {
        HStack {
            Rectangle()
                .fill(color)
                .frame(width: 30, height: 3)
                .overlay(
                    Rectangle()
                        .stroke(color, style: StrokeStyle(lineWidth: 3, dash: dash))
                )

            Text(label)
                .font(.caption)

            Spacer()
        }
    }
}
