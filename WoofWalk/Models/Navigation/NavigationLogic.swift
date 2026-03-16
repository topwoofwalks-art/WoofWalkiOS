import Foundation
import CoreLocation

struct NavigationLogic {
    static let offRouteThresholdMeters: Double = 30.0
    static let stepCompletionThresholdMeters: Double = 15.0
    static let earthRadiusMeters: Double = 6371000.0

    static func calculateDistance(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> Double {
        let dLat = toRadians(to.latitude - from.latitude)
        let dLng = toRadians(to.longitude - from.longitude)

        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(toRadians(from.latitude)) * cos(toRadians(to.latitude)) *
                sin(dLng / 2) * sin(dLng / 2)

        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadiusMeters * c
    }

    static func calculateDistanceToPolyline(
        point: CLLocationCoordinate2D,
        polyline: [CLLocationCoordinate2D]
    ) -> Double {
        guard !polyline.isEmpty else { return Double.greatestFiniteMagnitude }
        guard polyline.count > 1 else { return calculateDistance(from: point, to: polyline[0]) }

        var minDistance = Double.greatestFiniteMagnitude

        for i in 0..<(polyline.count - 1) {
            let segmentStart = polyline[i]
            let segmentEnd = polyline[i + 1]
            let distance = distanceToLineSegment(
                point: point,
                lineStart: segmentStart,
                lineEnd: segmentEnd
            )

            if distance < minDistance {
                minDistance = distance
            }
        }

        return minDistance
    }

    static func distanceToLineSegment(
        point: CLLocationCoordinate2D,
        lineStart: CLLocationCoordinate2D,
        lineEnd: CLLocationCoordinate2D
    ) -> Double {
        let x0 = point.latitude
        let y0 = point.longitude
        let x1 = lineStart.latitude
        let y1 = lineStart.longitude
        let x2 = lineEnd.latitude
        let y2 = lineEnd.longitude

        let dx = x2 - x1
        let dy = y2 - y1

        if dx == 0.0 && dy == 0.0 {
            return calculateDistance(from: point, to: lineStart)
        }

        let t = ((x0 - x1) * dx + (y0 - y1) * dy) / (dx * dx + dy * dy)

        let closestPoint: CLLocationCoordinate2D
        if t < 0 {
            closestPoint = lineStart
        } else if t > 1 {
            closestPoint = lineEnd
        } else {
            closestPoint = CLLocationCoordinate2D(
                latitude: x1 + t * dx,
                longitude: y1 + t * dy
            )
        }

        return calculateDistance(from: point, to: closestPoint)
    }

    static func isOffRoute(
        userLocation: CLLocationCoordinate2D,
        polyline: [CLLocationCoordinate2D]
    ) -> Bool {
        let distance = calculateDistanceToPolyline(point: userLocation, polyline: polyline)
        return distance > offRouteThresholdMeters
    }

    static func shouldAdvanceToNextStep(
        userLocation: CLLocationCoordinate2D,
        stepEndLocation: CLLocationCoordinate2D
    ) -> Bool {
        let distance = calculateDistance(from: userLocation, to: stepEndLocation)
        return distance <= stepCompletionThresholdMeters
    }

    static func calculateRemainingStats(
        currentStepIndex: Int,
        steps: [RouteStep]
    ) -> (distance: Double, time: Int) {
        var remainingDistance = 0.0
        var remainingTime = 0

        for i in currentStepIndex..<steps.count {
            remainingDistance += steps[i].distance
            remainingTime += Int(steps[i].duration)
        }

        return (remainingDistance, remainingTime)
    }

    static func cleanHtmlInstruction(_ html: String) -> String {
        return html
            .replacingOccurrences(of: "<b>", with: "")
            .replacingOccurrences(of: "</b>", with: "")
            .replacingOccurrences(of: "<div style=\"font-size:0.9em\">", with: " ")
            .replacingOccurrences(of: "</div>", with: "")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func calculateETA(
        distanceMeters: Double,
        averageSpeedMps: Double = 1.4
    ) -> TimeInterval {
        return distanceMeters / averageSpeedMps
    }

    static func calculateBearing(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> Double {
        let lat1 = toRadians(from.latitude)
        let lat2 = toRadians(to.latitude)
        let dLng = toRadians(to.longitude - from.longitude)

        let y = sin(dLng) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng)

        let bearing = toDegrees(atan2(y, x))
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }

    static func isNearDestination(
        userLocation: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        thresholdMeters: Double = 20.0
    ) -> Bool {
        let distance = calculateDistance(from: userLocation, to: destination)
        return distance <= thresholdMeters
    }

    private static func toRadians(_ degrees: Double) -> Double {
        return degrees * .pi / 180.0
    }

    private static func toDegrees(_ radians: Double) -> Double {
        return radians * 180.0 / .pi
    }
}

extension NavigationLogic {
    static func decodePolyline(_ encoded: String) -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []
        var index = encoded.startIndex
        var lat = 0
        var lng = 0

        while index < encoded.endIndex {
            var b: Int
            var shift = 0
            var result = 0

            repeat {
                b = Int(encoded[index].asciiValue! - 63)
                index = encoded.index(after: index)
                result |= (b & 0x1f) << shift
                shift += 5
            } while b >= 0x20

            let dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1))
            lat += dlat

            shift = 0
            result = 0

            repeat {
                b = Int(encoded[index].asciiValue! - 63)
                index = encoded.index(after: index)
                result |= (b & 0x1f) << shift
                shift += 5
            } while b >= 0x20

            let dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1))
            lng += dlng

            let coordinate = CLLocationCoordinate2D(
                latitude: Double(lat) / 1E5,
                longitude: Double(lng) / 1E5
            )
            coordinates.append(coordinate)
        }

        return coordinates
    }

    static func encodePolyline(_ coordinates: [CLLocationCoordinate2D]) -> String {
        var result = ""
        var prevLat = 0
        var prevLng = 0

        for coordinate in coordinates {
            let lat = Int(coordinate.latitude * 1E5)
            let lng = Int(coordinate.longitude * 1E5)

            let dLat = lat - prevLat
            let dLng = lng - prevLng

            result += encodeValue(dLat)
            result += encodeValue(dLng)

            prevLat = lat
            prevLng = lng
        }

        return result
    }

    private static func encodeValue(_ value: Int) -> String {
        var v = value < 0 ? ~(value << 1) : (value << 1)
        var result = ""

        while v >= 0x20 {
            result += String(UnicodeScalar((0x20 | (v & 0x1f)) + 63)!)
            v >>= 5
        }

        result += String(UnicodeScalar(v + 63)!)
        return result
    }
}
