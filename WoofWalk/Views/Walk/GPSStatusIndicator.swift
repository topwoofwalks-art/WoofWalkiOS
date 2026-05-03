import SwiftUI

/// Tiny RAG (red/amber/green) GPS health pill shown in the top-right of the
/// active walk screen. Tap to open `GPSStatusDetailSheet`.
///
/// Mirrors the Android `WalkScreen` indicator added in v7.6.x — surfaces
/// last-fix age, accuracy, and pipeline rejection counters so users + support
/// can diagnose "why is my distance off" without a USB cable.
struct GPSStatusIndicator: View {

    @ObservedObject var walkTracking: WalkTrackingService
    @ObservedObject var motionService: MotionActivityService

    @State private var showDetail = false
    @State private var nowTick = Date()

    /// Refresh tick so the dot color (which depends on fix-age) updates while
    /// the user is staring at it.
    private let timer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    var body: some View {
        Button {
            showDetail = true
        } label: {
            Circle()
                .fill(ragColor)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.7), lineWidth: 1)
                )
                .padding(6)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.35))
                )
        }
        .buttonStyle(.plain)
        .onReceive(timer) { _ in nowTick = Date() }
        .sheet(isPresented: $showDetail) {
            GPSStatusDetailSheet(walkTracking: walkTracking, motionService: motionService)
        }
    }

    /// Green: fresh fix < 10 s old + accuracy <= 20 m
    /// Amber: fix < 30 s old OR accuracy <= 50 m
    /// Red: stale or no-fix
    private var ragColor: Color {
        guard let last = walkTracking.lastAcceptedFixAt else { return .red }
        let age = nowTick.timeIntervalSince(last)
        let acc = walkTracking.trackingState.gpsAccuracy

        if age < 10, acc > 0, acc <= 20 {
            return .green
        }
        if age < 30, acc > 0, acc <= 50 {
            return .yellow
        }
        return .red
    }
}

/// Detail sheet shown when the RAG dot is tapped. Read-only snapshot of the
/// pipeline state — last fix age, accuracy, fusion mode, step count, counters.
struct GPSStatusDetailSheet: View {

    @ObservedObject var walkTracking: WalkTrackingService
    @ObservedObject var motionService: MotionActivityService
    @Environment(\.dismiss) private var dismiss
    @State private var nowTick = Date()
    private let refreshTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            List {
                Section("Last GPS Fix") {
                    row("Age", lastFixAgeText)
                    row("Accuracy", accuracyText)
                    row("Quality", String(describing: walkTracking.trackingState.gpsQuality))
                    row("Speed", String(format: "%.2f m/s", walkTracking.trackingState.currentSpeedMps))
                }

                Section("Motion") {
                    row("Permission", String(describing: motionService.motionAuthorisationStatus))
                    row("Stationary", motionService.isStationary ? "Yes" : "No")
                    row("Steps (this walk)", "\(motionService.stepCount)")
                    row("Last step at", lastStepText)
                }

                Section("Pipeline Counters") {
                    row("Received", "\(walkTracking.pipelineFixesReceived)")
                    row("Accepted", "\(walkTracking.pipelineFixesAccepted)")
                    row("Rejected (filter)", "\(walkTracking.pipelineFixesRejectedFilter)")
                    row("Rejected (step gate)", "\(walkTracking.pipelineFixesRejectedStepGate)")
                    row("Rejected (stationary)", "\(walkTracking.pipelineFixesRejectedStationaryGuard)")
                }
            }
            .navigationTitle("GPS Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onReceive(refreshTimer) { _ in nowTick = Date() }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
        }
    }

    private var lastFixAgeText: String {
        guard let last = walkTracking.lastAcceptedFixAt else { return "—" }
        let age = nowTick.timeIntervalSince(last)
        return String(format: "%.1fs ago", age)
    }

    private var accuracyText: String {
        let acc = walkTracking.trackingState.gpsAccuracy
        return acc > 0 ? String(format: "%.1f m", acc) : "—"
    }

    private var lastStepText: String {
        guard let stepAt = motionService.lastStepIncrementAt else { return "—" }
        let age = nowTick.timeIntervalSince(stepAt)
        return String(format: "%.1fs ago", age)
    }
}
