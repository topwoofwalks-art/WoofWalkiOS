import Foundation

enum Constants {
    enum Firebase {
        static let usersCollection = "users"
        static let walksCollection = "walks"
        static let dogsCollection = "dogs"
        static let poisCollection = "pois"
        static let postsCollection = "posts"
    }

    enum Location {
        static let defaultLatitude = 51.5074
        static let defaultLongitude = -0.1278
        static let trackingDistanceFilter = 10.0
        static let mapZoomLevel = 15.0
    }

    enum Walk {
        static let minimumDistance = 0.01
        static let pauseTimeout = 300
    }

    enum API {
        static let baseURL = "YOUR_API_URL"
        static let timeout: TimeInterval = 30
    }
}
