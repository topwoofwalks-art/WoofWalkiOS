import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
class WalkHistoryViewModel: ObservableObject {
    @Published var walks: [WalkHistory] = []
    @Published var selectedWalk: WalkHistory?
    @Published var statistics: WalkStatsSummary?
    @Published var isLoading = false
    @Published var error: String?

    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    private var walksListener: ListenerRegistration?

    deinit {
        walksListener?.remove()
    }

    func loadWalks() {
        guard let userId = Auth.auth().currentUser?.uid else {
            error = "User not authenticated"
            return
        }

        isLoading = true
        walksListener?.remove()

        walksListener = db.collection("users").document(userId)
            .collection("walks")
            .order(by: "startedAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    self.error = error.localizedDescription
                    self.isLoading = false
                    return
                }

                guard let documents = snapshot?.documents else {
                    self.isLoading = false
                    return
                }

                self.walks = documents.compactMap { doc in
                    try? doc.data(as: WalkHistory.self)
                }

                self.calculateStatistics()
                self.isLoading = false
            }
    }

    func refresh() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        isLoading = true

        do {
            let snapshot = try await db.collection("users").document(userId)
                .collection("walks")
                .order(by: "startedAt", descending: true)
                .getDocuments()

            walks = snapshot.documents.compactMap { doc in
                try? doc.data(as: WalkHistory.self)
            }

            calculateStatistics()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func selectWalk(walkId: String) {
        isLoading = true

        guard let userId = Auth.auth().currentUser?.uid else {
            error = "User not authenticated"
            isLoading = false
            return
        }

        db.collection("users").document(userId)
            .collection("walks").document(walkId)
            .getDocument { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    self.error = error.localizedDescription
                    self.isLoading = false
                    return
                }

                guard let snapshot = snapshot else {
                    self.isLoading = false
                    return
                }

                self.selectedWalk = try? snapshot.data(as: WalkHistory.self)
                self.isLoading = false
            }
    }

    func deleteWalk(walkId: String) {
        isLoading = true

        guard let userId = Auth.auth().currentUser?.uid else {
            error = "User not authenticated"
            isLoading = false
            return
        }

        db.collection("users").document(userId)
            .collection("walks").document(walkId)
            .delete { [weak self] error in
                guard let self = self else { return }

                if let error = error {
                    self.error = "Failed to delete walk: \(error.localizedDescription)"
                } else {
                    if let index = self.walks.firstIndex(where: { $0.id == walkId }) {
                        self.walks.remove(at: index)
                    }
                    self.calculateStatistics()
                }

                self.isLoading = false
            }
    }

    func exportWalkGpx(walkId: String) {
        guard let walk = walks.first(where: { $0.id == walkId }) else {
            error = "Walk not found"
            return
        }

        let gpxContent = generateGpx(walk: walk)

        let fileName = "walk_\(walkId).gpx"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try gpxContent.write(to: tempURL, atomically: true, encoding: .utf8)

            let activityVC = UIActivityViewController(
                activityItems: [tempURL],
                applicationActivities: nil
            )

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        } catch {
            self.error = "Failed to export GPX: \(error.localizedDescription)"
        }
    }

    private func generateGpx(walk: WalkHistory) -> String {
        var gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="WoofWalk">
          <metadata>
            <name>Walk \(walk.id ?? "")</name>
            <time>\(ISO8601DateFormatter().string(from: walk.startedAt?.dateValue() ?? Date()))</time>
          </metadata>
          <trk>
            <name>Walk Track</name>
            <trkseg>
        """

        for point in walk.track {
            let date = Date(timeIntervalSince1970: TimeInterval(point.t) / 1000.0)
            let time = ISO8601DateFormatter().string(from: date)
            gpx += """

                  <trkpt lat="\(point.lat)" lon="\(point.lng)">
                    <time>\(time)</time>
                  </trkpt>
            """
        }

        gpx += """

            </trkseg>
          </trk>
        </gpx>
        """

        return gpx
    }

    private func calculateStatistics() {
        guard !walks.isEmpty else {
            statistics = nil
            return
        }

        let totalDistance = walks.reduce(0) { $0 + $1.distanceMeters }
        let totalDuration = walks.reduce(0) { $0 + $1.durationSec }
        let avgSpeed = totalDuration > 0 ?
            (Double(totalDistance) / 1000.0) / (Double(totalDuration) / 3600.0) : 0.0

        statistics = WalkStatsSummary(
            totalWalks: walks.count,
            totalDistanceMeters: Double(totalDistance),
            avgSpeedKmh: avgSpeed
        )
    }

    func clearError() {
        error = nil
    }
}
