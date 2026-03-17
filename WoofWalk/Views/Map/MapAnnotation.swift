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
        switch poi.poiType {
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
            return Color(hex: 0x9E9E9E)
        case .landscape:
            return .orange
        case .accessNote:
            return .orange.opacity(0.7)
        case .livestock:
            return .purple
        case .wildlife:
            return .pink.opacity(0.8)
        case .amenity:
            return Color(hex: 0x607D8B)
        case .bench:
            return Color(hex: 0x03A9F4)
        case .picnicSite:
            return Color(hex: 0x4CAF50)
        case .picnicTable:
            return Color(hex: 0x4CAF50)
        case .attraction:
            return Color(hex: 0xFFC107)
        case .viewpoint:
            return Color(hex: 0xFF9800)
        case .dogFriendlyPub:
            return Color(hex: 0xFF8F00)
        case .dogFriendlyCafe:
            return Color(hex: 0x795548)
        case .dogFriendlyRestaurant:
            return Color(hex: 0xE53935)
        case .vet:
            return Color(hex: 0xD32F2F)
        case .toilet:
            return Color(hex: 0x1976D2)
        case .fountain:
            return Color(hex: 0x29B6F6)
        case .waterfall:
            return Color(hex: 0x00BCD4)
        case .shelter:
            return Color(hex: 0x6D4C41)
        case .other:
            return Color(hex: 0x9E9E9E)
        }
    }

    private var iconName: String {
        switch poi.poiType {
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
        case .bench:
            return "chair.fill"
        case .picnicSite:
            return "tent.fill"
        case .picnicTable:
            return "tablecells"
        case .attraction:
            return "star.fill"
        case .viewpoint:
            return "binoculars.fill"
        case .dogFriendlyPub:
            return "mug.fill"
        case .dogFriendlyCafe:
            return "cup.and.saucer.fill"
        case .dogFriendlyRestaurant:
            return "fork.knife"
        case .vet:
            return "cross.case.fill"
        case .toilet:
            return "figure.stand"
        case .fountain:
            return "drop.triangle.fill"
        case .waterfall:
            return "water.waves"
        case .shelter:
            return "house.fill"
        case .other:
            return "mappin"
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

@MainActor
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
        case bench
        case picnicSite
        case picnicTable
        case attraction
        case viewpoint
        case dogFriendlyPub
        case dogFriendlyCafe
        case dogFriendlyRestaurant
        case vet
        case toilet
        case fountain
        case waterfall
        case shelter
        case other
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
