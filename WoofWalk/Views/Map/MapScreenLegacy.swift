#if false
import SwiftUI
import MapKit
import CoreLocation

/// Fallback map screen for iOS 16 that uses the pre-iOS 17 Map API.
/// On iOS 17+, the full MapScreen with MapCameraPosition is used instead.
struct MapScreenLegacy: View {
    @StateObject private var locationManager = LocationManager()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )

    var body: some View {
        ZStack {
            Map(coordinateRegion: $region, showsUserLocation: true)
                .ignoresSafeArea()

            VStack {
                Spacer()
                Text("Upgrade to iOS 17+ for the full map experience")
                    .font(.caption)
                    .padding(8)
                    .background(.regularMaterial)
                    .cornerRadius(8)
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            locationManager.startUpdatingLocation()
        }
        .onChange(of: locationManager.location) { newLocation in
            if let coord = newLocation {
                region.center = coord
            }
        }
    }
}

#endif
