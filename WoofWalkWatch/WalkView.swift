import SwiftUI
import CoreLocation
import HealthKit

struct WalkView: View {
    @EnvironmentObject var sessionManager: WatchSessionManager
    @EnvironmentObject var settings: WatchSettings
    @StateObject private var walkTracker = WalkTracker()

    var body: some View {
        VStack(spacing: 4) {
            // Header
            HStack {
                Text("\u{1F9ED}")
                    .font(.system(size: 14))

                Spacer()

                Text("\u{1F415} WoofWalk")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color("TealLight"))

                Spacer()

                Text("\u{2709}")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 8)

            Spacer()

            if walkTracker.isWalking {
                // Duration
                Text(walkTracker.formattedDuration)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                // Distance
                Text(String(format: "%.2f km", walkTracker.distanceKm))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color("TealLight"))

                // Pace + Heart rate
                HStack(spacing: 12) {
                    if settings.paceDetectionEnabled {
                        Text("\(walkTracker.paceEmoji) \(walkTracker.currentPace)")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    }

                    if settings.heartRateEnabled && settings.hasHeartRate && walkTracker.heartRate > 0 {
                        Text("\u{2764}\u{FE0F} \(walkTracker.heartRate)")
                            .font(.system(size: 12))
                            .foregroundColor(Color.red)
                    }
                }
            } else {
                Text("\u{1F415}")
                    .font(.system(size: 32))

                if walkTracker.distanceKm > 0 {
                    Text("Last walk")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    Text(String(format: "%.2f km", walkTracker.distanceKm))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color("TealLight"))
                } else {
                    Text("Ready to walk")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            // DMS button
            if settings.dmsEnabled && sessionManager.dmsActive {
                Button("I'm OK") {
                    sessionManager.sendDmsOk()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }

            // Start/Stop
            Button(walkTracker.isWalking ? "Stop Walk" : "Start Walk") {
                if walkTracker.isWalking {
                    walkTracker.stopWalk()
                    sessionManager.syncWalkData(tracker: walkTracker)
                } else {
                    walkTracker.startWalk(
                        heartRateEnabled: settings.heartRateEnabled && settings.hasHeartRate
                    )
                    if settings.autoSaveCarLocation {
                        sessionManager.saveCarLocation(
                            lat: walkTracker.lastLat,
                            lng: walkTracker.lastLng
                        )
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(walkTracker.isWalking ? .red : Color("TealMedium"))

            // SOS
            if walkTracker.isWalking {
                Button("SOS") {
                    walkTracker.sendSOS()
                    sessionManager.sendSOS(lat: walkTracker.lastLat, lng: walkTracker.lastLng)
                    WKInterfaceDevice.current().play(.notification)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .font(.system(size: 14, weight: .bold))
            }
        }
        .padding(.vertical, 8)
    }
}
