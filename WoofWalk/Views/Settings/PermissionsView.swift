import SwiftUI
import CoreLocation
import CoreMotion
import Photos
import UserNotifications

struct PermissionsView: View {
    @StateObject private var viewModel = PermissionsViewModel()

    var body: some View {
        List {
            locationSection
            motionSection
            photoSection
            notificationSection
        }
        .navigationTitle("Permissions")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.checkPermissions()
        }
    }

    private var locationSection: some View {
        Section {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.blue)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Location Services")
                        .font(.headline)
                    Text(viewModel.locationStatus.description)
                        .font(.caption)
                        .foregroundColor(viewModel.locationStatus.color)
                }

                Spacer()

                if !viewModel.locationStatus.isAuthorized {
                    Button("Enable") {
                        viewModel.openSettings()
                    }
                    .font(.caption)
                }
            }

            Text("WoofWalk needs location access to track your walks, show nearby hazards, and provide location-based alerts.")
                .font(.caption)
                .foregroundColor(.secondary)
        } header: {
            Text("Location")
        }
    }

    private var motionSection: some View {
        Section {
            HStack {
                Image(systemName: "figure.walk.motion")
                    .foregroundColor(.blue)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Motion & Fitness")
                        .font(.headline)
                    Text(viewModel.motionStatus.description)
                        .font(.caption)
                        .foregroundColor(viewModel.motionStatus.color)
                }

                Spacer()

                if !viewModel.motionStatus.isAuthorized {
                    Button("Open Settings") {
                        viewModel.openSettings()
                    }
                    .font(.caption)
                }
            }

            Text("Motion access lets WoofWalk read the hardware step counter to count steps and validate GPS movement. Without it, walk distance can drift when GPS is unreliable and step counts won't appear.")
                .font(.caption)
                .foregroundColor(.secondary)
        } header: {
            Text("Motion & Fitness")
        }
    }

    private var photoSection: some View {
        Section {
            HStack {
                Image(systemName: "photo.fill")
                    .foregroundColor(.blue)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Photo Library")
                        .font(.headline)
                    Text(viewModel.photoStatus.description)
                        .font(.caption)
                        .foregroundColor(viewModel.photoStatus.color)
                }

                Spacer()

                if !viewModel.photoStatus.isAuthorized {
                    Button("Enable") {
                        viewModel.openSettings()
                    }
                    .font(.caption)
                }
            }

            Text("Photo access is needed to attach images to hazard reports and POI submissions.")
                .font(.caption)
                .foregroundColor(.secondary)
        } header: {
            Text("Photos")
        }
    }

    private var notificationSection: some View {
        Section {
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundColor(.blue)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Notifications")
                        .font(.headline)
                    Text(viewModel.notificationStatus.description)
                        .font(.caption)
                        .foregroundColor(viewModel.notificationStatus.color)
                }

                Spacer()

                if !viewModel.notificationStatus.isAuthorized {
                    Button("Enable") {
                        viewModel.openSettings()
                    }
                    .font(.caption)
                }
            }

            Text("Notification permission allows you to receive alerts about nearby hazards and community updates.")
                .font(.caption)
                .foregroundColor(.secondary)
        } header: {
            Text("Notifications")
        }
    }
}

@MainActor
class PermissionsViewModel: ObservableObject {
    @Published var locationStatus: PermissionStatus = .notDetermined
    @Published var motionStatus: PermissionStatus = .notDetermined
    @Published var photoStatus: PermissionStatus = .notDetermined
    @Published var notificationStatus: PermissionStatus = .notDetermined

    private let locationManager = CLLocationManager()

    func checkPermissions() {
        checkLocationPermission()
        checkMotionPermission()
        checkPhotoPermission()
        checkNotificationPermission()
    }

    private func checkMotionPermission() {
        let status = CMMotionActivityManager.authorizationStatus()
        switch status {
        case .authorized:
            motionStatus = .authorized
        case .denied:
            motionStatus = .denied
        case .restricted:
            motionStatus = .restricted
        case .notDetermined:
            motionStatus = .notDetermined
        @unknown default:
            motionStatus = .notDetermined
        }
    }

    private func checkLocationPermission() {
        let status = locationManager.authorizationStatus
        switch status {
        case .authorizedAlways:
            locationStatus = .authorizedAlways
        case .authorizedWhenInUse:
            locationStatus = .authorizedWhenInUse
        case .denied:
            locationStatus = .denied
        case .restricted:
            locationStatus = .restricted
        case .notDetermined:
            locationStatus = .notDetermined
        @unknown default:
            locationStatus = .notDetermined
        }
    }

    private func checkPhotoPermission() {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .authorized, .limited:
            photoStatus = .authorized
        case .denied:
            photoStatus = .denied
        case .restricted:
            photoStatus = .restricted
        case .notDetermined:
            photoStatus = .notDetermined
        @unknown default:
            photoStatus = .notDetermined
        }
    }

    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional:
                    self.notificationStatus = .authorized
                case .denied:
                    self.notificationStatus = .denied
                case .notDetermined:
                    self.notificationStatus = .notDetermined
                @unknown default:
                    self.notificationStatus = .notDetermined
                }
            }
        }
    }

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

enum PermissionStatus {
    case notDetermined
    case restricted
    case denied
    case authorized
    case authorizedWhenInUse
    case authorizedAlways

    var description: String {
        switch self {
        case .notDetermined: return "Not Set"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorized: return "Authorized"
        case .authorizedWhenInUse: return "While Using App"
        case .authorizedAlways: return "Always"
        }
    }

    var color: Color {
        switch self {
        case .notDetermined: return .orange
        case .restricted, .denied: return .red
        case .authorized, .authorizedWhenInUse, .authorizedAlways: return .green
        }
    }

    var isAuthorized: Bool {
        switch self {
        case .authorized, .authorizedWhenInUse, .authorizedAlways: return true
        default: return false
        }
    }
}
