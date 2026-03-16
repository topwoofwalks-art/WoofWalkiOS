import XCTest
import CoreLocation

func XCTAssertCoordinateEqual(
    _ lhs: CLLocationCoordinate2D,
    _ rhs: CLLocationCoordinate2D,
    accuracy: Double = 0.0001,
    file: StaticString = #file,
    line: UInt = #line
) {
    XCTAssertEqual(lhs.latitude, rhs.latitude, accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(lhs.longitude, rhs.longitude, accuracy: accuracy, file: file, line: line)
}

func XCTAssertDistance(
    from start: CLLocationCoordinate2D,
    to end: CLLocationCoordinate2D,
    isGreaterThan threshold: Double,
    file: StaticString = #file,
    line: UInt = #line
) {
    let startLoc = CLLocation(latitude: start.latitude, longitude: start.longitude)
    let endLoc = CLLocation(latitude: end.latitude, longitude: end.longitude)
    let distance = startLoc.distance(from: endLoc)

    XCTAssertGreaterThan(distance, threshold, file: file, line: line)
}

func XCTAssertDistance(
    from start: CLLocationCoordinate2D,
    to end: CLLocationCoordinate2D,
    isLessThan threshold: Double,
    file: StaticString = #file,
    line: UInt = #line
) {
    let startLoc = CLLocation(latitude: start.latitude, longitude: start.longitude)
    let endLoc = CLLocation(latitude: end.latitude, longitude: end.longitude)
    let distance = startLoc.distance(from: endLoc)

    XCTAssertLessThan(distance, threshold, file: file, line: line)
}

func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ message: String = "",
    file: StaticString = #file,
    line: UInt = #line,
    _ errorHandler: (Error) -> Void = { _ in }
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error to be thrown", file: file, line: line)
    } catch {
        errorHandler(error)
    }
}

func XCTAssertNoThrowAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ message: String = "",
    file: StaticString = #file,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
    } catch {
        XCTFail("Unexpected error thrown: \(error)", file: file, line: line)
    }
}
