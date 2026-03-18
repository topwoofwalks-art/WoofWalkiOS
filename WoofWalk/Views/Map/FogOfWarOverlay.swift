import SwiftUI
import MapKit

struct FogOfWarOverlay: View {
    let exploredCoordinates: [CLLocationCoordinate2D]
    let revealRadius: Double // meters, default 100
    @Binding var isEnabled: Bool

    var body: some View {
        if isEnabled && !exploredCoordinates.isEmpty {
            // Show a banner indicating fog of war mode
            VStack {
                HStack {
                    Image(systemName: "eye.slash.fill")
                        .foregroundColor(.white)
                    Text("Fog of War")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(exploredCoordinates.count) points explored")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                    Button(action: { isEnabled = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.7)))

                Spacer()
            }
            .padding(.top, 80) // Below top controls
            .padding(.horizontal)
        }
    }
}

// MARK: - Fog of War Default Values

extension FogOfWarOverlay {
    init(exploredCoordinates: [CLLocationCoordinate2D], isEnabled: Binding<Bool>) {
        self.exploredCoordinates = exploredCoordinates
        self.revealRadius = 100
        self._isEnabled = isEnabled
    }
}

#Preview {
    ZStack {
        Color.green.ignoresSafeArea()
        FogOfWarOverlay(
            exploredCoordinates: [
                CLLocationCoordinate2D(latitude: 51.5, longitude: -0.1),
                CLLocationCoordinate2D(latitude: 51.501, longitude: -0.101)
            ],
            revealRadius: 100,
            isEnabled: .constant(true)
        )
    }
}
