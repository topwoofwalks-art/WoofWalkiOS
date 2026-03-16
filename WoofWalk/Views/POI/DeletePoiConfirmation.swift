import SwiftUI

struct DeletePoiConfirmation: View {
    let poi: POI
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.orange)

            Text("Report POI for Removal?")
                .font(.headline)

            Text("If 3 users report this \(poi.poiType.displayName), it will be automatically removed.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button("Cancel", action: onCancel)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.neutral90))

                Button("Report", action: onConfirm)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.red))
            }
        }
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 16).fill(.regularMaterial))
    }
}
