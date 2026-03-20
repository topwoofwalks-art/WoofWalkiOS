#if false
import SwiftUI
import MapKit

struct FieldDrawingMode: View {
    @Binding var vertices: [CLLocationCoordinate2D]
    @Binding var isDrawing: Bool
    let onComplete: ([CLLocationCoordinate2D]) -> Void
    let onCancel: () -> Void

    @State private var showValidationError = false

    var body: some View {
        VStack {
            Spacer()

            if isDrawing {
                drawingControls
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .shadow(radius: 8)
                    .padding()
            }
        }
    }

    private var drawingControls: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Drawing Field")
                    .font(.headline)
                Spacer()
                Text("\(vertices.count) vertices")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !vertices.isEmpty {
                DrawingPreview(vertices: vertices)
                    .frame(height: 100)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }

            HStack(spacing: 12) {
                Button(action: undoLastVertex) {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(vertices.isEmpty ? Color.gray.opacity(0.3) : Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(vertices.isEmpty)

                Button(action: cancelDrawing) {
                    Label("Cancel", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }

            Button(action: completeDrawing) {
                Label("Complete Field", systemImage: "checkmark.circle.fill")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canComplete ? Color.green : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(!canComplete)

            if !vertices.isEmpty && vertices.count < 3 {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                    Text("Tap at least \(3 - vertices.count) more point\(3 - vertices.count == 1 ? "" : "s") to create a field")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .alert("Invalid Field", isPresented: $showValidationError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("A field must have at least 3 vertices to form a valid polygon.")
        }
    }

    private var canComplete: Bool {
        vertices.count >= 3
    }

    private func undoLastVertex() {
        guard !vertices.isEmpty else { return }
        vertices.removeLast()
    }

    private func cancelDrawing() {
        vertices.removeAll()
        isDrawing = false
        onCancel()
    }

    private func completeDrawing() {
        guard vertices.count >= 3 else {
            showValidationError = true
            return
        }

        let closedPolygon = vertices + [vertices[0]]
        onComplete(closedPolygon)
        vertices.removeAll()
        isDrawing = false
    }
}

struct DrawingPreview: View {
    let vertices: [CLLocationCoordinate2D]

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                guard vertices.count >= 2 else { return }

                let bounds = calculateBounds()
                let path = createPath(in: size, bounds: bounds)

                context.stroke(
                    path,
                    with: .color(.blue),
                    lineWidth: 2
                )

                for vertex in normalizedVertices(in: size, bounds: bounds) {
                    context.fill(
                        Circle().path(in: CGRect(x: vertex.x - 3, y: vertex.y - 3, width: 6, height: 6)),
                        with: .color(.blue)
                    )
                }
            }
        }
    }

    private func calculateBounds() -> (minLat: Double, maxLat: Double, minLng: Double, maxLng: Double) {
        let minLat = vertices.map { $0.latitude }.min() ?? 0
        let maxLat = vertices.map { $0.latitude }.max() ?? 0
        let minLng = vertices.map { $0.longitude }.min() ?? 0
        let maxLng = vertices.map { $0.longitude }.max() ?? 0
        return (minLat, maxLat, minLng, maxLng)
    }

    private func normalizedVertices(in size: CGSize, bounds: (minLat: Double, maxLat: Double, minLng: Double, maxLng: Double)) -> [CGPoint] {
        let padding: CGFloat = 10
        let width = size.width - 2 * padding
        let height = size.height - 2 * padding

        let latRange = bounds.maxLat - bounds.minLat
        let lngRange = bounds.maxLng - bounds.minLng

        return vertices.map { coord in
            let x = padding + CGFloat((coord.longitude - bounds.minLng) / lngRange) * width
            let y = padding + CGFloat((bounds.maxLat - coord.latitude) / latRange) * height
            return CGPoint(x: x, y: y)
        }
    }

    private func createPath(in size: CGSize, bounds: (minLat: Double, maxLat: Double, minLng: Double, maxLng: Double)) -> Path {
        var path = Path()
        let points = normalizedVertices(in: size, bounds: bounds)

        guard !points.isEmpty else { return path }

        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }

        if vertices.count >= 3 {
            path.addLine(to: points[0])
        }

        return path
    }
}

struct MapDrawingOverlay: View {
    @Binding var vertices: [CLLocationCoordinate2D]

    var body: some View {
        ZStack {
            if vertices.count >= 2 {
                MapPolyline(coordinates: vertices)
                    .stroke(.blue, lineWidth: 3)
            }

            ForEach(vertices.indices, id: \.self) { index in
                Annotation("", coordinate: vertices[index]) {
                    Circle()
                        .fill(.blue)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(.white, lineWidth: 2)
                        )
                }
                .annotationTitles(.hidden)
            }

            if vertices.count >= 3 {
                MapPolyline(coordinates: [vertices.last!, vertices.first!])
                    .stroke(.blue.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
            }
        }
    }
}
#endif
