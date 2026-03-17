#if false
import SwiftUI
import MapKit

struct FieldDetailSheet: View {
    let field: LivestockField
    let userLocation: CLLocationCoordinate2D
    let zoom: Int
    let onDismiss: () -> Void
    let onSubmitSignal: (String, [LivestockSpecies], Bool, Bool, String?, String?, CLLocationCoordinate2D, Int) -> Void

    @State private var selectedSpecies: Set<LivestockSpecies> = []
    @State private var notes: String = ""
    @State private var photoUrl: String? = nil
    @State private var showPresent: Bool = true
    @State private var isDangerous: Bool = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerSection
                    Divider()
                    infoSection
                    Divider()
                    reportSection
                }
                .padding()
            }
            .navigationTitle("Livestock Field")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onDismiss() }
                }
            }
        }
        .onAppear {
            isDangerous = field.isDangerous
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Field Information")
                .font(.headline)

            HStack(spacing: 20) {
                InfoPill(label: "Confidence", value: field.confidenceLevel.displayName)
                InfoPill(label: "Area", value: formatArea(field.area_m2))
            }

            HStack(spacing: 20) {
                InfoPill(
                    label: "Top Species",
                    value: field.topSpecies?.displayName ?? "Unknown"
                )
                InfoPill(label: "Reports", value: "\(field.signalCount)")
            }

            if let lastSeen = field.lastSeenAt {
                Text("Last seen: \(formatTimestamp(lastSeen))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if field.hasDynamicWorldData {
                DynamicWorldSection(field: field)
            }
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if field.isDangerous {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text("Hazardous animals reported")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
                .padding(12)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }

    private var reportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Report Livestock")
                .font(.headline)

            HStack(spacing: 12) {
                Button {
                    showPresent = true
                } label: {
                    Text("Present")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(showPresent ? Color.accentColor : Color.gray.opacity(0.2))
                        .foregroundColor(showPresent ? .white : .primary)
                        .cornerRadius(8)
                }

                Button {
                    showPresent = false
                } label: {
                    Text("Not Present")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(!showPresent ? Color.accentColor : Color.gray.opacity(0.2))
                        .foregroundColor(!showPresent ? .white : .primary)
                        .cornerRadius(8)
                }
            }

            if showPresent {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select Species")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    SpeciesSelector(
                        selectedSpecies: $selectedSpecies,
                        showHazardToggle: false
                    )

                    Button {
                        isDangerous.toggle()
                    } label: {
                        HStack {
                            Image(systemName: isDangerous ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isDangerous ? .red : .gray)
                            Text(isDangerous ? "Marked as Hazardous" : "Mark as Hazardous")
                                .foregroundColor(isDangerous ? .red : .primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isDangerous ? Color.red.opacity(0.1) : Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Notes (optional)")
                    .font(.subheadline)
                    .fontWeight(.medium)

                TextEditor(text: $notes)
                    .frame(height: 80)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
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

            Button {
                onSubmitSignal(
                    field.fieldId,
                    Array(selectedSpecies),
                    showPresent,
                    isDangerous,
                    notes.isEmpty ? nil : notes,
                    photoUrl,
                    userLocation,
                    zoom
                )
            } label: {
                Text("Submit Report")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canSubmit ? Color.accentColor : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(!canSubmit)
        }
    }

    private var canSubmit: Bool {
        !showPresent || !selectedSpecies.isEmpty
    }

    private func formatArea(_ areaM2: Double) -> String {
        if areaM2 >= 10000 {
            return String(format: "%.1f ha", areaM2 / 10000)
        } else {
            return String(format: "%.0f m²", areaM2)
        }
    }

    private func formatTimestamp(_ timestamp: Int64) -> String {
        let now = Date().timeIntervalSince1970 * 1000
        let diff = now - Double(timestamp)
        let days = Int(diff / (24 * 60 * 60 * 1000))

        if days < 1 { return "Today" }
        if days < 2 { return "Yesterday" }
        if days < 7 { return "\(days) days ago" }
        if days < 30 { return "\(days / 7) weeks ago" }

        let date = Date(timeIntervalSince1970: Double(timestamp) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

struct InfoPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct DynamicWorldSection: View {
    let field: LivestockField

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Land Cover Analysis")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack(spacing: 12) {
                if let grass = field.dwGrassProbability {
                    LandCoverBar(label: "Grass", value: grass, color: .green)
                }
                if let crops = field.dwCropsProbability {
                    LandCoverBar(label: "Crops", value: crops, color: .yellow)
                }
                if let trees = field.dwTreesProbability {
                    LandCoverBar(label: "Trees", value: trees, color: .brown)
                }
            }

            if field.dwLivestockSuitability > 0 {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Suitability: \(Int(field.dwLivestockSuitability * 100))%")
                        .font(.caption)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct LandCoverBar: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .bottom) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 30, height: 60)

                Rectangle()
                    .fill(color)
                    .frame(width: 30, height: 60 * value)
            }
            .cornerRadius(4)

            Text(label)
                .font(.caption2)
            Text("\(Int(value * 100))%")
                .font(.caption2)
                .fontWeight(.bold)
        }
    }
}
#endif
