import SwiftUI
import MapKit

struct LivestockMapIntegration: View {
    @StateObject private var viewModel = LivestockFieldViewModel()
    @State private var selectedField: LivestockField?
    @State private var showFieldDetail = false
    @State private var isDrawingMode = false
    @State private var drawingVertices: [CLLocationCoordinate2D] = []
    @State private var showFieldForm = false
    @State private var newFieldPolygon: [CLLocationCoordinate2D] = []
    @State private var livestockModeEnabled = false

    var userLocation: CLLocationCoordinate2D
    var currentZoom: Int

    var body: some View {
        ZStack {
            Map {
                if livestockModeEnabled {
                    LivestockFieldOverlay(
                        fields: viewModel.fields,
                        selectedFieldId: selectedField?.fieldId,
                        onFieldTap: { field in
                            selectedField = field
                            showFieldDetail = true
                        }
                    )

                    if isDrawingMode {
                        MapDrawingOverlay(vertices: $drawingVertices)
                    }
                }
            }
            .onTapGesture { location in
                if isDrawingMode {
                    let coordinate = convertToCoordinate(location)
                    drawingVertices.append(coordinate)
                }
            }

            VStack {
                HStack {
                    Spacer()
                    LivestockModeToggleButton(
                        isEnabled: $livestockModeEnabled,
                        onToggle: {
                            if livestockModeEnabled {
                                viewModel.loadFields(near: userLocation, radius: 5000)
                            }
                        }
                    )
                    .padding()
                }

                Spacer()

                if livestockModeEnabled && !isDrawingMode {
                    HStack {
                        Spacer()
                        LivestockFloatingButton {
                            isDrawingMode = true
                        }
                        .padding()
                    }
                }
            }

            if isDrawingMode {
                FieldDrawingMode(
                    vertices: $drawingVertices,
                    isDrawing: $isDrawingMode,
                    onComplete: { polygon in
                        newFieldPolygon = polygon
                        showFieldForm = true
                    },
                    onCancel: {
                        drawingVertices.removeAll()
                    }
                )
            }
        }
        .sheet(isPresented: $showFieldDetail) {
            if let field = selectedField {
                FieldDetailSheet(
                    field: field,
                    userLocation: userLocation,
                    zoom: currentZoom,
                    onDismiss: {
                        showFieldDetail = false
                        selectedField = nil
                    },
                    onSubmitSignal: { fieldId, species, present, isDangerous, notes, photoUrl, location, zoom in
                        viewModel.submitSignal(
                            fieldId: fieldId,
                            species: species,
                            present: present,
                            isDangerous: isDangerous,
                            notes: notes,
                            photoUrl: photoUrl,
                            location: location,
                            zoom: zoom
                        )
                        showFieldDetail = false
                        selectedField = nil
                    }
                )
            }
        }
        .sheet(isPresented: $showFieldForm) {
            FieldFormSheet(
                polygon: newFieldPolygon,
                userLocation: userLocation,
                zoom: currentZoom,
                onSubmit: { species, isDangerous, notes, photoUrl in
                    viewModel.createField(
                        polygon: newFieldPolygon,
                        species: species,
                        isDangerous: isDangerous,
                        notes: notes,
                        photoUrl: photoUrl,
                        location: userLocation,
                        zoom: currentZoom
                    )
                    newFieldPolygon.removeAll()
                }
            )
        }
    }

    private func convertToCoordinate(_ location: CGPoint) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: 0, longitude: 0)
    }
}
