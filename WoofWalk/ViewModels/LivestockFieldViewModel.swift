import Foundation
import SwiftUI
import CoreLocation
import Combine

@MainActor
class LivestockFieldViewModel: ObservableObject {
    @Published var fields: [LivestockField] = []
    @Published var selectedField: LivestockField?
    @Published var isDrawingMode: Bool = false
    @Published var drawingVertices: [CLLocationCoordinate2D] = []
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var showFieldOverlays: Bool = true

    private var cancellables = Set<AnyCancellable>()
    private let radiusMeters: Double = 5000

    func loadFieldsNearby(center: CLLocationCoordinate2D, radius: Double? = nil) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let searchRadius = radius ?? radiusMeters
            fields = try await fetchFieldsFromFirestore(
                center: center,
                radiusMeters: searchRadius
            )
        } catch {
            self.error = "Failed to load livestock fields: \(error.localizedDescription)"
            print("Error loading fields: \(error)")
        }
    }

    func startDrawing() {
        isDrawingMode = true
        drawingVertices = []
    }

    func addVertex(_ coordinate: CLLocationCoordinate2D) {
        guard isDrawingMode else { return }
        drawingVertices.append(coordinate)
    }

    func undoLastVertex() {
        guard isDrawingMode, !drawingVertices.isEmpty else { return }
        drawingVertices.removeLast()
    }

    func finishDrawing(species: [LivestockSpecies], notes: String?) async throws {
        guard drawingVertices.count >= 3 else {
            throw FieldError.insufficientVertices
        }

        isLoading = true
        defer {
            isLoading = false
            isDrawingMode = false
            drawingVertices = []
        }

        do {
            let newField = try await createField(
                vertices: drawingVertices,
                species: species,
                notes: notes
            )

            fields.append(newField)
        } catch {
            self.error = "Failed to create field: \(error.localizedDescription)"
            throw error
        }
    }

    func cancelDrawing() {
        isDrawingMode = false
        drawingVertices = []
    }

    func selectField(_ field: LivestockField) {
        selectedField = field
    }

    func deselectField() {
        selectedField = nil
    }

    func addFieldSignal(fieldId: String, isAccurate: Bool) async {
        do {
            try await submitFieldSignal(fieldId: fieldId, isAccurate: isAccurate)

            if let index = fields.firstIndex(where: { $0.fieldId == fieldId }) {
                await loadFieldsNearby(center: fields[index].coordinate)
            }
        } catch {
            self.error = "Failed to submit signal: \(error.localizedDescription)"
        }
    }

    func toggleFieldOverlays() {
        showFieldOverlays.toggle()
    }

    func getFieldsInBounds(_ region: MKCoordinateRegion) -> [LivestockField] {
        fields.filter { field in
            isCoordinateInRegion(field.coordinate, region: region)
        }
    }

    private func isCoordinateInRegion(_ coordinate: CLLocationCoordinate2D, region: MKCoordinateRegion) -> Bool {
        let latDelta = abs(coordinate.latitude - region.center.latitude)
        let lngDelta = abs(coordinate.longitude - region.center.longitude)

        return latDelta <= region.span.latitudeDelta / 2 &&
               lngDelta <= region.span.longitudeDelta / 2
    }

    private func fetchFieldsFromFirestore(center: CLLocationCoordinate2D, radiusMeters: Double) async throws -> [LivestockField] {
        return []
    }

    private func createField(vertices: [CLLocationCoordinate2D], species: [LivestockSpecies], notes: String?) async throws -> LivestockField {
        throw FieldError.notImplemented
    }

    private func submitFieldSignal(fieldId: String, isAccurate: Bool) async throws {
    }
}

enum FieldError: LocalizedError {
    case insufficientVertices
    case invalidPolygon
    case notImplemented

    var errorDescription: String? {
        switch self {
        case .insufficientVertices:
            return "At least 3 points are required to create a field"
        case .invalidPolygon:
            return "The drawn polygon is invalid"
        case .notImplemented:
            return "This feature is not yet implemented"
        }
    }
}

import MapKit
