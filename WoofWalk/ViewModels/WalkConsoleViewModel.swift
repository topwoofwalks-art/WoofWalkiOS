import Foundation
import SwiftUI
import CoreLocation
import Combine
import FirebaseAuth

/// ViewModel for the business walker Walk Console screen.
///
/// 1:1 port of Android `WalkConsoleViewModel.kt`. Owns the full walk-
/// console state: GPS pipeline, walk-session lifecycle, photo capture,
/// dog check-ins, incident logging, live-share fan-out + walker-safety
/// Watch Me. Mirrors the Android responsibilities so the two clients
/// stay parity-safe at the data layer.
///
/// Architecture notes:
/// - GPS comes from the existing `WalkTrackingService` (which already
///   wraps CoreLocation + the GPSFilterPipeline). Subscribing to its
///   `trackingState` publisher gives us the same accepted-fix stream
///   the consumer flow uses.
/// - The walk session itself is owned by `BusinessWalkSessionRepository`
///   (Firestore writes); this ViewModel orchestrates lifecycle calls.
/// - Live-share routes through `BusinessLiveShareRepository` (CF gateway).
/// - Walker-safety Watch Me routes through `SafetyWatchRepository` (CF gateway).
@MainActor
final class WalkConsoleViewModel: ObservableObject {
    // MARK: - Published UI state

    @Published var walkSession: BusinessWalkSessionState?
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var liveStats: WalkConsoleLiveStats = WalkConsoleLiveStats()
    @Published var photos: [WalkConsolePhoto] = []
    @Published var incidents: [WalkConsoleIncident] = []
    @Published var isTracking: Bool = false
    @Published var isPaused: Bool = false
    @Published var error: String?
    @Published var showEndWalkDialog: Bool = false
    @Published var showIncidentDialog: Bool = false
    @Published var showShareSheet: Bool = false
    @Published var showLocationPermissionDialog: Bool = false
    @Published var dogProfiles: [WalkConsoleDog] = []
    @Published var checkedInDogs: Set<String> = []
    @Published var checkInInProgress: Set<String> = []
    @Published var pendingCheckInDogId: String?
    @Published var plannedRoute: [CLLocationCoordinate2D] = []
    @Published var plannedRouteAdherence: Double?
    @Published var shareUrl: String?
    @Published var isCreatingShareLink: Bool = false
    @Published var bookingShareTargets: [BookingShareTarget] = []
    @Published var clientBriefs: [ClientBrief] = []
    @Published var walkerNote: String?
    @Published var walkerSafetyWatchActive: Bool = false
    @Published var walkerSafetyContactName: String?

    // MARK: - Phase 5 multi-select picker
    //
    // Pre-share step for group walks: instead of auto-fanning the live
    // share to every active booking, the walker picks the subset of
    // households to share with. Solo walks skip the picker entirely
    // and go straight to `createShare`. The picker reads booking
    // metadata (client name, dogs, service type) so each row reads as
    // a recognisable household, not a raw booking id.
    @Published var selectableBookings: [BookingShareTarget] = []
    @Published var selectedBookingIds: Set<String> = []
    @Published var showBookingPicker: Bool = false
    @Published var isLoadingPicker: Bool = false

    /// True until the walker hits Start. Drives the canStartWalk flag in
    /// the same way Android's UiState.canStartWalk does.
    var canStartWalk: Bool { !isTracking && walkSession == nil }

    // MARK: - Dependencies

    private let walkSessionRepo: BusinessWalkSessionRepository
    private let liveShareRepo: BusinessLiveShareRepository
    private let safetyWatchRepo: SafetyWatchRepository
    private let bookingRepo: BookingRepository
    private let walkTrackingService: WalkTrackingService

    // MARK: - Internal state

    private var activeWalkId: String?
    private var activeBookingId: String?
    private var activeBookingIds: [String] = []
    private var activeShareId: String?
    private var sessionStartTime: Date = Date()
    private var routePoints: [WalkConsoleRoutePoint] = []
    private var lastLiveSharePushAt: Date?
    private var lastPushedLocation: CLLocationCoordinate2D?
    private var statsTimer: Timer?
    private var trackingCancellable: AnyCancellable?
    private var initialDistanceOffset: Double = 0

    /// Throttle live-share pushes to one per 10 s — matches Android.
    private static let liveSharePushIntervalSec: TimeInterval = 10
    /// Cap polyline pushed to client at 500 points.
    private static let maxRoutePointsForPush = 500
    /// Tolerance band for the route-adherence indicator (m).
    private static let adherenceToleranceMeters: Double = 30
    /// Max length the walker note can be pushed at — matches CF cap.
    private static let walkerNoteMaxLength = 200

    // MARK: - Init

    init(
        walkSessionRepo: BusinessWalkSessionRepository = .shared,
        liveShareRepo: BusinessLiveShareRepository = .shared,
        safetyWatchRepo: SafetyWatchRepository = .shared,
        bookingRepo: BookingRepository = BookingRepository(),
        walkTrackingService: WalkTrackingService = .shared
    ) {
        self.walkSessionRepo = walkSessionRepo
        self.liveShareRepo = liveShareRepo
        self.safetyWatchRepo = safetyWatchRepo
        self.bookingRepo = bookingRepo
        self.walkTrackingService = walkTrackingService
    }

    deinit {
        statsTimer?.invalidate()
    }

    // MARK: - Preload

    /// Preload dog profiles + capture the dog-id list for downstream
    /// session creation. Safe to call repeatedly.
    func preloadDogProfiles(dogIds: [String]) {
        Task { @MainActor in
            self.dogProfiles = await walkSessionRepo.loadDogs(dogIds: dogIds)
        }
    }

    /// Pre-walk client briefs. Loaded on screen entry so the walker has
    /// address / phone / key code / instructions before hitting Start.
    func loadClientBriefs(bookingIds: [String]) {
        guard !bookingIds.isEmpty else { return }
        Task { @MainActor in
            self.clientBriefs = await walkSessionRepo.loadClientBriefs(bookingIds: bookingIds)
        }
    }

    // MARK: - Walk lifecycle

    /// Start a single-booking walk.
    func startWalk(bookingId: String, dogIds: [String]) {
        Task { @MainActor in
            do {
                let sessionId = try await walkSessionRepo.startWalkSession(
                    bookingId: bookingId,
                    dogIds: dogIds
                )
                activateLocalSession(
                    sessionId: sessionId,
                    bookingId: bookingId,
                    bookingIds: [bookingId],
                    dogIds: dogIds,
                    plannedRoute: []
                )
            } catch {
                self.error = "Failed to start walk: \(error.localizedDescription)"
                print("[WalkConsole] startWalk failed: \(error)")
            }
        }
    }

    /// Start a group walk covering N bookings.
    func startGroupWalk(bookingIds: [String], dogIds: [String]) {
        guard !bookingIds.isEmpty else {
            self.error = "No bookings selected"
            return
        }
        Task { @MainActor in
            do {
                let sessionId = try await walkSessionRepo.startGroupWalkSession(
                    bookingIds: bookingIds,
                    dogIds: dogIds
                )
                activateLocalSession(
                    sessionId: sessionId,
                    bookingId: bookingIds.first,
                    bookingIds: bookingIds,
                    dogIds: dogIds,
                    plannedRoute: []
                )
            } catch {
                self.error = "Failed to start group walk: \(error.localizedDescription)"
                print("[WalkConsole] startGroupWalk failed: \(error)")
            }
        }
    }

    /// Start a walk from a previously-planned walk (route preloaded).
    /// `plannedRoute` is the polyline that appears on the map.
    func startWalkFromPlannedWalk(
        bookingId: String,
        dogIds: [String],
        plannedWalkId: String,
        plannedRoute: [CLLocationCoordinate2D]
    ) {
        Task { @MainActor in
            do {
                let sessionId = try await walkSessionRepo.startWalkSession(
                    bookingId: bookingId,
                    dogIds: dogIds,
                    plannedRoute: plannedRoute,
                    plannedWalkId: plannedWalkId
                )
                activateLocalSession(
                    sessionId: sessionId,
                    bookingId: bookingId,
                    bookingIds: [bookingId],
                    dogIds: dogIds,
                    plannedRoute: plannedRoute
                )
            } catch {
                self.error = "Failed to start walk: \(error.localizedDescription)"
                print("[WalkConsole] startWalkFromPlannedWalk failed: \(error)")
            }
        }
    }

    private func activateLocalSession(
        sessionId: String,
        bookingId: String?,
        bookingIds: [String],
        dogIds: [String],
        plannedRoute: [CLLocationCoordinate2D]
    ) {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        activeWalkId = sessionId
        activeBookingId = bookingId
        activeBookingIds = bookingIds
        activeShareId = nil
        sessionStartTime = Date()
        routePoints = []
        lastLiveSharePushAt = nil
        lastPushedLocation = nil

        walkSession = BusinessWalkSessionState(
            id: sessionId,
            bookingId: bookingId,
            dogIds: dogIds,
            startedAt: now,
            status: .inProgress,
            plannedWalkId: nil,
            routePoints: []
        )
        isTracking = true
        isPaused = false
        liveStats = WalkConsoleLiveStats()
        self.plannedRoute = plannedRoute
        self.error = nil

        startGpsPipeline()
        startStatsTimer()
    }

    /// Pause the active walk. Pushes a paused-state to the live share so
    /// the client sees a "Walk paused" banner instead of a stalled dot.
    func pauseWalk() {
        guard isTracking, !isPaused, let sessionId = activeWalkId else { return }
        isPaused = true
        walkSession?.status = .paused
        Task { @MainActor in
            try? await walkSessionRepo.updateSessionStatus(sessionId: sessionId, status: .paused)
            await pushPauseState(paused: true)
        }
    }

    /// Resume a paused walk.
    func resumeWalk() {
        guard isTracking, isPaused, let sessionId = activeWalkId else { return }
        isPaused = false
        walkSession?.status = .inProgress
        Task { @MainActor in
            try? await walkSessionRepo.updateSessionStatus(sessionId: sessionId, status: .inProgress)
            await pushPauseState(paused: false)
        }
    }

    /// Open the end-walk confirmation dialog.
    func showEndWalkConfirmation() { showEndWalkDialog = true }
    func dismissEndWalkDialog() { showEndWalkDialog = false }

    /// End the active walk. Stops GPS, ends the live share, fans
    /// out booking → COMPLETED, then invokes `onComplete` with the
    /// summary. Mirrors Android's `endWalk(onComplete:)`.
    func endWalk(onComplete: @escaping (WalkConsoleSummary) -> Void) {
        guard let sessionId = activeWalkId, let session = walkSession else { return }
        let durationSec = Int(Date().timeIntervalSince(sessionStartTime))
        let distanceMeters = liveStats.distance
        let summary = WalkConsoleSummary(
            sessionId: sessionId,
            bookingId: session.bookingId,
            duration: durationSec,
            distance: distanceMeters,
            photoCount: photos.count,
            incidentCount: incidents.count
        )

        // Cleanup local state immediately so the UI flips off the
        // tracking surface; backend writes happen in parallel below.
        stopGpsPipeline()
        stopStatsTimer()
        isTracking = false
        showEndWalkDialog = false
        walkSession?.status = .completed

        let bookingIdsToComplete = activeBookingIds.isEmpty
            ? [activeBookingId].compactMap { $0 }
            : activeBookingIds
        let activeShareIdSnapshot = activeShareId

        Task { @MainActor in
            // 1. Mark the walk session itself COMPLETED.
            do {
                try await walkSessionRepo.completeSession(
                    sessionId: sessionId,
                    distanceMeters: distanceMeters,
                    durationSec: durationSec
                )
            } catch {
                print("[WalkConsole] completeSession failed: \(error)")
            }

            // 2. End the live share if one was created.
            if let shareId = activeShareIdSnapshot {
                do {
                    try await liveShareRepo.endShare(shareId: shareId)
                } catch {
                    print("[WalkConsole] endShare failed: \(error)")
                }
            }

            // 3. Fan out booking → COMPLETED across every booking in scope.
            for bookingId in bookingIdsToComplete {
                do {
                    try await bookingRepo.updateBookingStatus(
                        bookingId: bookingId,
                        status: .completed
                    )
                } catch {
                    print("[WalkConsole] updateBookingStatus(completed) failed for \(bookingId): \(error)")
                }
            }
        }

        // Reset session-scoped state.
        activeWalkId = nil
        activeBookingId = nil
        activeBookingIds = []
        activeShareId = nil
        routePoints = []
        lastLiveSharePushAt = nil

        onComplete(summary)
    }

    // MARK: - Photo capture

    /// Record a captured photo locally and upload to live-share storage
    /// if one is active. The photo is added to the local `photos` list
    /// immediately (offline-friendly) — the upload is best-effort.
    func capturePhoto(imageData: Data, caption: String?) {
        guard let sessionId = activeWalkId else { return }
        let photoId = UUID().uuidString
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let coord = currentLocation
        let localPhoto = WalkConsolePhoto(
            id: photoId,
            sessionId: sessionId,
            photoUrl: "local://\(photoId)",
            thumbnailUrl: nil,
            caption: caption,
            timestamp: now,
            latitude: coord?.latitude,
            longitude: coord?.longitude
        )
        photos.append(localPhoto)

        // Upload + add to live-share if we've got an active share.
        let shareId = activeShareId
        Task { @MainActor in
            guard let shareId = shareId else { return }
            do {
                let storagePath = try await walkSessionRepo.uploadLiveSharePhoto(
                    shareId: shareId,
                    photoId: photoId,
                    imageData: imageData
                )
                _ = try await liveShareRepo.addPhoto(
                    shareId: shareId,
                    storagePath: storagePath,
                    thumbnailPath: nil,
                    lat: coord?.latitude ?? 0,
                    lng: coord?.longitude ?? 0,
                    takenAt: now,
                    caption: caption
                )
            } catch {
                // Photo stays in local list for the post-walk recap.
                print("[WalkConsole] photo upload failed for \(photoId): \(error)")
            }
        }
    }

    // MARK: - Walker note

    /// Push the walker's commentary note onto the live share. Empty
    /// string clears the note. Capped at 200 chars to match the CF.
    func setWalkerNote(_ note: String) {
        guard let shareId = activeShareId else { return }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let truncated = String(trimmed.prefix(Self.walkerNoteMaxLength))
        let lastCoord = currentLocation
        let durationSec = Int64(Date().timeIntervalSince(sessionStartTime))
        let distance = liveStats.distance
        let route = routePointsForPush()

        Task { @MainActor in
            do {
                if truncated.isEmpty {
                    try await liveShareRepo.pushLocation(
                        shareId: shareId,
                        lat: lastCoord?.latitude ?? 0,
                        lng: lastCoord?.longitude ?? 0,
                        distanceMeters: distance,
                        durationSec: durationSec,
                        routePoints: route,
                        walkerNote: nil,
                        clearWalkerNote: true
                    )
                    self.walkerNote = nil
                } else {
                    try await liveShareRepo.pushLocation(
                        shareId: shareId,
                        lat: lastCoord?.latitude ?? 0,
                        lng: lastCoord?.longitude ?? 0,
                        distanceMeters: distance,
                        durationSec: durationSec,
                        routePoints: route,
                        walkerNote: truncated,
                        clearWalkerNote: false
                    )
                    self.walkerNote = truncated
                }
            } catch {
                print("[WalkConsole] setWalkerNote failed: \(error)")
                self.error = "Couldn't update note"
            }
        }
    }

    // MARK: - Live share

    /// Create (or reuse) a live-share for the active walk and reveal
    /// the share sheet. For solo walks (one booking) creates the
    /// share directly. For group walks (>1 booking) opens the
    /// multi-select picker first so the walker chooses the subset of
    /// households to share with.
    ///
    /// Phase 5 — the picker step replaces the previous auto-fan to
    /// every active booking. Default selection is "all", so a walker
    /// who wants the old behaviour just taps confirm.
    func startSharingWalk() {
        guard let _ = activeWalkId, let bookingId = activeBookingId else {
            self.error = "Start the walk before sharing"
            return
        }
        let candidateIds = activeBookingIds.isEmpty ? [bookingId] : activeBookingIds
        if candidateIds.count <= 1 {
            // Solo walk — straight to share, skip the picker.
            proceedWithShare(bookingIds: candidateIds)
            return
        }
        // Group walk — load metadata for each booking so the picker
        // shows recognisable rows. Default selection = all bookings,
        // matching the pre-Phase-5 behaviour for one-tap confirm.
        isLoadingPicker = true
        selectedBookingIds = Set(candidateIds)
        Task { @MainActor in
            // Build targets without a base URL — the share doesn't
            // exist yet. We'll re-build with the real per-client URLs
            // after `createShare` lands.
            let targets = await walkSessionRepo.buildBookingShareTargets(
                bookingIds: candidateIds,
                baseUrl: ""
            )
            self.selectableBookings = targets
            self.isLoadingPicker = false
            self.showBookingPicker = true
        }
    }

    /// Toggle a booking's inclusion in the share. No-op if the id
    /// isn't in the candidate list.
    func toggleBookingSelection(_ bookingId: String) {
        guard selectableBookings.contains(where: { $0.bookingId == bookingId }) else { return }
        if selectedBookingIds.contains(bookingId) {
            selectedBookingIds.remove(bookingId)
        } else {
            selectedBookingIds.insert(bookingId)
        }
    }

    /// Confirm the picker selection and create the share with the
    /// chosen subset. No-op if no rows are selected.
    func confirmBookingPicker() {
        let chosen = selectableBookings
            .map { $0.bookingId }
            .filter { selectedBookingIds.contains($0) }
        guard !chosen.isEmpty else {
            self.error = "Pick at least one client"
            return
        }
        showBookingPicker = false
        proceedWithShare(bookingIds: chosen)
    }

    /// Dismiss the picker without sharing.
    func cancelBookingPicker() {
        showBookingPicker = false
        selectableBookings = []
        selectedBookingIds = []
    }

    /// Internal helper — actually call the CF and reveal the send sheet.
    /// Always runs after the picker (or directly for solo walks).
    private func proceedWithShare(bookingIds: [String]) {
        guard let sessionId = activeWalkId else {
            self.error = "Start the walk before sharing"
            return
        }
        isCreatingShareLink = true
        Task { @MainActor in
            do {
                let result = try await liveShareRepo.createShare(
                    sessionId: sessionId,
                    bookingIds: bookingIds
                )
                activeShareId = result.id
                shareUrl = result.url
                showShareSheet = true

                // Build per-client targets for group walks.
                if bookingIds.count > 1 {
                    bookingShareTargets = await walkSessionRepo.buildBookingShareTargets(
                        bookingIds: bookingIds,
                        baseUrl: result.url
                    )
                } else {
                    bookingShareTargets = []
                }

                // Reset picker state — we're past the picker now.
                selectableBookings = []
                selectedBookingIds = []
            } catch {
                self.error = "Couldn't create share link: \(error.localizedDescription)"
                print("[WalkConsole] startSharingWalk failed: \(error)")
            }
            isCreatingShareLink = false
        }
    }

    func dismissShareSheet() { showShareSheet = false }

    /// Per-client share URL. Appends `?b={bookingId}` so the portal page
    /// highlights that household's dog. Solo walks: returns base URL
    /// unchanged.
    func shareUrl(forBooking bookingId: String) -> String? {
        guard let base = shareUrl else { return nil }
        guard activeBookingIds.count > 1 else { return base }
        let separator = base.contains("?") ? "&" : "?"
        return "\(base)\(separator)b=\(bookingId)"
    }

    // MARK: - Walker safety Watch Me

    /// Kick off a walker-safety watch with the supplied emergency
    /// contact. Routes through SafetyWatchRepository → CF gateway.
    /// Returns the watch URL synchronously via the completion so the
    /// view can immediately fire a system share intent.
    ///
    /// `walkerFirstName` is taken from the auth display name (best
    /// effort — fall back to "Walker"). `expectedReturnAt` is one
    /// hour out by default, mirroring Android.
    func startWalkerSafetyWatch(
        contactName: String,
        contactPhone: String,
        expectedReturnAt: Int64,
        completion: @escaping (String?) -> Void
    ) {
        guard let sessionId = activeWalkId else {
            self.error = "Start the walk before enabling safety watch"
            completion(nil)
            return
        }
        guard !contactPhone.isEmpty else {
            self.error = "Emergency contact phone required"
            completion(nil)
            return
        }
        let firstName = (Auth.auth().currentUser?.displayName?
            .components(separatedBy: " ")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines))
            .flatMap { $0.isEmpty ? nil : $0 }
            ?? "Walker"
        let resolvedContactName = contactName.isEmpty ? "Emergency contact" : contactName

        Task { @MainActor in
            do {
                let watch = try await safetyWatchRepo.startWatch(
                    sessionId: sessionId,
                    walkerFirstName: firstName,
                    walkerNote: "Working — please look out for me",
                    guardianNames: [resolvedContactName],
                    guardianPhones: [contactPhone],
                    guardianUids: [],
                    expectedReturnAt: expectedReturnAt
                )
                walkerSafetyWatchActive = true
                walkerSafetyContactName = resolvedContactName
                let url = safetyWatchRepo.watchUrl(token: watch.token)
                completion(url)
            } catch {
                print("[WalkConsole] startWalkerSafetyWatch failed: \(error)")
                self.error = "Couldn't start safety watch: \(error.localizedDescription)"
                completion(nil)
            }
        }
    }

    /// Mark walker-safety watch as ended locally. The underlying watch
    /// expires server-side via session expiry; this just clears the UI flag.
    func endWalkerSafetyWatch() {
        walkerSafetyWatchActive = false
        walkerSafetyContactName = nil
    }

    // MARK: - POI quick-add (bin)

    /// Quick-add a bin POI at the walker's current location. Hands off
    /// to the consumer PoiRepository so the bin appears on every
    /// WoofWalk user's map. No-op if no current GPS fix.
    func quickAddBin() {
        guard let coord = currentLocation else { return }
        let geohash = Self.geohashEncode(latitude: coord.latitude, longitude: coord.longitude)
        let poi = Poi(
            type: PoiType.bin.rawValue,
            title: "Dog Bin",
            desc: "Quick-added during walk",
            lat: coord.latitude,
            lng: coord.longitude,
            geohash: geohash
        )
        Task { @MainActor in
            do {
                _ = try await PoiRepository.shared.createPoi(poi)
                print("[WalkConsole] Bin added at \(coord.latitude),\(coord.longitude)")
            } catch {
                print("[WalkConsole] quickAddBin failed: \(error)")
                self.error = "Couldn't add bin"
            }
        }
    }

    // MARK: - Dog check-ins

    func requestDogCheckIn(dogId: String) {
        pendingCheckInDogId = dogId
    }

    func dismissCheckInDialog() {
        pendingCheckInDogId = nil
    }

    /// Confirm the pending check-in with an optional note.
    func confirmDogCheckIn(note: String?) {
        guard let dogId = pendingCheckInDogId else { return }
        performDogCheckIn(dogId: dogId, note: note)
    }

    /// Bulk check-in for every dog still pending.
    func checkInAllDogs() {
        guard let session = walkSession else { return }
        for dogId in session.dogIds where !checkedInDogs.contains(dogId) {
            performDogCheckIn(dogId: dogId, note: nil)
        }
    }

    private func performDogCheckIn(dogId: String, note: String?) {
        guard let sessionId = activeWalkId else { return }
        checkInInProgress.insert(dogId)
        pendingCheckInDogId = nil
        let dogName = dogProfiles.first(where: { $0.id == dogId })?.name ?? ""
        let coord = currentLocation
        let bookingId = activeBookingId

        Task { @MainActor in
            do {
                try await walkSessionRepo.recordDogCheckIn(
                    sessionId: sessionId,
                    bookingId: bookingId,
                    dogId: dogId,
                    dogName: dogName,
                    note: note,
                    coordinate: coord
                )
                checkedInDogs.insert(dogId)
            } catch {
                print("[WalkConsole] check-in failed for \(dogId): \(error)")
                self.error = "Failed to check in dog"
            }
            checkInInProgress.remove(dogId)
        }
    }

    // MARK: - Incidents

    func showIncidentLogDialog() { showIncidentDialog = true }
    func dismissIncidentDialog() { showIncidentDialog = false }

    /// Log an incident locally + persist to Firestore. HIGH / CRITICAL
    /// severities trigger client notifications via the repository.
    func logIncident(type: WalkIncidentType, notes: String, severity: WalkIncidentSeverity) {
        guard let sessionId = activeWalkId else { return }
        let coord = currentLocation
        let incident = WalkConsoleIncident(
            id: UUID().uuidString,
            sessionId: sessionId,
            type: type,
            severity: severity,
            notes: notes,
            timestamp: Int64(Date().timeIntervalSince1970 * 1000),
            latitude: coord?.latitude,
            longitude: coord?.longitude
        )
        incidents.append(incident)
        showIncidentDialog = false
        let bookingId = activeBookingId

        Task { @MainActor in
            do {
                try await walkSessionRepo.saveIncident(
                    sessionId: sessionId,
                    bookingId: bookingId,
                    incident: incident
                )
            } catch {
                print("[WalkConsole] logIncident persist failed: \(error)")
            }
        }
    }

    func clearError() { error = nil }

    // MARK: - GPS pipeline

    /// Subscribes to WalkTrackingService's published tracking state. As
    /// each accepted GPS fix lands, we mirror it into our local
    /// route-points list, throttled-push to the live share, and
    /// update route-adherence.
    private func startGpsPipeline() {
        // Capture WalkTrackingService's distance-accumulator at start
        // so we can report cumulative distance for THIS walk only
        // (the service tracks across services, ours is per-session).
        initialDistanceOffset = walkTrackingService.trackingState.distanceMeters

        // If the consumer service isn't already tracking, start it.
        // (The walker may have come straight to this screen; the
        // consumer flow lazy-starts on demand and is shared here.)
        if !walkTrackingService.trackingState.isTracking {
            walkTrackingService.startTracking(sessionId: activeWalkId)
        }

        trackingCancellable = walkTrackingService.$trackingState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                Task { @MainActor [weak self] in
                    self?.handleTrackingStateUpdate(state)
                }
            }
    }

    private func stopGpsPipeline() {
        trackingCancellable?.cancel()
        trackingCancellable = nil
        // Don't `stopTracking()` on the consumer service unconditionally
        // — if the user backed into the console mid-personal-walk it
        // would kill their personal tracker. Only stop if the session
        // id we started with is still the active one.
        if walkTrackingService.trackingState.sessionId == activeWalkId {
            _ = walkTrackingService.stopTracking()
        }
    }

    private func handleTrackingStateUpdate(_ state: WalkTrackingState) {
        guard isTracking, !isPaused else { return }

        let distanceForThisWalk = max(0, state.distanceMeters - initialDistanceOffset)
        let lastCoord = state.polyline.last
        guard let coord = lastCoord else { return }
        currentLocation = coord

        // Append to our routePoints list (cap at 500 for push payload).
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let point = WalkConsoleRoutePoint(
            latitude: coord.latitude,
            longitude: coord.longitude,
            timestamp: now,
            accuracy: state.gpsAccuracy
        )
        // Don't double-append the same coord; WalkTrackingService can
        // republish the same state even when only timer fields change.
        if let last = routePoints.last,
           abs(last.latitude - coord.latitude) < 0.000005,
           abs(last.longitude - coord.longitude) < 0.000005 {
            // skip duplicate
        } else {
            routePoints.append(point)
            if routePoints.count > Self.maxRoutePointsForPush {
                routePoints.removeFirst(routePoints.count - Self.maxRoutePointsForPush)
            }
            walkSession?.routePoints = routePoints
        }

        liveStats.distance = distanceForThisWalk
        plannedRouteAdherence = computeRouteAdherence(
            plannedRoute: plannedRoute,
            currentLocation: coord
        )

        // Throttled live-share push.
        guard let shareId = activeShareId else { return }
        let nowDate = Date()
        if let last = lastLiveSharePushAt, nowDate.timeIntervalSince(last) < Self.liveSharePushIntervalSec {
            return
        }
        lastLiveSharePushAt = nowDate
        let route = routePointsForPush()
        let durationSec = Int64(Date().timeIntervalSince(sessionStartTime))
        let distance = distanceForThisWalk
        Task { @MainActor in
            do {
                try await liveShareRepo.pushLocation(
                    shareId: shareId,
                    lat: coord.latitude,
                    lng: coord.longitude,
                    distanceMeters: distance,
                    durationSec: durationSec,
                    routePoints: route
                )
            } catch {
                print("[WalkConsole] live-share push failed: \(error)")
            }
        }
    }

    private func pushPauseState(paused: Bool) async {
        guard let shareId = activeShareId else { return }
        let coord = currentLocation
        // The CF doesn't accept an explicit pause field today; the
        // walker note carries the banner copy instead. (Keeps parity
        // with the Android pushPauseState helper which also re-uses
        // the same callable.)
        let route = routePointsForPush()
        let durationSec = Int64(Date().timeIntervalSince(sessionStartTime))
        do {
            try await liveShareRepo.pushLocation(
                shareId: shareId,
                lat: coord?.latitude ?? 0,
                lng: coord?.longitude ?? 0,
                distanceMeters: liveStats.distance,
                durationSec: durationSec,
                routePoints: route,
                walkerNote: paused ? "(Walk paused)" : nil,
                clearWalkerNote: !paused && walkerNote == nil
            )
        } catch {
            print("[WalkConsole] pushPauseState(\(paused)) failed: \(error)")
        }
    }

    private func routePointsForPush() -> [[String: Double]] {
        routePoints.map { ["lat": $0.latitude, "lng": $0.longitude] }
    }

    // MARK: - Stats timer

    private func startStatsTimer() {
        statsTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let strong = self else { return }
            Task { @MainActor in
                strong.tickStats()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        statsTimer = timer
    }

    private func stopStatsTimer() {
        statsTimer?.invalidate()
        statsTimer = nil
    }

    private func tickStats() {
        guard isTracking, !isPaused else { return }
        let elapsed = Int(Date().timeIntervalSince(sessionStartTime))
        var stats = liveStats
        stats.duration = elapsed
        if stats.distance > 50 {
            stats.pace = (Double(elapsed) / 60.0) / (stats.distance / 1000.0)
        }
        liveStats = stats
    }

    // MARK: - Route adherence

    /// Perpendicular-distance based adherence — 100 = on path,
    /// 0 = >= 100 m off. Mirrors Android `computeRouteAdherence`.
    private func computeRouteAdherence(
        plannedRoute: [CLLocationCoordinate2D],
        currentLocation: CLLocationCoordinate2D
    ) -> Double? {
        guard plannedRoute.count >= 2 else { return nil }
        let nearest = nearestDistanceToPolyline(point: currentLocation, polyline: plannedRoute)
        let maxOff = Self.adherenceToleranceMeters * 3.33
        return max(0, min(100, (1.0 - (nearest / maxOff)) * 100.0))
    }

    private func nearestDistanceToPolyline(
        point: CLLocationCoordinate2D,
        polyline: [CLLocationCoordinate2D]
    ) -> Double {
        var minDist = Double.greatestFiniteMagnitude
        for i in 0..<(polyline.count - 1) {
            let a = polyline[i]
            let b = polyline[i + 1]
            let da = haversine(point, a)
            let db = haversine(point, b)
            let dab = haversine(a, b)
            let perp: Double
            if dab < 1.0 {
                perp = da
            } else {
                let s = (da + db + dab) / 2.0
                let areaSq = s * (s - da) * (s - db) * (s - dab)
                perp = areaSq <= 0 ? min(da, db) : 2.0 * sqrt(areaSq) / dab
            }
            if perp < minDist { minDist = perp }
        }
        return minDist
    }

    private func haversine(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let r = 6371000.0
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLng = (b.longitude - a.longitude) * .pi / 180
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) +
            cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2)
        return 2 * r * atan2(sqrt(h), sqrt(1 - h))
    }

    // MARK: - Geohash

    /// Tiny geohash encoder for POI lat/lng. Mirrors the precision-9
    /// output of Android's `GeoHashUtil.encode`.
    private static func geohashEncode(latitude: Double, longitude: Double, precision: Int = 9) -> String {
        let base32 = Array("0123456789bcdefghjkmnpqrstuvwxyz")
        var lat = (-90.0, 90.0)
        var lng = (-180.0, 180.0)
        var hash = ""
        var bit = 0
        var ch = 0
        var even = true
        while hash.count < precision {
            if even {
                let mid = (lng.0 + lng.1) / 2
                if longitude >= mid {
                    ch = (ch << 1) | 1
                    lng.0 = mid
                } else {
                    ch = ch << 1
                    lng.1 = mid
                }
            } else {
                let mid = (lat.0 + lat.1) / 2
                if latitude >= mid {
                    ch = (ch << 1) | 1
                    lat.0 = mid
                } else {
                    ch = ch << 1
                    lat.1 = mid
                }
            }
            even.toggle()
            bit += 1
            if bit == 5 {
                hash.append(base32[ch])
                bit = 0
                ch = 0
            }
        }
        return hash
    }
}
