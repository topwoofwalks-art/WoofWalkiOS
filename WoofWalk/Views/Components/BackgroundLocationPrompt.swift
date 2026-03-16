import SwiftUI
import CoreLocation

struct BackgroundLocationPrompt: View {
    @Binding var isPresented: Bool
    let onEnable: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.fill.viewfinder")
                .font(.system(size: 48))
                .foregroundColor(.turquoise60)

            Text("Background Location")
                .font(.title3.bold())

            Text("Enable background location to keep tracking your walk even when the app is in the background. This ensures accurate distance and route recording.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 4) {
                benefitRow(icon: "figure.walk", text: "Accurate walk tracking")
                benefitRow(icon: "map", text: "Complete route recording")
                benefitRow(icon: "bell.badge", text: "Geofence notifications")
            }
            .padding(.vertical, 8)

            VStack(spacing: 12) {
                Button(action: {
                    onEnable()
                    isPresented = false
                }) {
                    Text("Enable Background Location")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.turquoise60))
                }

                Button(action: {
                    onSkip()
                    isPresented = false
                }) {
                    Text("Maybe Later")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 20).fill(.regularMaterial))
        .padding(16)
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.turquoise60)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
}
