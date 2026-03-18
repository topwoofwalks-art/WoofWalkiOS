import SwiftUI
import MapKit
import CoreLocation
import FirebaseFirestore

// MARK: - Walk Console State

private enum WalkConsolePhase {
    case ready
    case walking
    case paused
    case completed
}

// MARK: - Business Walk Console Screen

struct BusinessWalkConsoleScreen: View {
    let bookingId: String

    @StateObject private var bookingRepo = BookingRepository()
    @ObservedObject private var walkTracking = WalkTrackingService.shared

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var booking: Booking?
    @State private var phase: WalkConsolePhase = .ready
    @State private var walkNote: String = ""
    @State private var showAddNoteSheet = false
    @State private var showCompleteConfirmation = false
    @State private var showPhotoCapture = false
    @State private var walkNotes: [String] = []
    @State private var capturedPhotos: [UIImage] = []
    @State private var completionRecord: LocalWalkRecord?
    @State private var isLoadingBooking = true
    @State private var errorMessage: String?

    // MARK: - Theme

    private let tealAccent = Color(red: 0.6, green: 0.9, blue: 0.9)
    private let darkTeal = Color.turquoise30

    private var cardBackground: Color {
        colorScheme == .dark ? Color.neutral20 : Color(.systemGray6)
    }

    private var surfaceBackground: Color {
        colorScheme == .dark ? Color.neutral10 : Color(.systemBackground)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            surfaceBackground.ignoresSafeArea()

            if isLoadingBooking {
                ProgressView("Loading booking...")
                    .foregroundColor(.white)
            } else if let booking = booking {
                VStack(spacing: 0) {
                    bookingHeader(booking)

                    if phase == .completed, let record = completionRecord {
                        completionSummary(booking: booking, record: record)
                    } else {
                        mapSection
                        statsBar
                        controlPanel(booking)
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text(errorMessage ?? "Booking not found")
                        .font(.headline)
                        .foregroundColor(.white)
                    Button("Go Back") { dismiss() }
                        .buttonStyle(.borderedProminent)
                        .tint(darkTeal)
                }
            }
        }
        .navigationTitle("Walk Console")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadBooking()
        }
        .sheet(isPresented: $showAddNoteSheet) {
            addNoteSheet
        }
        .sheet(isPresented: $showPhotoCapture) {
            ImagePickerView(image: Binding(
                get: { nil },
                set: { img in
                    if let img = img {
                        capturedPhotos.append(img)
                    }
                }
            ), sourceType: .camera)
        }
        .alert("Complete Walk", isPresented: $showCompleteConfirmation) {
            Button("Complete", role: .destructive) {
                completeWalk()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to end this walk? This action cannot be undone.")
        }
    }

    // MARK: - Load Booking

    private func loadBooking() async {
        isLoadingBooking = true
        do {
            let fetched = try await bookingRepo.fetchBooking(bookingId: bookingId)
            booking = fetched
        } catch {
            errorMessage = "Failed to load booking: \(error.localizedDescription)"
            print("[WalkConsole] Error loading booking: \(error)")
        }
        isLoadingBooking = false
    }

    // MARK: - Booking Header

    private func bookingHeader(_ booking: Booking) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Client avatar placeholder
                Circle()
                    .fill(darkTeal.opacity(0.3))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(booking.clientName.prefix(1)).uppercased())
                            .font(.headline)
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(booking.clientName)
                        .font(.headline)
                        .foregroundColor(.white)
                    HStack(spacing: 6) {
                        Image(systemName: "pawprint.fill")
                            .font(.caption)
                            .foregroundColor(tealAccent)
                        Text(booking.dogName)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }

                Spacer()

                // Service type badge
                serviceTypeBadge(booking.serviceTypeEnum)
            }

            // Special instructions if any
            if let instructions = booking.specialInstructions, !instructions.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text(instructions)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.15))
                )
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private func serviceTypeBadge(_ type: BookingServiceType) -> some View {
        HStack(spacing: 4) {
            Image(systemName: type.icon)
                .font(.caption)
            Text(type.displayName)
                .font(.caption.bold())
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(darkTeal)
        )
    }

    // MARK: - Map Section

    private var mapSection: some View {
        ZStack(alignment: .topLeading) {
            if #available(iOS 17.0, *) {
                Map {
                    // Current location marker
                    if let location = walkTracking.trackingState.polyline.last {
                        Annotation("You", coordinate: location) {
                            Circle()
                                .fill(tealAccent)
                                .frame(width: 14, height: 14)
                                .overlay(
                                    Circle()
                                        .stroke(.white, lineWidth: 2)
                                )
                                .shadow(radius: 4)
                        }
                    }

                    // Route polyline
                    if walkTracking.trackingState.polyline.count >= 2 {
                        MapPolyline(coordinates: walkTracking.trackingState.polyline)
                            .stroke(tealAccent, lineWidth: 4)
                    }
                }
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
            } else {
                Map(coordinateRegion: .constant(MKCoordinateRegion(
                    center: walkTracking.trackingState.polyline.last ?? CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 250)

            // GPS quality indicator
            if walkTracking.trackingState.isTracking {
                gpsQualityBadge
                    .padding(12)
            }
        }
    }

    private var gpsQualityBadge: some View {
        let quality = walkTracking.trackingState.gpsQuality
        let color: Color = {
            switch quality {
            case .excellent, .good: return .green
            case .fair: return .yellow
            case .poor: return .red
            case .unknown: return .gray
            }
        }()

        return HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("GPS")
                .font(.caption2.bold())
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.6))
        )
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: 0) {
            statItem(
                value: FormatUtils.formatDuration(walkTracking.trackingState.durationSeconds),
                label: "Duration",
                icon: "clock"
            )

            Divider()
                .frame(height: 32)
                .background(Color.white.opacity(0.2))

            statItem(
                value: FormatUtils.formatDistance(walkTracking.trackingState.distanceMeters),
                label: "Distance",
                icon: "map"
            )

            Divider()
                .frame(height: 32)
                .background(Color.white.opacity(0.2))

            statItem(
                value: FormatUtils.formatSpeed(walkTracking.trackingState.currentPaceKmh),
                label: "Pace",
                icon: "speedometer"
            )
        }
        .padding(.vertical, 12)
        .background(cardBackground)
    }

    private func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(tealAccent)
                Text(value)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Control Panel

    private func controlPanel(_ booking: Booking) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                // Primary action button
                primaryActionButton

                // Secondary actions (only during walk)
                if phase == .walking || phase == .paused {
                    secondaryActions
                }

                // Walk notes display
                if !walkNotes.isEmpty {
                    notesSection
                }

                // Photos display
                if !capturedPhotos.isEmpty {
                    photosSection
                }

                Spacer(minLength: 20)
            }
            .padding(16)
        }
    }

    private var primaryActionButton: some View {
        Group {
            switch phase {
            case .ready:
                Button(action: startWalk) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.body)
                        Text("Start Walk")
                            .font(.body.bold())
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(darkTeal)
                    )
                }

            case .walking:
                HStack(spacing: 12) {
                    Button(action: pauseWalk) {
                        HStack(spacing: 6) {
                            Image(systemName: "pause.fill")
                            Text("Pause")
                                .font(.body.bold())
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.orange)
                        )
                    }

                    Button(action: { showCompleteConfirmation = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Complete")
                                .font(.body.bold())
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.green)
                        )
                    }
                }

            case .paused:
                HStack(spacing: 12) {
                    Button(action: resumeWalk) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                            Text("Resume")
                                .font(.body.bold())
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(darkTeal)
                        )
                    }

                    Button(action: { showCompleteConfirmation = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Complete")
                                .font(.body.bold())
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.green)
                        )
                    }
                }

            case .completed:
                EmptyView()
            }
        }
    }

    private var secondaryActions: some View {
        HStack(spacing: 12) {
            Button(action: { showAddNoteSheet = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "note.text.badge.plus")
                        .font(.subheadline)
                    Text("Add Note")
                        .font(.subheadline.bold())
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
            }

            Button(action: { showPhotoCapture = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "camera.fill")
                        .font(.subheadline)
                    Text("Photo (\(capturedPhotos.count))")
                        .font(.subheadline.bold())
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(tealAccent)
                Text("Walk Notes")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
            }

            ForEach(Array(walkNotes.enumerated()), id: \.offset) { index, note in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1).")
                        .font(.caption)
                        .foregroundColor(tealAccent)
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground)
        )
    }

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "photo.on.rectangle")
                    .foregroundColor(tealAccent)
                Text("Walk Photos (\(capturedPhotos.count))")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(capturedPhotos.enumerated()), id: \.offset) { _, photo in
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground)
        )
    }

    // MARK: - Add Note Sheet

    private var addNoteSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Add a note about this walk")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextEditor(text: $walkNote)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )

                Spacer()
            }
            .padding(16)
            .navigationTitle("Walk Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        walkNote = ""
                        showAddNoteSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if !walkNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            walkNotes.append(walkNote.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                        walkNote = ""
                        showAddNoteSheet = false
                    }
                    .disabled(walkNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Completion Summary

    private func completionSummary(booking: Booking, record: LocalWalkRecord) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Success icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.green)
                    .padding(.top, 24)

                Text("Walk Complete!")
                    .font(.title2.bold())
                    .foregroundColor(.white)

                // Stats summary cards
                VStack(spacing: 12) {
                    summaryRow(icon: "map", label: "Distance", value: record.formattedDistance)
                    summaryRow(icon: "clock", label: "Duration", value: record.formattedDuration)
                    summaryRow(icon: "speedometer", label: "Avg Speed", value: record.formattedSpeed)
                    summaryRow(icon: "flame", label: "Calories", value: "\(record.caloriesBurned) kcal")
                    summaryRow(icon: "arrow.up.right", label: "Elevation Gain",
                              value: String(format: "%.0f m", record.elevationGainMeters))
                    summaryRow(icon: "sterlingsign.circle", label: "Earnings",
                              value: String(format: "\u{00A3}%.2f", booking.price))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(cardBackground)
                )

                // Notes summary
                if !walkNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes (\(walkNotes.count))")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)

                        ForEach(Array(walkNotes.enumerated()), id: \.offset) { _, note in
                            Text("- \(note)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(cardBackground)
                    )
                }

                // Done button
                Button(action: { dismiss() }) {
                    Text("Done")
                        .font(.body.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(darkTeal)
                        )
                }
                .padding(.top, 8)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
        }
    }

    private func summaryRow(icon: String, label: String, value: String) -> some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(tealAccent)
                    .frame(width: 24)
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(.white)
        }
    }

    // MARK: - Walk Actions

    private func startWalk() {
        walkTracking.startTracking()
        phase = .walking

        // Update booking status to IN_PROGRESS
        guard let bookingId = booking?.id else { return }
        Task {
            do {
                try await bookingRepo.updateBookingStatus(bookingId: bookingId, status: .inProgress)
                print("[WalkConsole] Booking \(bookingId) set to IN_PROGRESS")
            } catch {
                print("[WalkConsole] Failed to update booking status: \(error)")
            }
        }
    }

    private func pauseWalk() {
        walkTracking.pauseTracking()
        phase = .paused
    }

    private func resumeWalk() {
        walkTracking.resumeTracking()
        phase = .walking
    }

    private func completeWalk() {
        let record = walkTracking.stopTracking()
        completionRecord = record
        phase = .completed

        // Update booking status to COMPLETED
        guard let bookingId = booking?.id else { return }
        Task {
            do {
                try await bookingRepo.updateBookingStatus(bookingId: bookingId, status: .completed)
                print("[WalkConsole] Booking \(bookingId) set to COMPLETED")
            } catch {
                print("[WalkConsole] Failed to complete booking: \(error)")
            }

            // Save walk data to Firestore
            if let record = record {
                await saveWalkData(bookingId: bookingId, record: record)
            }
        }
    }

    private func saveWalkData(bookingId: String, record: LocalWalkRecord) async {
        let db = Firestore.firestore()
        let walkData: [String: Any] = [
            "bookingId": bookingId,
            "distanceMeters": record.distanceMeters,
            "durationSec": record.durationSec,
            "caloriesBurned": record.caloriesBurned,
            "elevationGainMeters": record.elevationGainMeters,
            "avgSpeedKmh": record.avgSpeedKmh,
            "polyline": record.polyline,
            "notes": walkNotes,
            "photoCount": capturedPhotos.count,
            "completedAt": Int64(Date().timeIntervalSince1970 * 1000),
            "earnings": booking?.price ?? 0.0
        ]

        do {
            try await db.collection("walkRecords").addDocument(data: walkData)
            print("[WalkConsole] Walk data saved for booking \(bookingId)")
        } catch {
            print("[WalkConsole] Failed to save walk data: \(error)")
        }
    }
}

// MARK: - Image Picker (Camera)

private struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView

        init(_ parent: ImagePickerView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage {
                parent.image = img
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BusinessWalkConsoleScreen(bookingId: "preview-booking-id")
    }
    .preferredColorScheme(.dark)
}
