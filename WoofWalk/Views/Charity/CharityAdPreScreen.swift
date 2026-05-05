import SwiftUI

/// Pre-walk charity ad prompt. Mirrors Android's
/// `CharityAdLoadingDialog.kt → CharityAdPreScreen` exactly: the user
/// is offered a rewarded interstitial in exchange for charity points;
/// "Watch Ad & Walk" presents the ad, "Skip Ad & Walk" starts the
/// walk immediately with no charity credit. Either way the walk
/// starts — never blocked.
struct CharityAdPreScreen: View {
    let charityName: String
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.fill")
                .font(.system(size: 36))
                .foregroundColor(.green)

            Text("Support \(charityName.isEmpty ? "your charity" : charityName) before your walk?")
                .font(.title3.bold())
                .multilineTextAlignment(.center)

            Text("Watch a short ad to earn charity credit for your chosen dog rescue. Your walk starts the moment the ad finishes.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.caption)
                Text("~30 seconds")
                    .font(.caption.weight(.semibold))
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(Color.green.opacity(0.15))
            )

            Button(action: onContinue) {
                HStack {
                    Image(systemName: "heart.fill")
                    Text("Watch Ad & Walk")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            }

            Button(action: onSkip) {
                HStack {
                    Image(systemName: "xmark")
                    Text("Skip Ad & Walk")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary, lineWidth: 1)
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 24)
    }
}
