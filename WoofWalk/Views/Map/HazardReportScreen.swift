import SwiftUI
import CoreLocation
import FirebaseAuth
import FirebaseFirestore

struct HazardReportScreen: View {
    @StateObject private var locationManager = LocationManager()
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: HazardType?
    @State private var selectedSeverity: HazardSeverity = .medium
    @State private var descriptionText: String = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Location status
                locationBanner

                // Hazard type selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Hazard Type")
                        .font(.headline)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(HazardType.allCases, id: \.self) { type in
                            hazardTypeCard(type)
                        }
                    }
                }

                // Severity picker
                VStack(alignment: .leading, spacing: 12) {
                    Text("Severity")
                        .font(.headline)

                    HStack(spacing: 8) {
                        ForEach(HazardSeverity.allCases, id: \.self) { severity in
                            severityChip(severity)
                        }
                    }
                }

                // Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description (optional)")
                        .font(.headline)

                    TextField("Describe the hazard...", text: $descriptionText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }

                // Expiry info
                if let type = selectedType {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text("This report will expire after \(type.expirationHours) hours")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }

                // Submit button
                Button(action: submitReport) {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "exclamationmark.triangle.fill")
                        }
                        Text("Submit Report")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedType != nil ? Color.red : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(selectedType == nil || isSubmitting)
            }
            .padding()
        }
        .navigationTitle("Report Hazard")
        .alert("Report Submitted", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("Thank you for keeping the community safe. Nearby walkers will be alerted.")
        }
    }

    // MARK: - Location Banner

    private var locationBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: locationManager.location != nil ? "location.fill" : "location.slash")
                .foregroundColor(locationManager.location != nil ? .green : .orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(locationManager.location != nil ? "Location available" : "Waiting for location...")
                    .font(.subheadline.bold())
                Text("The hazard will be pinned to your current location")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
    }

    // MARK: - Hazard Type Card

    private func hazardTypeCard(_ type: HazardType) -> some View {
        let isSelected = selectedType == type
        return Button { selectedType = type } label: {
            VStack(spacing: 8) {
                Image(systemName: type.iconName)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .red)
                Text(type.displayName)
                    .font(.caption.weight(.medium))
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.red : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.red : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Severity Chip

    private func severityChip(_ severity: HazardSeverity) -> some View {
        let isSelected = selectedSeverity == severity
        return Button { selectedSeverity = severity } label: {
            Text(severity.displayName)
                .font(.subheadline.weight(.medium))
                .foregroundColor(isSelected ? .white : severity.color)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? severity.color : severity.color.opacity(0.15))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Submit

    private func submitReport() {
        guard let type = selectedType,
              let location = locationManager.location else { return }
        isSubmitting = true

        let db = Firestore.firestore()
        let userId = Auth.auth().currentUser?.uid ?? "anonymous"
        let data: [String: Any] = [
            "type": type.rawValue,
            "severity": selectedSeverity.rawValue,
            "description": descriptionText,
            "lat": location.latitude,
            "lng": location.longitude,
            "reportedBy": userId,
            "reportedAt": Timestamp(date: Date()),
            "expiresAt": Timestamp(date: Date().addingTimeInterval(7 * 24 * 3600)),
            "status": "active",
            "voteUp": 0,
            "voteDown": 0
        ]

        db.collection("hazardReports").addDocument(data: data) { error in
            isSubmitting = false
            if let error = error {
                print("[HazardReport] Failed to save: \(error.localizedDescription)")
            } else {
                showSuccess = true
            }
        }
    }
}
