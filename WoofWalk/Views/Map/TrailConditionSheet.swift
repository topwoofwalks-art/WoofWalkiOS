import SwiftUI
import CoreLocation

struct TrailConditionSheet: View {
    let userLocation: CLLocationCoordinate2D?
    let onSubmit: (TrailConditionType, Int, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: TrailConditionType?
    @State private var severity: Double = 1
    @State private var note: String = ""

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Condition type grid
                    Text("Trail Condition")
                        .font(.headline)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(TrailConditionType.allCases, id: \.self) { type in
                            conditionChip(type)
                        }
                    }

                    // Severity slider
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Severity")
                            .font(.headline)

                        HStack {
                            Text("Minor")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Slider(value: $severity, in: 1...3, step: 1)
                                .tint(severityColor)
                            Text("Severe")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text(severityLabel)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(severityColor)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }

                    // Note field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Note (optional)")
                            .font(.headline)

                        TextField("Add details about the condition...", text: $note, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...5)
                    }

                    // Submit button
                    Button(action: submit) {
                        HStack {
                            Image(systemName: "paperplane.fill")
                            Text("Report Condition")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedType != nil ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(selectedType == nil)
                }
                .padding()
            }
            .navigationTitle("Report Trail Condition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Condition Chip

    private func conditionChip(_ type: TrailConditionType) -> some View {
        let isSelected = selectedType == type
        return Button(action: { selectedType = type }) {
            VStack(spacing: 6) {
                Text(type.emoji)
                    .font(.title2)
                Text(type.displayName)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? type.color.opacity(0.2) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? type.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Severity Helpers

    private var severityLabel: String {
        switch Int(severity) {
        case 1: return "Minor"
        case 2: return "Moderate"
        case 3: return "Severe"
        default: return "Minor"
        }
    }

    private var severityColor: Color {
        switch Int(severity) {
        case 1: return .yellow
        case 2: return .orange
        case 3: return .red
        default: return .yellow
        }
    }

    // MARK: - Submit

    private func submit() {
        guard let type = selectedType else { return }
        onSubmit(type, Int(severity), note)
        dismiss()
    }
}
