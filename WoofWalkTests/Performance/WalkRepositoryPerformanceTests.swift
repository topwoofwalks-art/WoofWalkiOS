import XCTest
@testable import WoofWalk

@MainActor
final class WalkRepositoryPerformanceTests: XCTestCase {
    var repository: MockWalkRepository!

    override func setUp() {
        super.setUp()
        repository = MockWalkRepository()
    }

    override func tearDown() {
        repository = nil
        super.tearDown()
    }

    func testInsertPerformance() {
        measure {
            for i in 0..<100 {
                let walk = TestDataBuilder.createTestWalk(id: "perf-walk-\(i)")
                try? repository.insert(walk)
            }
            try? repository.deleteAll()
        }
    }

    func testBatchInsertPerformance() {
        let walks = (0..<100).map { i in
            TestDataBuilder.createTestWalk(id: "batch-walk-\(i)")
        }

        measure {
            try? repository.insertAll(walks)
            try? repository.deleteAll()
        }
    }

    func testQueryPerformance() {
        let walks = (0..<1000).map { i in
            TestDataBuilder.createTestWalk(id: "query-walk-\(i)", userId: "user-1")
        }
        try? repository.insertAll(walks)

        measure {
            _ = try? repository.getUserWalks("user-1")
        }
    }

    func testAggregatePerformance() {
        let walks = (0..<500).map { i in
            TestDataBuilder.createTestWalk(
                id: "agg-walk-\(i)",
                userId: "user-1",
                distanceMeters: 5000,
                durationSec: 3600
            )
        }
        try? repository.insertAll(walks)

        measure {
            _ = try? repository.getTotalDistance("user-1")
            _ = try? repository.getTotalDuration("user-1")
            _ = try? repository.getWalkCount("user-1")
        }
    }

    func testDeletePerformance() {
        let walks = (0..<100).map { i in
            TestDataBuilder.createTestWalk(id: "delete-walk-\(i)")
        }
        try? repository.insertAll(walks)

        measure {
            for walk in walks {
                try? repository.deleteById(walk.id)
            }
        }
    }
}
