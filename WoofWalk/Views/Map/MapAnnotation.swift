import SwiftUI
import MapKit

struct POIMarkerView: View {
    let poi: POI

    var body: some View {
        ZStack {
            Circle()
                .fill(markerColor)
                .frame(width: 40, height: 40)
                .shadow(radius: 3)

            Image(systemName: iconName)
                .foregroundColor(.white)
                .font(.system(size: 20))
        }
    }

    private var markerColor: Color {
        switch poi.type {
        case .bin:
            return .green
        case .hazard:
            return .red
        case .water:
            return .blue
        case .dogPark:
            return .yellow
        case .park:
            return .green.opacity(0.7)
        case .church:
            return .pink
        case .landscape:
            return .orange
        case .accessNote:
            return .orange.opacity(0.7)
        case .livestock:
            return .purple
        case .wildlife:
            return .pink.opacity(0.8)
        case .amenity:
            return .cyan
        }
    }

    private var iconName: String {
        switch poi.type {
        case .bin:
            return "trash.fill"
        case .hazard:
            return "exclamationmark.triangle.fill"
        case .water:
            return "drop.fill"
        case .dogPark:
            return "figure.walk"
        case .park:
            return "tree.fill"
        case .church:
            return "building.2.fill"
        case .landscape:
            return "photo.fill"
        case .accessNote:
            return "info.circle.fill"
        case .livestock:
            return "leaf.fill"
        case .wildlife:
            return "hare.fill"
        case .amenity:
            return "mappin.circle.fill"
        }
    }
}

struct ClusteredAnnotationView: View {
    let count: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(.blue)
                .frame(width: 50, height: 50)
                .shadow(radius: 4)

            Text("\(count)")
                .foregroundColor(.white)
                .font(.system(size: 18, weight: .bold))
        }
    }
}

struct CustomAnnotation: Identifiable {
    let id = UUID()
    let title: String
    let coordinate: CLLocationCoordinate2D
    let type: AnnotationType

    enum AnnotationType {
        case poi(POI)
        case pooBag
        case publicDog
        case lostDog
        case car
    }
}

struct AnnotationCluster: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let annotations: [CustomAnnotation]

    var count: Int {
        annotations.count
    }
}

class AnnotationClusterManager: ObservableObject {
    @Published var clusters: [AnnotationCluster] = []

    private let clusteringDistance: CLLocationDistance = 50

    func cluster(annotations: [CustomAnnotation], visibleRegion: MKCoordinateRegion) {
        var unclustered = annotations
        var newClusters: [AnnotationCluster] = []

        while !unclustered.isEmpty {
            let annotation = unclustered.removeFirst()
            var clusterGroup = [annotation]

            unclustered = unclustered.filter { other in
                let distance = annotation.coordinate.distance(to: other.coordinate)
                if distance < clusteringDistance {
                    clusterGroup.append(other)
                    return false
                }
                return true
            }

            if clusterGroup.count > 1 {
                let centerCoordinate = calculateCenter(for: clusterGroup)
                let cluster = AnnotationCluster(
                    coordinate: centerCoordinate,
                    annotations: clusterGroup
                )
                newClusters.append(cluster)
            } else {
                let cluster = AnnotationCluster(
                    coordinate: annotation.coordinate,
                    annotations: clusterGroup
                )
                newClusters.append(cluster)
            }
        }

        clusters = newClusters
    }

    private func calculateCenter(for annotations: [CustomAnnotation]) -> CLLocationCoordinate2D {
        let totalLat = annotations.reduce(0.0) { $0 + $1.coordinate.latitude }
        let totalLon = annotations.reduce(0.0) { $0 + $1.coordinate.longitude }
        let count = Double(annotations.count)

        return CLLocationCoordinate2D(
            latitude: totalLat / count,
            longitude: totalLon / count
        )
    }
}

extension CLLocationCoordinate2D {
    func distance(to other: CLLocationCoordinate2D) -> CLLocationDistance {
        let from = CLLocation(latitude: latitude, longitude: longitude)
        let to = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return from.distance(from: to)
    }
}

struct MapPOI: Identifiable {
    let id: String
    let title: String
    let description: String
    let coordinate: CLLocationCoordinate2D
    let type: MapPOIType
    let voteUp: Int
    let voteDown: Int
    let createdAt: Date

    enum MapPOIType: String, CaseIterable {
        case bin
        case hazard
        case water
        case dogPark
        case park
        case church
        case landscape
        case accessNote
        case livestock
        case wildlife
        case amenity
    }
}

struct PooBagDrop: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let droppedAt: Date
    let notes: String?

    func ageMinutes() -> Int {
        let interval = Date().timeIntervalSince(droppedAt)
        return Int(interval / 60)
    }
}

struct PublicDog: Identifiable {
    let id: String
    let name: String
    let breed: String
    let coordinate: CLLocationCoordinate2D
    let isNervous: Bool
    let warningNote: String?
    let ownerName: String
    let photoURL: URL?
}

struct LostDog: Identifiable {
    let id: String
    let name: String
    let breed: String
    let coordinate: CLLocationCoordinate2D
    let description: String
    let locationDescription: String
    let reporterName: String
    let reporterPhone: String?
    let photoURL: URL?
    let reportedAt: Date
}
