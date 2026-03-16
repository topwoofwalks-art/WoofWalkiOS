import SwiftUI

struct AppUpdateBanner: View {
    let currentVersion: String
    let latestVersion: String
    let onUpdate: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.title2)
                .foregroundColor(.turquoise60)

            VStack(alignment: .leading, spacing: 2) {
                Text("Update Available")
                    .font(.subheadline.bold())
                Text("Version \(latestVersion) is now available")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Update", action: onUpdate)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.turquoise60))
                .foregroundColor(.white)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(radius: 2))
        .padding(.horizontal)
    }
}
