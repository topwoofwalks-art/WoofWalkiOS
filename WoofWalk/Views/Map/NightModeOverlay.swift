import SwiftUI

struct NightModeOverlay: View {
    @Binding var isEnabled: Bool

    var body: some View {
        if isEnabled {
            VStack {
                Spacer()

                HStack(spacing: 16) {
                    // Torch quick-access
                    Button(action: { TorchManager.shared.toggleTorch(true) }) {
                        VStack(spacing: 4) {
                            Image(systemName: "flashlight.on.fill")
                                .font(.title2)
                            Text("Torch")
                                .font(.caption2)
                        }
                        .foregroundColor(.white)
                        .frame(width: 70, height: 70)
                        .background(Circle().fill(.orange.opacity(0.8)))
                    }

                    // Visibility button
                    VStack(spacing: 4) {
                        Image(systemName: "eye.fill")
                            .font(.title2)
                        Text("High Vis")
                            .font(.caption2)
                    }
                    .foregroundColor(.white)
                    .frame(width: 70, height: 70)
                    .background(Circle().fill(.yellow.opacity(0.8)))

                    // Exit night mode
                    Button(action: { isEnabled = false }) {
                        VStack(spacing: 4) {
                            Image(systemName: "sun.max.fill")
                                .font(.title2)
                            Text("Day Mode")
                                .font(.caption2)
                        }
                        .foregroundColor(.white)
                        .frame(width: 70, height: 70)
                        .background(Circle().fill(.blue.opacity(0.8)))
                    }
                }
                .padding(.bottom, 100) // Above tab bar
            }
            .background(Color.black.opacity(0.3).ignoresSafeArea())
        }
    }
}
