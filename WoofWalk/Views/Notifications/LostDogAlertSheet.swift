import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import CoreLocation

/// In-app sheet shown when the FCM lost-dog topic fires while the app
/// is foregrounded. Mirrors `LostDogAlertDialog.kt` on Android — dog
/// photo, name, breed, last-known location, "Saw it" / "Dismiss" CTAs.
///
/// Payload keys come from the FCM data block sent by the
/// `lost_dog_alert` topic publisher (functions/src/index.ts ~856). Every
/// field is optional except `lostDogId` (used to write the sighting
/// back); we render best-effort with whatever the payload carries.
struct LostDogAlertSheet: View {
    let payload: [AnyHashable: Any]
    let onDismiss: () -> Void

    @State private var isSubmittingSighting = false
    @State private var submissionError: String?
    @State private var didSubmit = false

    private var alertId: String? {
        (payload["lostDogId"] as? String) ?? (payload["alertId"] as? String)
    }

    private var dogName: String {
        (payload["dogName"] as? String) ?? "A local dog"
    }

    private var dogBreed: String? {
        payload["dogBreed"] as? String
    }

    private var dogPhotoUrl: String? {
        (payload["dogPhotoUrl"] as? String) ?? (payload["photoUrl"] as? String)
    }

    private var locationDescription: String? {
        (payload["locationDescription"] as? String) ?? (payload["lastSeenLocation"] as? String)
    }

    private var alertLat: Double? {
        if let s = payload["lat"] as? String { return Double(s) }
        return payload["lat"] as? Double
    }

    private var alertLng: Double? {
        if let s = (payload["lng"] as? String) ?? (payload["lon"] as? String) { return Double(s) }
        return (payload["lng"] as? Double) ?? (payload["lon"] as? Double)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)

                    Text("Lost dog nearby")
                        .font(.title2.bold())

                    Text("\(dogName)\(dogBreed.map { " — \($0)" } ?? "")")
                        .font(.headline)
                        .multilineTextAlignment(.center)

                    if let urlString = dogPhotoUrl, let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(height: 180)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 220)
                                    .clipped()
                                    .cornerRadius(12)
                            case .failure:
                                Image(systemName: "photo")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                    .frame(height: 180)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }

                    if let location = locationDescription, !location.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundColor(.secondary)
                            Text("Last seen: \(location)")
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                        }
                    }

                    Text("Keep an eye out. If you spot this dog, tap below so the owner is alerted with your current location.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    if let error = submissionError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }

                    if didSubmit {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                            Text("Sighting reported. Thank you.")
                                .font(.subheadline.bold())
                        }
                        .padding(.vertical, 12)
                    } else {
                        Button {
                            submitSighting()
                        } label: {
                            HStack(spacing: 8) {
                                if isSubmittingSighting {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "eye.fill")
                                }
                                Text("I've seen this dog")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.orange)
                            )
                        }
                        .disabled(isSubmittingSighting || alertId == nil)
                    }

                    Button("Dismiss") { onDismiss() }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(24)
            }
            .navigationTitle("Lost Dog Alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { onDismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func submitSighting() {
        guard let alertId else {
            submissionError = "Missing alert id"
            return
        }
        guard let uid = Auth.auth().currentUser?.uid else {
            submissionError = "Sign in to report a sighting"
            return
        }
        isSubmittingSighting = true
        submissionError = nil

        Task {
            let currentLocation = await currentLocationOrNil()
            var data: [String: Any] = [
                "reportedBy": uid,
                "createdAt": FieldValue.serverTimestamp(),
                "alertId": alertId
            ]
            if let loc = currentLocation {
                data["lat"] = loc.coordinate.latitude
                data["lng"] = loc.coordinate.longitude
                data["accuracy"] = loc.horizontalAccuracy
            } else if let lat = alertLat, let lng = alertLng {
                data["lat"] = lat
                data["lng"] = lng
            }

            do {
                _ = try await Firestore.firestore()
                    .collection("lost_dog_alerts")
                    .document(alertId)
                    .collection("sightings")
                    .addDocument(data: data)
                await MainActor.run {
                    self.isSubmittingSighting = false
                    self.didSubmit = true
                }
            } catch {
                await MainActor.run {
                    self.isSubmittingSighting = false
                    self.submissionError = error.localizedDescription
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
