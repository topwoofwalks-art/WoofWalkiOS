import XCTest
@testable import WoofWalk

/// Mathematical contract tests for WOOF_RANK on iOS. Mirrors the Kotlin
/// `BusinessRankerTest` assertions — same inputs, same expectations —
/// so any drift between the two implementations will surface as either
/// a red iOS CI build or a red Android Gradle check.
///
/// See `BUSINESS_SEARCH_AUDIT.md` (main repo) for the worked examples.
final class BusinessRankerTests: XCTestCase {

    /// 2026-04-22 anchor so tenure calculations are deterministic.
    private let now = Date(timeIntervalSince1970: 1_777_161_600)

    private func make(
        id: String = "p",
        isPartner: Bool = false,
        isExternal: Bool = false,
        distanceKm: Double? = 2.0,
        rating: Double = 4.2,
        reviewCount: Int = 3,
        daysVerified: Double? = nil,
        services: [String] = ["grooming"]
    ) -> ServiceProviderLite {
        let verifiedSince = daysVerified.map { Date(timeInterval: -$0 * 86_400, since: now) }
        var p = ServiceProviderLite(id: id, name: id)
        p.rating = rating
        p.reviewCount = reviewCount
        p.services = services
        p.distance = distanceKm
        p.isPartner = isPartner
        p.isExternal = isExternal
        p.verifiedSince = verifiedSince
        return p
    }

    // MARK: - Radius gate

    func testBeyondMaxRadiusScoresZero() {
        let london = make(id: "london", isPartner: true, distanceKm: 330, daysVerified: 400)
        XCTAssertEqual(BusinessRanker.score(london, queryService: .grooming, now: now), 0)
    }

    func testNegativeDistanceScoresZero() {
        let p = make(distanceKm: -1)
        XCTAssertEqual(BusinessRanker.score(p, queryService: .grooming, now: now), 0)
    }

    // MARK: - Distance dominance

    func testVerifiedFarLosesToUnclaimedNear() {
        let far = make(id: "v", isPartner: true, distanceKm: 20, daysVerified: 365)
        let near = make(id: "u", isExternal: true, distanceKm: 2)
        let sFar = BusinessRanker.score(far, queryService: .grooming, now: now)
        let sNear = BusinessRanker.score(near, queryService: .grooming, now: now)
        XCTAssertGreaterThan(sNear, sFar)
    }

    // MARK: - Tenure bonus

    func testTenureZeroOnDayOne() {
        let newbie = make(isPartner: true, daysVerified: 0)
        XCTAssertEqual(BusinessRanker.tenure(newbie, now: now), 1.0, accuracy: 0.0001)
    }

    func testTenureTenPercentAtOneYear() {
        let veteran = make(isPartner: true, daysVerified: 365)
        XCTAssertEqual(BusinessRanker.tenure(veteran, now: now), 1.10, accuracy: 0.0001)
    }

    func testTenurePlateausAfterOneYear() {
        let ancient = make(isPartner: true, daysVerified: 1000)
        XCTAssertEqual(BusinessRanker.tenure(ancient, now: now), 1.10, accuracy: 0.0001)
    }

    func testTenureIsOneForUnverified() {
        let claimed = make(isPartner: false, daysVerified: 500)
        XCTAssertEqual(BusinessRanker.tenure(claimed, now: now), 1.0, accuracy: 0.0001)
    }

    func testEarlyAdopterOutscoresNewVerified() {
        let early = make(id: "e", isPartner: true, daysVerified: 365)
        let new = make(id: "n", isPartner: true, daysVerified: 10)
        let sEarly = BusinessRanker.score(early, queryService: .grooming, now: now)
        let sNew = BusinessRanker.score(new, queryService: .grooming, now: now)
        XCTAssertGreaterThan(sEarly, sNew)
        let ratio = sEarly / sNew
        XCTAssertTrue((1.07...1.11).contains(ratio), "ratio \(ratio) outside expected 1.07..1.11")
    }

    // MARK: - Bayesian quality

    func testOneFiveStarLosesToFiftyFourAndAHalfStar() {
        let oneHit = make(rating: 5.0, reviewCount: 1)
        let established = make(rating: 4.5, reviewCount: 50)
        XCTAssertGreaterThan(
            BusinessRanker.quality(established),
            BusinessRanker.quality(oneHit)
        )
    }

    func testColdStartQualityEqualsPriorOverFive() {
        let newbie = make(rating: 0, reviewCount: 0)
        let expected = BusinessRanker.BAYESIAN_PRIOR_M / 5.0
        XCTAssertEqual(BusinessRanker.quality(newbie), expected, accuracy: 0.0001)
    }

    // MARK: - Relevance

    func testUnrelatedServiceFilteredOut() {
        let trainer = make(services: ["training"])
        XCTAssertEqual(
            BusinessRanker.score(trainer, queryService: .grooming, now: now),
            0
        )
    }

    func testRelatedServiceGetsFortyPercentMultiplier() {
        let daycare = make(services: ["daycare"])
        let exact = make(services: ["walking"])
        let sDay = BusinessRanker.score(daycare, queryService: .walk, now: now)
        let sExact = BusinessRanker.score(exact, queryService: .walk, now: now)
        XCTAssertEqual(sDay / sExact, 0.4, accuracy: 0.001)
    }

    // MARK: - rank() end-to-end

    func testRankFiltersZeroScoreAndSortsDescending() {
        let london = make(id: "london", isPartner: true, distanceKm: 330, daysVerified: 400)
        let localUnclaimed = make(id: "local-unclaimed", isExternal: true, distanceKm: 2)
        let localVerified = make(
            id: "local-verified",
            isPartner: true,
            distanceKm: 3,
            rating: 4.8,
            reviewCount: 50,
            daysVerified: 365
        )
        let ranked = BusinessRanker.rank(
            [london, localUnclaimed, localVerified],
            queryService: .grooming,
            now: now
        )
        XCTAssertEqual(ranked.count, 2)
        XCTAssertEqual(ranked[0].id, "local-verified")
        XCTAssertEqual(ranked[1].id, "local-unclaimed")
        XCTAssertFalse(ranked.contains { $0.id == "london" })
    }
}
