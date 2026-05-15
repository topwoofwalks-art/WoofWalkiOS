import SwiftUI
import MapKit
import FirebaseAuth
import FirebaseFirestore
import CoreLocation
import UIKit

/// Lost-dog detail — the deep-link target for FCM payloads carrying
/// `actionUrl=/lost-dog/{alertId}` and for notification-feed taps on
/// LOST_DOG_ALERT rows.
///
/// Mirrors Android's `LostDogDetailScreen.kt` (and is structurally the
/// full-screen sibling of the foreground `LostDogAlertSheet`). Shows
/// dog photo, name, breed, owner contact, last-known location on a
/// small MapKit map, and the sightings feed populated by other users
/// tapping "I've seen this dog" via the alert sheet or this screen.
///
/// Data model
/// ----------
/// Document is at `lost_dog_alerts/{alertId}`. Subcollection
/// `lost_dog_alerts/{alertId}/sightings` carries `{lat, lng, reportedBy,
/// createdAt, note?}`. Both are already used by Android + iOS sheet —
/// this screen just renders the same data in a richer layout.
struct LostDogDetailScreen: View {
    let alertId: String

    @State private var alert: LostDogAlert?
    @State private var sightings: [Sighting] = []
    @State private var loadState: LoadState = .loading
    @State private var errorMessage: String?

    @State private var showSightingSheet = false
    @State private var showShareSheet = false
    @State private var sightingsListener: ListenerRegistration?
    @State private var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 54.5, longitude: -2.5),
        span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)
    )

    private struct PinItem: Identifiable {
        let id: String
        let coordinate: CLLocationCoordinate2D
        let kind: Kind
        enum Kind { case lastSeen, sighting }
    }

    enum LoadState {
        case loading
        case loaded
        case notFound
        case error
    }

    struct LostDogAlert: Equatable {
        let id: String
        let dogName: String
        let dogBreed: String?
        let dogPhotoUrl: String?
        let locationDescription: String?
        let lat: Double?
        let lng: Double?
        let ownerName: String?
        let ownerPhone: String?
        let status: String
        let reportedAt: Date?

        var hasFix: Bool {
            if let lat, let lng, !(lat == 0 && lng == 0) { return true }
            return false
        }
    }

    struct Sighting: Identifiable, Equatable {
        let id: String
        let lat: Double?
        let lng: Double?
        let note: String?
        let createdAt: Date?
        let reportedBy: String?
    }

    var body: some View {
        Group {
            switch loadState {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .notFound:
                emptyState(
                    icon: "questionmark.diamond.fill",
                    title: "Alert not found",
                    body: "This lost dog alert has been removed or never existed."
                )
            case .error:
                emptyState(
                    icon: "exclamationmark.triangle.fill",
                    title: "Couldn't load",
                    body: errorMessage ?? "Try again in a moment."
                )
            case .loaded:
                if let alert {
                    content(alert)
                } else {
                    ProgressView()
                }
            }
        }
        .navigationTitle("Lost Dog")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(alert == nil)
            }
        }
        .sheet(isPresented: $showSightingSheet) {
            if let alert {
                ReportSightingSheet(alertId: alert.id, dogName: alert.dogName) {
                    showSightingSheet = false
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [shareUrl])
        }
        .task {
            await loadOnce()
            attachSightingsListener()
        }
        .onDisappear {
            sightingsListener?.remove()
            sightingsListener = nil
        }
    }

    private var shareUrl: URL {
        URL(string: "https://woofwalk.app/lost-dog/\(alertId)")!
    }

    @ViewBuilder
    private func content(_ alert: LostDogAlert) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                heroPhoto(alert)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(alert.status == "FOUND" ? "Reunited" : "Lost dog")
                            .font(.caption.bold())
                            .foregroundColor(alert.status == "FOUND" ? .green : .orange)
                    }
                    Text(alert.dogName)
                        .font(.largeTitle.bold())
                    if let breed = alert.dogBreed, !breed.isEmpty {
                        Text(breed)
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)

                if let desc = alert.locationDescription, !desc.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundColor(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Last seen")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                            Text(desc)
                                .font(.subheadline)
                        }
                    }
                    .padding(.horizontal)
                }

                if alert.hasFix {
                    miniMap(alert)
                        .frame(height: 200)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }

                ownerSection(alert)

                actionsRow(alert)

                sightingsSection
            }
            .padding(.vertical, 16)
        }
    }

    @ViewBuilder
    private func heroPhoto(_ alert: LostDogAlert) -> some View {
        if let urlStr = alert.dogPhotoUrl, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color.secondary.opacity(0.1))
                        .overlay(ProgressView())
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Rectangle()
                        .fill(Color.secondary.opacity(0.1))
                        .overlay(
                            Image(systemName: "pawprint.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                        )
                @unknown default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 260)
            .clipped()
        } else {
            Rectangle()
                .fill(Color.secondary.opacity(0.1))
                .frame(height: 220)
                .overlay(
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.secondary)
                )
        }
    }

    @ViewBuilder
    private func miniMap(_ alert: LostDogAlert) -> some View {
        if let lat = alert.lat, let lng = alert.lng {
            let pins: [PinItem] = [
                PinItem(id: "lastSeen", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng), kind: .lastSeen)
            ] + sightings.compactMap { s in
                guard let sLat = s.lat, let sLng = s.lng else { return nil }
                return PinItem(id: s.id, coordinate: CLLocationCoordinate2D(latitude: sLat, longitude: sLng), kind: .sighting)
            }
            Map(coordinateRegion: $region, annotationItems: pins) { pin in
                MapAnnotation(coordinate: pin.coordinate) {
                    switch pin.kind {
                    case .lastSeen:
                        ZStack {
                            Circle().fill(Color.orange).frame(width: 28, height: 28)
                            Image(systemName: "pawprint.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                    case .sighting:
                        ZStack {
                            Circle().fill(Color.blue).frame(width: 18, height: 18)
                            Image(systemName: "eye.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .onAppear {
                region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
            }
        }
    }

    @ViewBuilder
    private func ownerSection(_ alert: LostDogAlert) -> some View {
        if let owner = alert.ownerName, !owner.isEmpty {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.secondary.opacity(0.15)).frame(width: 44, height: 44)
                    Image(systemName: "person.fill")
                        .foregroundColor(.secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Owner")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Text(owner)
                        .font(.subheadline.bold())
                }
                Spacer()
                if let phone = alert.ownerPhone, !phone.isEmpty {
                    Button {
                        callOwner(phone)
                    } label: {
                        Label("Call", systemImage: "phone.fill")
                            .font(.subheadline.bold())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                    }
                }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    private func actionsRow(_ alert: LostDogAlert) -> some View {
        HStack(spacing: 10) {
            Button {
                showSightingSheet = true
            } label: {
                Label("I've seen this dog", systemImage: "eye.fill")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(alert.status == "FOUND")

            Button {
                showShareSheet = true
            } label: {
                Label("Share alert", systemImage: "square.and.arrow.up")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var sightingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sightings")
                .font(.headline)
                .padding(.horizontal)

            if sightings.isEmpty {
                Text("No sightings reported yet. Tap “I've seen this dog” to be the first.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            } else {
                ForEach(sightings) { sighting in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "eye.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            if let note = sighting.note, !note.isEmpty {
                                Text(note).font(.subheadline)
                            } else {
                                Text("Spotted near here").font(.subheadline)
                            }
                            if let date = sighting.createdAt {
                                Text(FormatUtils.formatRelativeTime(date))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private func emptyState(icon: String, title: String, body: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(title).font(.title3.bold())
            Text(body)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Data

    @MainActor
    private func loadOnce() async {
        let db = Firestore.firestore()
        do {
            let snap = try await db.collection("lost_dog_alerts").document(alertId).getDocument()
            guard snap.exists, let data = snap.data() else {
                loadState = .notFound
                return
            }
            let lat: Double? = (data["lat"] as? Double)
                ?? (data["lastSeenLat"] as? Double)
                ?? (data["lastKnownLat"] as? Double)
            let lng: Double? = (data["lng"] as? Double)
                ?? (data["lon"] as? Double)
                ?? (data["lastSeenLng"] as? Double)
                ?? (data["lastKnownLng"] as? Double)
            let parsed = LostDogAlert(
                id: snap.documentID,
                dogName: (data["dogName"] as? String) ?? "Unknown",
                dogBreed: data["dogBreed"] as? String,
                dogPhotoUrl: (data["dogPhotoUrl"] as? String) ?? (data["photoUrl"] as? String),
                locationDescription: (data["locationDescription"] as? String)
                    ?? (data["lastSeenLocation"] as? String),
                lat: lat,
                lng: lng,
                ownerName: (data["ownerName"] as? String) ?? (data["reporterName"] as? String),
                ownerPhone: (data["ownerPhone"] as? String) ?? (data["contactPhone"] as? String),
                status: (data["status"] as? String) ?? "LOST",
                reportedAt: (data["reportedAt"] as? Timestamp)?.dateValue()
            )
            alert = parsed
            loadState = .loaded
            if let lat = parsed.lat, let lng = parsed.lng, lat != 0 || lng != 0 {
                region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
            }
        } catch {
            loadState = .error
            errorMessage = error.localizedDescription
        }
    }

    private func attachSightingsListener() {
        sightingsListener?.remove()
        sightingsListener = Firestore.firestore()
            .collection("lost_dog_alerts")
            .document(alertId)
            .collection("sightings")
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { snapshot, error in
                if let error {
                    // Sightings live in a subcollection — rules may
                    // permission-deny anonymous reads. Log + carry on,
                    // the rest of the screen still works.
                    print("[LostDogDetail] sightings listener: \(error.localizedDescription)")
                    return
                }
                self.sightings = (snapshot?.documents ?? []).map { doc in
                    let data = doc.data()
                    let createdAt: Date? = (data["createdAt"] as? Timestamp)?.dateValue()
                    return Sighting(
                        id: doc.documentID,
                        lat: data["lat"] as? Double,
                        lng: data["lng"] as? Double,
                        note: data["note"] as? String,
                        createdAt: createdAt,
                        reportedBy: data["reportedBy"] as? String
                    )
                }
            }
    }

    // MARK: - Actions

    private func callOwner(_ raw: String) {
        let digits = raw.filter { "0123456789+".contains($0) }
        if let url = URL(string: "tel://\(digits)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Sighting submission

/// Sheet for adding a new sighting. Captures the device's current
/// location at submit time + an optional free-text note. Writes to
/// `lost_dog_alerts/{alertId}/sightings/{new}` — the same path used
/// by `LostDogAlertSheet`.
private struct ReportSightingSheet: View {
    let alertId: String
    let dogName: String
    let onClose: () -> Void

    @State private var note: String = ""
    @State private var submitting = false
    @State private var errorMessage: String?
    @State private var didSubmit = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Reporting a sighting of \(dogName). Your current location will be attached so the owner can pinpoint where you saw the dog.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Section("Optional note") {
                    TextField("e.g. running west along the canal path", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundColor(.red).font(.caption) }
                }
                if didSubmit {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.seal.fill").foregroundColor(.green)
                            Text("Sighting reported. Thank you.")
                                .font(.subheadline.bold())
                        }
                    }
                }
            }
            .navigationTitle("Report sighting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onClose() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        submit()
                    } label: {
                        if submitting { ProgressView() } else { Text("Submit").bold() }
                    }
                    .disabled(submitting || didSubmit)
                }
            }
        }
    }

    private func submit() {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "Sign in to report a sighting"
            return
        }
        submitting = true
        errorMessage = nil
        Task {
            let loc = await currentLocationOrNil()
            var payload: [String: Any] = [
                "reportedBy": uid,
                "createdAt": FieldValue.serverTimestamp(),
                "alertId": alertId
            ]
            if let loc {
                payload["lat"] = loc.coordinate.latitude
                payload["lng"] = loc.coordinate.longitude
                payload["accuracy"] = loc.horizontalAccuracy
            }
            if !note.isEmpty { payload["note"] = note }
            do {
                _ = try await Firestore.firestore()
                    .collection("lost_dog_alerts")
                    .document(alertId)
                    .collection("sightings")
                    .addDocument(data: payload)
                await MainActor.run {
                    submitting = false
                    didSubmit = true
                }
                try? await Task.sleep(nanoseconds: 800_000_000)
                await MainActor.run { onClose() }
            } catch {
                await MainActor.run {
                    submitting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func currentLocationOrNil() async -> CLLocation? {
        let manager = CLLocationManager()
        let status = manager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            return nil
        }
        return manager.location
    }
}
