#if false
import SwiftUI
import MapKit
import PhotosUI

struct FieldFormSheet: View {
    @Environment(\.dismiss) var dismiss
    let polygon: [CLLocationCoordinate2D]
    let userLocation: CLLocationCoordinate2D
    let zoom: Int
    let onSubmit: ([LivestockSpecies], Bool, String?, String?) -> Void

    @State private var selectedSpecies: Set<LivestockSpecies> = []
    @State private var notes: String = ""
    @State private var isDangerous: Bool = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var showValidationError = false
    @State private var isSubmitting = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    fieldPreview
                    Divider()
                    speciesSection
                    Divider()
                    hazardSection
                    Divider()
                    notesSection
                    Divider()
                    photoSection
                    submitButton
                }
                .padding()
            }
            .navigationTitle("New Livestock Field")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Missing Information", isPresented: $showValidationError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please select at least one species before submitting.")
            }
        }
    }

    private var fieldPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Field Preview")
                .font(.headline)

            Map(interactionModes: []) {
                MapPolygon(coordinates: polygon)
                    .foregroundStyle(Color.blue.opacity(0.3))
                    .stroke(.blue, lineWidth: 2)
            }
            .frame(height: 150)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )

            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(.blue)
                Text("\(polygon.count - 1) vertices")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Area: \(formatArea(calculateArea()))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var speciesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Species")
                .font(.headline)

            Text("Choose all species present in this field")
                .font(.caption)
                .foregroundStyle(.secondary)

            SpeciesSelector(
                selectedSpecies: $selectedSpecies,
                showHazardToggle: false
            )
        }
    }

    private var hazardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Safety Information")
                .font(.headline)

            Button(action: { isDangerous.toggle() }) {
                HStack {
                    Image(systemName: isDangerous ? "checkmark.square.fill" : "square")
                        .foregroundStyle(isDangerous ? .red : .secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hazardous Animals")
                            .foregroundStyle(.primary)
                        Text("Animals are aggressive or dangerous to approach")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(isDangerous ? Color.red.opacity(0.1) : Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Additional Notes")
                .font(.headline)

            Text("Provide any relevant details about this field")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $notes)
                .frame(height: 100)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .onChange(of: notes) { newValue in
                    if newValue.count > 300 {
                        notes = String(newValue.prefix(300))
                    }
                }

            Text("\(notes.count)/300")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photo (Optional)")
                .font(.headline)

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                HStack {
                    if let photoData = photoData,
                       let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.secondary)
                            .frame(width: 80, height: 80)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(photoData == nil ? "Add Photo" : "Change Photo")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Help others identify livestock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            .onChange(of: selectedPhoto) { newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        photoData = data
                    }
                }
            }
        }
    }

    private var submitButton: some View {
        Button {
            submitForm()
        } label: {
            HStack {
                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Create Field")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canSubmit ? Color.accentColor : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .disabled(!canSubmit || isSubmitting)
    }

    private var canSubmit: Bool {
        !selectedSpecies.isEmpty && polygon.count >= 3
    }

    private func submitForm() {
        guard canSubmit else {
            showValidationError = true
            return
        }

        isSubmitting = true

        let photoUrl: String? = nil

        onSubmit(
            Array(selectedSpecies),
            isDangerous,
            notes.isEmpty ? nil : notes,
            photoUrl
        )

        dismiss()
    }

    private func calculateArea() -> Double {
        guard polygon.count >= 3 else { return 0 }

        var area: Double = 0
        let n = polygon.count - 1

        for i in 0..<n {
            let p1 = polygon[i]
            let p2 = polygon[(i + 1) % n]

            let lat1 = p1.latitude * .pi / 180
            let lat2 = p2.latitude * .pi / 180
            let lng1 = p1.longitude * .pi / 180
            let lng2 = p2.longitude * .pi / 180

            area += (lng2 - lng1) * (2 + sin(lat1) + sin(lat2))
        }

        area = abs(area * 6378137 * 6378137 / 2)
        return area
    }

    private func formatArea(_ areaM2: Double) -> String {
        if areaM2 >= 10000 {
            return String(format: "%.1f ha", areaM2 / 10000)
        } else {
            return String(format: "%.0f m²", areaM2)
        }
    }
}
#endif
