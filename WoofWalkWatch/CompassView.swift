import SwiftUI
import CoreMotion
import CoreLocation

struct CompassView: View {
    @EnvironmentObject var sessionManager: WatchSessionManager

    @State private var heading: Double = 0
    @State private var currentWaypointIndex = 0
    @State private var showCarDirection = false

    private let motionManager = CMMotionManager()
    private let locationManager = CLLocationManager()

    var nextWaypoint: (waypoint: WatchWaypoint, distance: Double, bearing: Double)? {
        guard let route = sessionManager.activeRoute,
              currentWaypointIndex < route.waypoints.count else { return nil }
        let wp = route.waypoints[currentWaypointIndex]
        // Simplified - use CLLocation for distance/bearing
        return (waypoint: wp, distance: 0, bearing: 0)
    }

    var body: some View {
        VStack(spacing: 4) {
            // Waypoint info or car info
            if showCarDirection, let car = sessionManager.carLocation {
                Text("Back to car")
                    .font(.system(size: 10))
                    .foregroundColor(.blue)
            } else if let wp = nextWaypoint {
                Text(wp.waypoint.name)
                    .font(.system(size: 10))
                    .foregroundColor(Color("TealLight"))
                    .lineLimit(1)
            }

            // Compass circle
            ZStack {
                Circle()
                    .stroke(Color("TealLight").opacity(0.4), lineWidth: 2)
                    .frame(width: 140, height: 140)

                // Cardinal directions rotated by heading
                ForEach(["N", "E", "S", "W"], id: \.self) { dir in
                    let angle: Double = switch dir {
                    case "N": 0
                    case "E": 90
                    case "S": 180
                    case "W": 270
                    default: 0
                    }
                    Text(dir)
                        .font(.system(size: dir == "N" ? 16 : 12, weight: .bold))
                        .foregroundColor(dir == "N" ? .red : .white)
                        .offset(y: -52)
                        .rotationEffect(.degrees(angle - heading))
                }

                // Bearing text
                VStack {
                    Text("\(Int(heading))\u{00B0}")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 140, height: 140)

            // Toggle car/route
            if sessionManager.carLocation != nil {
                Button(showCarDirection ? "Show route" : "Find car") {
                    showCarDirection.toggle()
                }
                .font(.system(size: 10))
                .buttonStyle(.bordered)
            }
        }
        .onAppear {
            startHeadingUpdates()
        }
    }

    private func startHeadingUpdates() {
        if CLLocationManager.headingAvailable() {
            // Using CLLocationManager for heading on watchOS
        }
    }
}
