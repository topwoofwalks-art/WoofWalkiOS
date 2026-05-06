import SwiftUI
import MapKit
import CoreLocation
import PhotosUI
import UIKit

/// Walk Console screen for business walkers — 1:1 port of Android
/// `WalkConsoleScreen.kt`. Drives the entire walking-appointment UX:
///   - Pre-walk client brief (address, phone, key code, instructions)
///   - Map with planned route + live trail + POI markers
///   - Live stats overlay + route adherence indicator
///   - Dog check-in strip
///   - Walk control buttons (Start / Pause / Resume / End)
///   - Photo capture + Mark bin
///   - Walker note inline editor with quick-template chips
///   - Live-share sheet (Copy / Send / per-client WhatsApp + SMS rows)
///   - Walker-safety Watch Me sheet
///   - Incident log dialog
///
/// Backed by `WalkConsoleViewModel`. Single-booking entry: pass
/// `bookingIds = [bookingId]`. Group-walk entry: pass the full list.
struct BusinessWalkConsoleScreen: View {
    let bookingId: String
    let dogIds: [String]
    let bookingIds: [String]

    @StateObject private var viewModel = WalkConsoleViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var showPhotoPicker: Bool = false
    @State private var showWalkerSafetySheet: Bool = false
    @State private var showShareActivitySheet: Bool = false
    @State private var shareActivityText: String = ""
    @State private var summary: WalkConsoleSummary?

    /// Convenience: single-booking entry-point. Defaults the booking-ids
    /// list to `[bookingId]` for the navigation Route case.
    init(bookingId: String, dogIds: [String] = [], bookingIds: [String]? = nil) {
        self.bookingId = bookingId
        self.dogIds = dogIds
        self.bookingIds = bookingIds ?? [bookingId]
    }

    var body: some View {
        VStack(spacing: 0) {
            mapSection
                .frame(maxWidth: .infinity)
                .frame(height: UIScreen.main.bounds.height * 0.42)

            if viewModel.isTracking && !viewModel.dogProfiles.isEmpty {
                dogCheckInStrip
            }

            ScrollView {
                VStack(spacing: 12) {
                    if !viewModel.clientBriefs.isEmpty {
                        clientBriefCard(compact: viewModel.isTracking)
                    }

                    walkControlButtons

                    if viewModel.isTracking {
                        photoAndBinRow
                    }

                    if viewModel.isTracking, viewModel.shareUrl != nil {
                        walkerNoteRow
                    }

                    if !viewModel.photos.isEmpty {
                        photoThumbnailRow
                    }

                    if !viewModel.incidents.isEmpty {
                        incidentsSummaryCard
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Walk Console")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                }
            }
            if viewModel.isTracking {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.startSharingWalk()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(viewModel.isCreatingShareLink)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showWalkerSafetySheet = true
                    } label: {
                        ZStack(alignment: .bottomTrailing) {
                            Image(systemName: "shield")
                            if viewModel.walkerSafetyWatchActive {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 2, y: 2)
                            }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showIncidentLogDialog()
                    } label: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                }
            }
        }
        .task {
            viewModel.preloadDogProfiles(dogIds: dogIds)
            viewModel.loadClientBriefs(bookingIds: bookingIds)
        }
        .sheet(isPresented: $showPhotoPicker) {
            WalkConsolePhotoPicker { data in
                if let data = data {
                    viewModel.capturePhoto(imageData: data, caption: nil)
                }
                showPhotoPicker = false
            }
        }
        .sheet(isPresented: $showWalkerSafetySheet) {
            WalkerSafetySheet(
                currentlyActive: viewModel.walkerSafetyWatchActive,
                currentContact: viewModel.walkerSafetyContactName,
                onStart: { name, phone, returnAt in
                    viewModel.startWalkerSafetyWatch(
                        contactName: name,
                        contactPhone: phone,
                        expectedReturnAt: returnAt
                    ) { url in
                        if let url = url {
                            shareActivityText = "I'm out walking dogs — please look out for me. Watch live: \(url)"
                            showShareActivitySheet = true
                        }
                    }
                    showWalkerSafetySheet = false
                },
                onEnd: {
                    viewModel.endWalkerSafetyWatch()
                    showWalkerSafetySheet = false
                },
                onDismiss: { showWalkerSafetySheet = false }
            )
        }
        .sheet(isPresented: $viewModel.showShareSheet) {
            LiveShareBottomSheet(
                shareUrl: viewModel.shareUrl ?? "",
                bookingShareTargets: viewModel.bookingShareTargets,
                onDismiss: { viewModel.dismissShareSheet() },
                onShareSheetFor: { text in
                    shareActivityText = text
                    showShareActivitySheet = true
                }
            )
        }
        .sheet(isPresented: $viewModel.showBookingPicker) {
            BookingPickerSheet(
                candidates: viewModel.selectableBookings,
                selectedIds: viewModel.selectedBookingIds,
                isLoading: viewModel.isLoadingPicker,
                onToggle: { viewModel.toggleBookingSelection($0) },
                onConfirm: { viewModel.confirmBookingPicker() },
                onCancel: { viewModel.cancelBookingPicker() }
            )
        }
        .sheet(isPresented: $showShareActivitySheet) {
            ShareActivityView(text: shareActivityText)
        }
        .alert(
            "End Walk?",
            isPresented: $viewModel.showEndWalkDialog
        ) {
            Button("End Walk", role: .destructive) {
                viewModel.endWalk { summary in
                    self.summary = summary
                }
            }
            Button("Cancel", role: .cancel) {
                viewModel.dismissEndWalkDialog()
            }
        } message: {
            Text("Are you sure you want to end this walk? This action cannot be undone.")
        }
        .sheet(isPresented: $viewModel.showIncidentDialog) {
            IncidentLogDialog(
                onSubmit: { type, notes, severity in
                    viewModel.logIncident(type: type, notes: notes, severity: severity)
                },
                onDismiss: { viewModel.dismissIncidentDialog() }
            )
        }
        .sheet(item: Binding<DogCheckInTarget?>(
            get: {
                viewModel.pendingCheckInDogId.flatMap { id in
                    let name = viewModel.dogProfiles.first(where: { $0.id == id })?.name ?? "Dog"
                    return DogCheckInTarget(id: id, name: name)
                }
            },
            set: { newValue in
                if newValue == nil { viewModel.dismissCheckInDialog() }
            }
        )) { target in
            DogCheckInDialog(
                dogName: target.name,
                onConfirm: { note in viewModel.confirmDogCheckIn(note: note) },
                onDismiss: { viewModel.dismissCheckInDialog() }
            )
        }
        .alert(
            "Location Permission Required",
            isPresented: $viewModel.showLocationPermissionDialog
        ) {
            Button("OK") { viewModel.showLocationPermissionDialog = false }
        } message: {
            Text("Location access is needed to track your walk and record the route.")
        }
        .overlay(alignment: .bottom) {
            if let error = viewModel.error {
                ErrorBanner(text: error)
                    .padding(.bottom, 80)
                    .task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        viewModel.clearError()
                    }
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { summary != nil },
            set: { if !$0 { summary = nil } }
        )) {
            if let summary = summary {
                WalkSummaryScreen(summary: summary, onDone: {
                    self.summary = nil
                    dismiss()
                })
            }
        }
    }

    // MARK: - Map

    private var mapSection: some View {
        ZStack(alignment: .topLeading) {
            WalkConsoleMapView(
                currentLocation: viewModel.currentLocation,
                routePoints: viewModel.walkSession?.routePoints.map { $0.coordinate } ?? [],
                plannedRoute: viewModel.plannedRoute
            )

            VStack(alignment: .leading, spacing: 8) {
                if viewModel.isTracking {
                    LiveStatsOverlay(stats: viewModel.liveStats)
                }
            }
            .padding(16)

            if viewModel.isTracking, let adherence = viewModel.plannedRouteAdherence {
                VStack {
                    HStack {
                        Spacer()
                        RouteAdherenceIndicator(adherence: adherence)
                    }
                    Spacer()
                }
                .padding(16)
            }
        }
    }

    // MARK: - Dog check-in strip

    private var dogCheckInStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Dog Check-ins")
                    .font(.subheadline.bold())
                Spacer()
                Button("Check All") {
                    viewModel.checkInAllDogs()
                }
                .font(.subheadline)
            }
            .padding(.horizontal, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.dogProfiles) { dog in
                        DogCheckInChip(
                            dog: dog,
                            isCheckedIn: viewModel.checkedInDogs.contains(dog.id),
                            isLoading: viewModel.checkInInProgress.contains(dog.id),
                            onTap: { viewModel.requestDogCheckIn(dogId: dog.id) }
                        )
                    }
                }
                .padding(.horizontal, 12)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    // MARK: - Client brief

    private func clientBriefCard(compact: Bool) -> some View {
        let briefs = viewModel.clientBriefs
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "person.crop.circle")
                    .foregroundColor(.accentColor)
                Text(briefs.count == 1 ? "Visit details" : "\(briefs.count) clients")
                    .font(.subheadline.bold())
            }

            ForEach(Array(briefs.enumerated()), id: \.element.bookingId) { idx, brief in
                if idx > 0 {
                    Divider()
                }
                if compact {
                    HStack {
                        Text(brief.clientName)
                            .font(.body.weight(.semibold))
                        Spacer()
                        if let phone = brief.clientPhone {
                            Button {
                                openDial(phone)
                            } label: {
                                Label("Call", systemImage: "phone")
                                    .font(.caption)
                            }
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(brief.clientName)
                            .font(.body.weight(.semibold))
                        if !brief.dogNames.isEmpty {
                            Text(brief.dogNames.joined(separator: ", "))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if let address = brief.address {
                            Label(address, systemImage: "mappin.and.ellipse")
                                .font(.caption)
                        }
                        if let key = brief.keyCode {
                            Label("Key: \(key)", systemImage: "key.fill")
                                .font(.caption)
                                .monospaced()
                        }
                        if let instructions = brief.specialInstructions {
                            Text("\u{201C}\(instructions)\u{201D}")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if let phone = brief.clientPhone {
                            Button {
                                openDial(phone)
                            } label: {
                                Label("Call \(brief.clientName.components(separatedBy: " ").first ?? brief.clientName)", systemImage: "phone")
                                    .font(.subheadline)
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Walk control buttons

    private var walkControlButtons: some View {
        HStack(spacing: 8) {
            if !viewModel.isTracking {
                Button {
                    if bookingIds.count > 1 {
                        viewModel.startGroupWalk(bookingIds: bookingIds, dogIds: dogIds)
                    } else {
                        viewModel.startWalk(bookingId: bookingId, dogIds: dogIds)
                    }
                } label: {
                    Label("Start Walk", systemImage: "play.fill")
                        .font(.body.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canStartWalk)
            } else {
                if viewModel.isPaused {
                    Button {
                        viewModel.resumeWalk()
                    } label: {
                        Label("Resume", systemImage: "play.fill")
                            .font(.body.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        viewModel.pauseWalk()
                    } label: {
                        Label("Pause", systemImage: "pause.fill")
                            .font(.body.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                }
                Button {
                    viewModel.showEndWalkConfirmation()
                } label: {
                    Label("End Walk", systemImage: "stop.fill")
                        .font(.body.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
    }

    // MARK: - Photo + bin row

    private var photoAndBinRow: some View {
        HStack(spacing: 8) {
            Button {
                showPhotoPicker = true
            } label: {
                Label("Photo (\(viewModel.photos.count))", systemImage: "camera")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)

            Button {
                viewModel.quickAddBin()
            } label: {
                Label("Mark bin", systemImage: "trash")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Walker note row

    @State private var noteEditing: Bool = false
    @State private var noteDraft: String = ""

    private var walkerNoteRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "pencil.tip")
                    .foregroundColor(.accentColor)
                Text("Note for the client")
                    .font(.subheadline.bold())
                Spacer()
                if !noteEditing {
                    Button(viewModel.walkerNote?.isEmpty == false ? "Edit" : "Add") {
                        noteDraft = viewModel.walkerNote ?? ""
                        noteEditing = true
                    }
                    .font(.subheadline)
                }
            }

            if noteEditing {
                TextField(
                    "e.g. Bella was a star at the park today",
                    text: $noteDraft,
                    axis: .vertical
                )
                .lineLimit(3, reservesSpace: true)
                .textFieldStyle(.roundedBorder)
                .onChange(of: noteDraft) { newValue in
                    if newValue.count > 200 {
                        noteDraft = String(newValue.prefix(200))
                    }
                }
                Text("\(noteDraft.count)/200")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(WalkerNoteTemplate.allCases, id: \.self) { tmpl in
                            Button {
                                let phrase = tmpl.phrase
                                let combined = noteDraft.isEmpty
                                    ? phrase
                                    : "\(noteDraft.trimmingCharacters(in: .whitespaces)). \(phrase)"
                                noteDraft = String(combined.prefix(200))
                            } label: {
                                Text(tmpl.phrase)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(.systemGray5))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                HStack {
                    Spacer()
                    Button("Cancel") {
                        noteEditing = false
                        noteDraft = viewModel.walkerNote ?? ""
                    }
                    Button("Save") {
                        viewModel.setWalkerNote(noteDraft)
                        noteEditing = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if let note = viewModel.walkerNote, !note.isEmpty {
                Text("\u{201C}\(note)\u{201D}")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Photo thumbnails

    private var photoThumbnailRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.photos) { photo in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                        )
                }
            }
        }
    }

    // MARK: - Incidents card

    private var incidentsSummaryCard: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.red)
            Text("\(viewModel.incidents.count) incident(s) logged")
                .font(.body)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func openDial(_ phone: String) {
        let cleaned = phone.replacingOccurrences(of: " ", with: "")
        if let url = URL(string: "tel:\(cleaned)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Pending check-in target identifier

private struct DogCheckInTarget: Identifiable {
    let id: String
    let name: String
}

// MARK: - Walker note quick templates

private enum WalkerNoteTemplate: String, CaseIterable {
    case havingGreatTime
    case lotsOfEnergy
    case metAnotherDog
    case toiletStop
    case onLead
    case offLead
    case headingBack
    case almostHome

    var phrase: String {
        switch self {
        case .havingGreatTime: return "Having a great time"
        case .lotsOfEnergy: return "Lots of energy today"
        case .metAnotherDog: return "Met another dog"
        case .toiletStop: return "Toilet stop done"
        case .onLead: return "On lead"
        case .offLead: return "Off lead"
        case .headingBack: return "Heading back"
        case .almostHome: return "Almost home"
        }
    }
}

// MARK: - Map subview

private struct WalkConsoleMapView: View {
    let currentLocation: CLLocationCoordinate2D?
    let routePoints: [CLLocationCoordinate2D]
    let plannedRoute: [CLLocationCoordinate2D]

    var body: some View {
        Group {
            if #available(iOS 17.0, *) {
                ModernWalkConsoleMap(
                    currentLocation: currentLocation,
                    routePoints: routePoints,
                    plannedRoute: plannedRoute
                )
            } else {
                Map(coordinateRegion: .constant(MKCoordinateRegion(
                    center: currentLocation ?? routePoints.first ?? plannedRoute.first
                        ?? CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )))
            }
        }
    }
}

/// iOS 17+ MapKit polyline + annotation map. Hosted here as a separate
/// availability-gated view so the iOS-16 fallback in WalkConsoleMapView
/// doesn't pull `MapCameraPosition` (iOS 17+ only) into the type system.
@available(iOS 17.0, *)
private struct ModernWalkConsoleMap: View {
    let currentLocation: CLLocationCoordinate2D?
    let routePoints: [CLLocationCoordinate2D]
    let plannedRoute: [CLLocationCoordinate2D]

    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $cameraPosition) {
            if plannedRoute.count >= 2 {
                MapPolyline(coordinates: plannedRoute)
                    .stroke(Color.blue.opacity(0.5), lineWidth: 6)
            }
            if routePoints.count >= 2 {
                MapPolyline(coordinates: routePoints)
                    .stroke(Color.green, lineWidth: 7)
            }
            if let coord = currentLocation {
                Annotation("You", coordinate: coord) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .shadow(radius: 4)
                }
            }
        }
        .onChange(of: currentLocation?.latitude) { _, _ in
            if let coord = currentLocation {
                cameraPosition = .region(MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                ))
            }
        }
    }
}

// MARK: - Live stats overlay

private struct LiveStatsOverlay: View {
    let stats: WalkConsoleLiveStats

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(stats.formattedDuration())
                .font(.title2.bold())
            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text(stats.formattedDistance())
                        .font(.body)
                    Text("Distance")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                VStack(alignment: .leading) {
                    Text(stats.formattedPace())
                        .font(.body)
                    Text("Pace")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Route adherence indicator

private struct RouteAdherenceIndicator: View {
    let adherence: Double

    private var color: Color {
        if adherence >= 80 { return .green }
        if adherence >= 50 { return .yellow }
        return .red
    }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(Int(adherence))%")
                .font(.title3.bold())
                .foregroundColor(.white)
            Text("On Route")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.85))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Dog check-in chip

private struct DogCheckInChip: View {
    let dog: WalkConsoleDog
    let isCheckedIn: Bool
    let isLoading: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            if !isCheckedIn && !isLoading { onTap() }
        } label: {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                } else if isCheckedIn {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                Text(dog.name)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isCheckedIn ? Color.green.opacity(0.2) : Color(.systemGray5))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Live share bottom sheet

private struct LiveShareBottomSheet: View {
    let shareUrl: String
    let bookingShareTargets: [BookingShareTarget]
    let onDismiss: () -> Void
    let onShareSheetFor: (String) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(bookingShareTargets.isEmpty ? "Share live walk" : "Send the live walk")
                        .font(.title2.bold())

                    Text(bookingShareTargets.isEmpty
                         ? "Send this link to the owner so they can watch the walk in real time."
                         : "Each client gets their own link with their dog highlighted on the page.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                    if !bookingShareTargets.isEmpty {
                        ForEach(bookingShareTargets) { target in
                            BookingShareRow(
                                target: target,
                                onWhatsApp: { phone, msg in openWhatsApp(phone: phone, message: msg) },
                                onSms: { phone, msg in openSms(phone: phone, message: msg) },
                                onCopy: { copyToClipboard(target.perClientUrl) },
                                onShareSheet: { onShareSheetFor("Follow your dog's walk live: \(target.perClientUrl)") }
                            )
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(shareUrl)
                                .font(.caption)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            HStack(spacing: 8) {
                                Button {
                                    copyToClipboard(shareUrl)
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)

                                Button {
                                    onShareSheetFor("Follow the walk live: \(shareUrl)")
                                } label: {
                                    Label("Send\u{2026}", systemImage: "square.and.arrow.up")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { onDismiss() }
                }
            }
        }
    }

    private func copyToClipboard(_ s: String) {
        UIPasteboard.general.string = s
    }

    private func openWhatsApp(phone: String, message: String) {
        let cleaned = phone.replacingOccurrences(of: "+", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://wa.me/\(cleaned)?text=\(encoded)") {
            UIApplication.shared.open(url)
        }
    }

    private func openSms(phone: String, message: String) {
        let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "sms:\(phone)&body=\(encoded)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Per-booking share row

private struct BookingShareRow: View {
    let target: BookingShareTarget
    let onWhatsApp: (String, String) -> Void
    let onSms: (String, String) -> Void
    let onCopy: () -> Void
    let onShareSheet: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(target.clientName.prefix(1)).uppercased())
                            .font(.subheadline.bold())
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(target.clientName)
                        .font(.subheadline.bold())
                    if !target.dogNames.isEmpty {
                        Text(target.dogNames.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if target.clientPhone == nil {
                        Text("No phone on file")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            HStack(spacing: 6) {
                if let phone = target.clientPhone {
                    let message = "Follow your dog's walk live: \(target.perClientUrl)"
                    Button {
                        onWhatsApp(phone, message)
                    } label: {
                        Text("WhatsApp")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        onSms(phone, message)
                    } label: {
                        Text("SMS")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        onCopy()
                    } label: {
                        Text("Copy URL")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        onShareSheet()
                    } label: {
                        Text("Send\u{2026}")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Walker safety sheet

private struct WalkerSafetySheet: View {
    let currentlyActive: Bool
    let currentContact: String?
    let onStart: (String, String, Int64) -> Void
    let onEnd: () -> Void
    let onDismiss: () -> Void

    @State private var name: String = ""
    @State private var phone: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "shield")
                            .foregroundColor(.accentColor)
                        Text("Walker safety")
                            .font(.title2.bold())
                    }

                    if currentlyActive {
                        Text("\(currentContact ?? "Your emergency contact") is watching this walk. End when you're back.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Button {
                            onEnd()
                        } label: {
                            Text("I've finished — end safety watch")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Text("Pick someone to look out for you. They'll get a private link to watch your live location until you end the walk.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        TextField("Their name", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: name) { new in
                                if new.count > 50 { name = String(new.prefix(50)) }
                            }

                        TextField("Their phone (incl. country code)", text: $phone)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.phonePad)
                            .onChange(of: phone) { new in
                                if new.count > 20 { phone = String(new.prefix(20)) }
                            }

                        Button {
                            let returnAt = Int64(Date().addingTimeInterval(60 * 60).timeIntervalSince1970 * 1000)
                            onStart(name.trimmingCharacters(in: .whitespaces), phone.trimmingCharacters(in: .whitespaces), returnAt)
                        } label: {
                            Text("Send safety link")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(phone.count < 7)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Walker safety")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onDismiss() }
                }
            }
        }
    }
}

// MARK: - Incident log dialog

private struct IncidentLogDialog: View {
    let onSubmit: (WalkIncidentType, String, WalkIncidentSeverity) -> Void
    let onDismiss: () -> Void

    @State private var selectedType: WalkIncidentType = .other
    @State private var selectedSeverity: WalkIncidentSeverity = .low
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Incident type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(WalkIncidentType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }

                Section("Severity") {
                    Picker("Severity", selection: $selectedSeverity) {
                        ForEach(WalkIncidentSeverity.allCases, id: \.self) { sev in
                            Text(sev.displayName).tag(sev)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Notes") {
                    TextField("What happened?", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle("Log Incident")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") {
                        onSubmit(selectedType, notes, selectedSeverity)
                    }
                    .disabled(notes.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Dog check-in dialog

private struct DogCheckInDialog: View {
    let dogName: String
    let onConfirm: (String?) -> Void
    let onDismiss: () -> Void

    @State private var note: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Add an optional note about the check-in.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Note (optional)", text: $note)
                }
            }
            .navigationTitle("Check In \(dogName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Check In") {
                        let trimmed = note.trimmingCharacters(in: .whitespaces)
                        onConfirm(trimmed.isEmpty ? nil : trimmed)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Walk summary screen (post-walk)

private struct WalkSummaryScreen: View {
    let summary: WalkConsoleSummary
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)
                    .padding(.top, 20)
                Text("Walk Complete")
                    .font(.title.bold())

                VStack(spacing: 12) {
                    summaryRow(icon: "map", label: "Distance", value: FormatUtils.formatDistance(summary.distance))
                    summaryRow(icon: "clock", label: "Duration", value: FormatUtils.formatDuration(summary.duration))
                    summaryRow(icon: "camera", label: "Photos", value: "\(summary.photoCount)")
                    summaryRow(icon: "exclamationmark.triangle", label: "Incidents", value: "\(summary.incidentCount)")
                }
                .padding(16)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Button {
                    onDone()
                } label: {
                    Text("Done")
                        .font(.body.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle("Walk Summary")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func summaryRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            Text(value).bold()
        }
    }
}

// MARK: - Error banner

private struct ErrorBanner: View {
    let text: String

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
            Text(text)
                .font(.subheadline)
                .lineLimit(2)
        }
        .padding(12)
        .background(Color.red)
        .foregroundColor(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }
}

// MARK: - Photo picker

private struct WalkConsolePhotoPicker: UIViewControllerRepresentable {
    let onPicked: (Data?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onPicked: (Data?) -> Void
        init(onPicked: @escaping (Data?) -> Void) { self.onPicked = onPicked }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
            let image = info[.originalImage] as? UIImage
            let data = image?.jpegData(compressionQuality: 0.85)
            picker.dismiss(animated: true) { self.onPicked(data) }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) { self.onPicked(nil) }
        }
    }
}

// MARK: - Share activity wrapper

private struct ShareActivityView: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BusinessWalkConsoleScreen(bookingId: "preview", dogIds: ["d1", "d2"])
    }
}
