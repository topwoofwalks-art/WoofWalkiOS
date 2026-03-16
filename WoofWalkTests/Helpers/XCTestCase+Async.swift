import XCTest

extension XCTestCase {
    func awaitPublisher<T: Publisher>(
        _ publisher: T,
        timeout: TimeInterval = 1.0,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> T.Output where T.Failure == Never {
        var result: T.Output?
        let expectation = self.expectation(description: "Awaiting publisher")

        let cancellable = publisher.first().sink { value in
            result = value
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout)
        cancellable.cancel()

        guard let unwrappedResult = result else {
            XCTFail("Publisher did not emit a value", file: file, line: line)
            throw TestError.publisherTimeout
        }

        return unwrappedResult
    }

    func waitForPublisher<T: Publisher>(
        _ publisher: T,
        timeout: TimeInterval = 1.0,
        file: StaticString = #file,
        line: UInt = #line
    ) throws where T.Failure == Never {
        let expectation = self.expectation(description: "Waiting for publisher")

        let cancellable = publisher.first().sink { _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout)
        cancellable.cancel()
    }

    func asyncTest(
        timeout: TimeInterval = 5.0,
        file: StaticString = #file,
        line: UInt = #line,
        _ block: @escaping () async throws -> Void
    ) {
        let expectation = self.expectation(description: "Async operation")

        Task {
            do {
                try await block()
                expectation.fulfill()
            } catch {
                XCTFail("Async test failed with error: \(error)", file: file, line: line)
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: timeout)
    }
}

enum TestError: Error {
    case publisherTimeout
    case asyncTimeout
}
