import SwiftUI

struct ProfilePortalLinkCard: View {
    var body: some View {
        Button(action: {
            if let url = URL(string: "https://woofwalk.app") {
                UIApplication.shared.open(url)
            }
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("WoofWalk Portal")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Manage bookings, invoices & more")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right.square")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
            .shadow(radius: 2)
        }
        .buttonStyle(.plain)
    }
}
