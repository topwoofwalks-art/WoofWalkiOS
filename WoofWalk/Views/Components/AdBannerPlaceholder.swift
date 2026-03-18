import SwiftUI

struct AdBannerPlaceholder: View {
    var body: some View {
        HStack {
            Image(systemName: "pawprint.fill")
                .foregroundColor(.secondary)
            Text("WoofWalk Premium — Remove Ads")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text("Upgrade")
                .font(.caption.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.turquoise60))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.systemGray4)),
            alignment: .top
        )
    }
}
