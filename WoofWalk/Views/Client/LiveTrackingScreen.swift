import SwiftUI
import MapKit
import CoreLocation
import Combine

// MARK: - Live Tracking Screen

struct LiveTrackingScreen: View {
    @StateObject private var viewModel: LiveTrackingViewModel
    @State private var showEmergencyDialog = false
    @State private var selectedPhoto: WalkPhotoUpdate?
    @State private var toastMessage: String?

    let onNavigateBack: () -> Void
    let onNavigateToChat: (String) -> Void

    init(
        walkId: String,
        onNavigateBack: @escaping () -> Void,
        onNavigateToChat: @escaping (String) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: LiveTrackingViewModel(walkId: walkId))
        self.onNavigateBack = onNavigateBack
        self.onNavigateToChat = onNavigateToChat
    }

    var body: some View {
        ZStack {
            mainContent
            toastOverlay
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onNavigateBack) {
                    Image(systemName: "chevron.left")
                }
            }
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Text("Live Tracking")
                        .font(.headline)
                    Image(systemName: viewModel.connectionStatus.icon)
                        .font(.caption)
                        .foregroundColor(viewModel.connectionStatus.color)
                }
            }
        }
        .alert("Emergency Contact", isPresented: $showEmergencyDialog) {
            if let walkerName = viewModel.walkSession?.walkerInfo.name,
               viewModel.walkSession?.walkerInfo.phoneNumber != nil {
                Button("Call \(walkerName)") {
                    viewModel.onCallWalkerClicked()
                }
            }
            Button("Call Emergency (999)", role: .destructive) {
                if let url = URL(string: "tel:999") {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose who to contact:")
        }
        .sheet(item: $selectedPhoto) { photo in
            PhotoDetailSheet(photo: photo)
        }
        .onReceive(viewModel.eventSubject) { event in
            handleEvent(event)
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        if viewModel.isLoading {
            loadingView
        } else if viewModel.walkSession == nil {
            errorView
        } else {
            trackingContent
        }
    }

    // MARK: - Tracking Content

    private var trackingContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Map
                if let session = viewModel.walkSession {
                    LiveTrackingMapSection(
                        session: session,
                        isExpanded: viewModel.isMapExpanded,
                        onToggleExpanded: { viewModel.toggleMapExpanded() }
                    )
                }

                VStack(spacing: 16) {
                    // Dog info card
                    if let dog = viewModel.dogInfo, let session = viewModel.walkSession {
                        DogInfoCard(dog: dog, walkerInfo: session.walkerInfo)
                    }

                    // Walk stats
                    if let session = viewModel.walkSession {
                        WalkStatsCard(stats: session.stats)
                    }

                    // Live activity feed
                    if let session = viewModel.walkSession {
                        LiveActivityFeedCard(events: session.activityEvents)
                    }

                    // ETA card
                    if let eta = viewModel.eta {
                        ETACard(eta: eta)
                    }

                    // Photos
                    if let session = viewModel.walkSession, !session.photos.isEmpty {
                        PhotosCard(
                            photos: session.photos,
                            onPhotoTapped: { selectedPhoto = $0 }
                        )
                    }

                    // Quick reply & actions
                    QuickReplyBar(
                        onSendMessage: { viewModel.sendQuickMessage($0) },
                        onOpenFullChat: { viewModel.onMessageWalkerClicked() },
                        onEmergencyContact: { showEmergencyDialog = true }
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Connecting to live tracking...")
                .font(.body)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    // MARK: - Error

    private var errorView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.red)
            Text("Connection Error")
                .font(.title2.bold())
                .foregroundColor(.red)
            Text(viewModel.error ?? "Walk session not found")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("Retry") {
                viewModel.refresh()
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }

    // MARK: - Toast Overlay

    @ViewBuilder
    private var toastOverlay: some View {
        if let message = toastMessage {
            VStack {
                Spacer()
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.black.opacity(0.8)))
                    .padding(.bottom, 60)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { toastMessage = nil }
                }
            }
        }
    }

    // MARK: - Event Handling

    private func handleEvent(_ event: LiveTrackingViewModel.Event) {
        switch event {
        case .showMessage(let message):
            withAnimation { toastMessage = message }
        case .navigateToChat(let walkerId):
            onNavigateToChat(walkerId)
        case .initiateCall(let phoneNumber):
            if let url = URL(string: "tel:\(phoneNumber)") {
                UIApplication.shared.open(url)
            }
        case .showEmergencyOptions:
            showEmergencyDialog = true
        }
    }
}

// MARK: - Map Section

@available(iOS 17.0, *)
private struct LiveTrackingMapSection17: View {
    let session: LiveWalkSession
    let isExpanded: Bool
    let onToggleExpanded: () -> Void

    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        ZStack(alignment: .topLeading) {
            Map(position: $cameraPosition) {
                // Route polyline
                if session.routePoints.count > 1 {
                    MapPolyline(coordinates: session.routePoints.map(\.coordinate))
                        .stroke(Color(hex: 0x4CAF50), lineWidth: 4)
                }

                // Home marker
                if let home = session.homeLocation {
                    Annotation("Home", coordinate: home) {
                        Image(systemName: "house.fill")
                            .foregroundColor(.blue)
                            .padding(6)
                            .background(Circle().fill(.white))
                            .shadow(radius: 2)
                    }
                }

                // Walker marker
                if let current = session.currentLocation {
                    Annotation(session.walkerInfo.name, coordinate: current.coordinate) {
                        WalkerMarkerView(heading: current.heading)
                    }
                }

                // Photo markers
                ForEach(session.photos.filter { $0.location != nil }) { photo in
                    if let loc = photo.location {
                        Annotation("Photo", coordinate: loc) {
                            Image(systemName: "camera.fill")
                                .font(.caption2)
                                .foregroundColor(.purple)
                                .padding(4)
                                .background(Circle().fill(.white))
                                .shadow(radius: 1)
                        }
                    }
                }
            }
            .mapStyle(.standard)
            .mapControls {
                MapCompass()
            }
            .frame(height: isExpanded ? 400 : 250)
            .animation(.easeInOut(duration: 0.3), value: isExpanded)
            .onChange(of: session.currentLocation) { _, newLocation in
                guard let loc = newLocation else { return }
                withAnimation(.easeInOut(duration: 0.5)) {
                    cameraPosition = .camera(MapCamera(
                        centerCoordinate: loc.coordinate,
                        distance: 1000
                    ))
                }
            }

            // Status badge
            WalkStatusBadge(status: session.status)
                .padding(8)

            // Expand button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: onToggleExpanded) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.bold())
                            .foregroundColor(.primary)
                            .padding(8)
                            .background(Circle().fill(.regularMaterial))
                            .shadow(radius: 2)
                    }
                    .padding(8)
                }
            }
            .frame(height: isExpanded ? 400 : 250)
        }
    }
}

/// Fallback for iOS 16
private struct LiveTrackingMapSectionLegacy: View {
    let session: LiveWalkSession
    let isExpanded: Bool
    let onToggleExpanded: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Simple map region based on walker location
            if let current = session.currentLocation {
                let region = MKCoordinateRegion(
                    center: current.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
                Map(coordinateRegion: .constant(region), annotationItems: mapAnnotations) { item in
                    MapAnnotation(coordinate: item.coordinate) {
                        if item.type == .walker {
                            WalkerMarkerView(heading: session.currentLocation?.heading)
                        } else if item.type == .home {
                            Image(systemName: "house.fill")
                                .foregroundColor(.blue)
                                .padding(6)
                                .background(Circle().fill(.white))
                                .shadow(radius: 2)
                        }
                    }
                }
                .frame(height: isExpanded ? 400 : 250)
                .animation(.easeInOut(duration: 0.3), value: isExpanded)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: isExpanded ? 400 : 250)
                    .overlay {
                        ProgressView("Waiting for location...")
                    }
            }

            WalkStatusBadge(status: session.status)
                .padding(8)

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: onToggleExpanded) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.bold())
                            .foregroundColor(.primary)
                            .padding(8)
                            .background(Circle().fill(.regularMaterial))
                            .shadow(radius: 2)
                    }
                    .padding(8)
                }
            }
            .frame(height: isExpanded ? 400 : 250)
        }
    }

    private enum AnnotationType {
        case walker, home
    }

    private struct MapItem: Identifiable {
        let id = UUID()
        let coordinate: CLLocationCoordinate2D
        let type: AnnotationType
    }

    private var mapAnnotations: [MapItem] {
        var items: [MapItem] = []
        if let current = session.currentLocation {
            items.append(MapItem(coordinate: current.coordinate, type: .walker))
        }
        if let home = session.homeLocation {
            items.append(MapItem(coordinate: home, type: .home))
        }
        return items
    }
}

/// Wrapper that picks iOS 17 or legacy map
private struct LiveTrackingMapSection: View {
    let session: LiveWalkSession
    let isExpanded: Bool
    let onToggleExpanded: () -> Void

    var body: some View {
        if #available(iOS 17.0, *) {
            LiveTrackingMapSection17(
                session: session,
                isExpanded: isExpanded,
                onToggleExpanded: onToggleExpanded
            )
        } else {
            LiveTrackingMapSectionLegacy(
                session: session,
                isExpanded: isExpanded,
                onToggleExpanded: onToggleExpanded
            )
        }
    }
}

// MARK: - Walker Marker

private struct WalkerMarkerView: View {
    let heading: Double?

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: 0x4CAF50).opacity(0.2))
                .frame(width: 40, height: 40)

            Circle()
                .fill(Color(hex: 0x4CAF50))
                .frame(width: 20, height: 20)
                .overlay {
                    if let heading {
                        Image(systemName: "location.north.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(heading))
                    } else {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                    }
                }
                .shadow(radius: 2)
        }
    }
}

// MARK: - Walk Status Badge

private struct WalkStatusBadge: View {
    let status: LiveWalkStatus

    var body: some View {
        HStack(spacing: 4) {
            if status == .active {
                Circle()
                    .fill(.white)
                    .frame(width: 6, height: 6)
            }
            Text(status.label)
                .font(.caption2.bold())
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(status.color))
    }
}

// MARK: - Dog Info Card

private struct DogInfoCard: View {
    let dog: LiveTrackingDogInfo
    let walkerInfo: WalkerInfo

    var body: some View {
        HStack(spacing: 16) {
            // Dog photo
            ZStack {
                Circle()
                    .fill(Color.turquoise90.opacity(0.5))
                    .frame(width: 64, height: 64)

                if let photoUrl = dog.photoUrl, let url = URL(string: photoUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 64, height: 64)
                                .clipShape(Circle())
                        default:
                            Image(systemName: "pawprint.fill")
                                .font(.title2)
                                .foregroundColor(.turquoise60)
                        }
                    }
                } else {
                    Image(systemName: "pawprint.fill")
                        .font(.title2)
                        .foregroundColor(.turquoise60)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(dog.name)
                    .font(.title3.bold())

                if let breed = dog.breed {
                    Text(breed)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "figure.walk")
                        .font(.caption)
                        .foregroundColor(.turquoise60)
                    Text("with \(walkerInfo.name)")
                        .font(.caption)
                        .foregroundColor(.turquoise60)
                }
            }

            Spacer()

            // Walker rating
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundColor(Color(hex: 0xFFB300))
                    Text(String(format: "%.1f", walkerInfo.rating))
                        .font(.subheadline.bold())
                }
                Text("Walker")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.turquoise90.opacity(0.2))
        )
    }
}

// MARK: - Walk Stats Card

private struct WalkStatsCard: View {
    let stats: LiveWalkStats

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Walk Stats")
                .font(.headline)

            HStack {
                StatItem(
                    icon: "point.topleft.down.to.point.bottomright.curvepath",
                    value: String(format: "%.2f", stats.distanceKm),
                    unit: "km",
                    label: "Distance"
                )
                Spacer()
                StatItem(
                    icon: "timer",
                    value: formatDuration(stats.durationSeconds),
                    unit: "",
                    label: "Duration"
                )
                Spacer()
                StatItem(
                    icon: "speedometer",
                    value: String(format: "%.1f", stats.averageSpeedKmh ?? 0.0),
                    unit: "km/h",
                    label: "Speed"
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        )
    }
}

private struct StatItem: View {
    let icon: String
    let value: String
    let unit: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.turquoise60)

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2.bold())
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - ETA Card

private struct ETACard: View {
    let eta: ETACalculation

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "clock.fill")
                .font(.system(size: 32))
                .foregroundColor(.turquoise60)

            VStack(alignment: .leading, spacing: 2) {
                Text("Estimated Return")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(timeFormatter.string(from: eta.estimatedReturnTime))
                    .font(.title2.bold())
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(eta.estimatedRemainingMinutes) min")
                    .font(.headline)
                    .foregroundColor(.turquoise60)
                Text(String(format: "%.1f km away", eta.remainingDistanceKm))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.turquoise95.opacity(0.4))
        )
    }
}

// MARK: - Live Activity Feed

private struct LiveActivityFeedCard: View {
    let events: [WalkActivityEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Live Activity")
                    .font(.headline)
                Spacer()
                if !events.isEmpty {
                    Text("\(events.count) events")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if events.isEmpty {
                Text("No activity yet")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                let sorted = events.sorted { $0.timestamp > $1.timestamp }
                ForEach(Array(sorted.enumerated()), id: \.element.id) { index, event in
                    ActivityEventRow(event: event)

                    if index < sorted.count - 1 {
                        Divider()
                            .padding(.vertical, 2)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        )
    }
}

private struct ActivityEventRow: View {
    let event: WalkActivityEvent

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(event.tintColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: event.icon)
                    .font(.system(size: 16))
                    .foregroundColor(event.tintColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(event.label)
                    .font(.subheadline.weight(.medium))

                if let note = event.note {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Text(timeFormatter.string(from: event.timestamp))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Photos Card

private struct PhotosCard: View {
    let photos: [WalkPhotoUpdate]
    let onPhotoTapped: (WalkPhotoUpdate) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .foregroundColor(.turquoise60)
                    Text("Walk Photos")
                        .font(.headline)
                }
                Spacer()
                Text("\(photos.count) photos")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(photos) { photo in
                        PhotoThumbnail(photo: photo) {
                            onPhotoTapped(photo)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        )
    }
}

private struct PhotoThumbnail: View {
    let photo: WalkPhotoUpdate
    let onTap: () -> Void

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: URL(string: photo.thumbnailUrl ?? photo.url)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Color.gray.opacity(0.3)
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                            }
                    default:
                        Color.gray.opacity(0.1)
                            .overlay { ProgressView() }
                    }
                }
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(timeFormatter.string(from: photo.timestamp))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.black.opacity(0.6))
                    )
                    .padding(4)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Photo Detail Sheet

private struct PhotoDetailSheet: View {
    let photo: WalkPhotoUpdate
    @Environment(\.dismiss) private var dismiss

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    AsyncImage(url: URL(string: photo.url)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        case .failure:
                            Color.gray.opacity(0.3)
                                .frame(height: 300)
                                .overlay {
                                    Image(systemName: "photo")
                                        .font(.largeTitle)
                                        .foregroundColor(.secondary)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        default:
                            Color.gray.opacity(0.1)
                                .frame(height: 300)
                                .overlay { ProgressView() }
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal)

                    if let caption = photo.caption {
                        Text(caption)
                            .font(.body)
                            .padding(.horizontal)
                    }

                    if let location = photo.location {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.4f, %.4f", location.latitude, location.longitude))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(timeFormatter.string(from: photo.timestamp))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Quick Reply Bar

private struct QuickReplyBar: View {
    let onSendMessage: (String) -> Void
    let onOpenFullChat: () -> Void
    let onEmergencyContact: () -> Void

    @State private var messageText = ""
    @State private var showQuickReplies = false

    private let quickReplies = [
        "How's the walk going?",
        "Please send a photo!",
        "Is everything okay?",
        "Please head home soon",
        "Give extra water please"
    ]

    var body: some View {
        VStack(spacing: 10) {
            // Message input
            HStack(spacing: 8) {
                HStack {
                    TextField("Message walker...", text: $messageText)
                        .font(.subheadline)
                        .textFieldStyle(.plain)

                    Button {
                        showQuickReplies.toggle()
                    } label: {
                        Image(systemName: "bolt.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )

                Button {
                    if !messageText.trimmingCharacters(in: .whitespaces).isEmpty {
                        onSendMessage(messageText.trimmingCharacters(in: .whitespaces))
                        messageText = ""
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(10)
                        .background(
                            Circle().fill(
                                messageText.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? Color.gray
                                    : Color.turquoise60
                            )
                        )
                }
                .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            // Quick replies
            if showQuickReplies {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(quickReplies, id: \.self) { reply in
                            Button {
                                onSendMessage(reply)
                                showQuickReplies = false
                            } label: {
                                Text(reply)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Action buttons
            HStack(spacing: 10) {
                Button(action: onOpenFullChat) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.caption2)
                        Text("Full Chat")
                            .font(.caption.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.turquoise60, lineWidth: 1)
                    )
                    .foregroundColor(.turquoise60)
                }

                Button(action: onEmergencyContact) {
                    HStack(spacing: 4) {
                        Image(systemName: "sos")
                            .font(.caption2)
                        Text("Emergency")
                            .font(.caption.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.red.opacity(0.1))
                    )
                    .foregroundColor(.red)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        )
        .animation(.easeInOut(duration: 0.2), value: showQuickReplies)
    }
}

// MARK: - Helpers

private func formatDuration(_ seconds: Int) -> String {
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    if hours > 0 {
        return String(format: "%d:%02d", hours, minutes)
    } else {
        return "\(minutes) min"
    }
}
