import Foundation

struct Geohash {
    static func encode(latitude: Double, longitude: Double, precision length: Int = 6) -> String {
        let base32 = "0123456789bcdefghjkmnpqrstuvwxyz"
        var latRange = (-90.0, 90.0)
        var lngRange = (-180.0, 180.0)
        var hash = ""
        var isEven = true
        var bit = 0
        var ch = 0

        while hash.count < length {
            if isEven {
                let mid = (lngRange.0 + lngRange.1) / 2
                if longitude > mid {
                    ch |= (1 << (4 - bit))
                    lngRange.0 = mid
                } else {
                    lngRange.1 = mid
                }
            } else {
                let mid = (latRange.0 + latRange.1) / 2
                if latitude > mid {
                    ch |= (1 << (4 - bit))
                    latRange.0 = mid
                } else {
                    latRange.1 = mid
                }
            }
            isEven.toggle()
            bit += 1
            if bit == 5 {
                let index = base32.index(base32.startIndex, offsetBy: ch)
                hash.append(base32[index])
                bit = 0
                ch = 0
            }
        }
        return hash
    }

    /// Returns geohash query bounds for a given center and radius.
    /// Each bound is a (startHash, endHash) tuple suitable for Firestore range queries.
    static func queryBounds(latitude: Double, longitude: Double, radiusKm: Double) -> [(String, String)] {
        let precision = radiusKm < 1 ? 7 : (radiusKm < 5 ? 6 : 5)

        // Approximate degree offset for the radius
        let latOffset = radiusKm / 110.574
        let lngOffset = radiusKm / (111.320 * cos(latitude * .pi / 180.0))

        let minLat = latitude - latOffset
        let maxLat = latitude + latOffset
        let minLng = longitude - lngOffset
        let maxLng = longitude + lngOffset

        let sw = encode(latitude: minLat, longitude: minLng, precision: precision)
        let ne = encode(latitude: maxLat, longitude: maxLng, precision: precision)

        // If the hashes share a prefix, we can use a single range query
        if sw <= ne {
            return [(sw, ne + "~")]
        } else {
            return [(ne, ne + "~"), (sw, sw + "~")]
        }
    }
}
