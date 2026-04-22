import Foundation

/// WOOF_RANK — iOS mirror of `BusinessRanker.kt`. Identical constants and
/// math so Android and iOS produce the same ordering on the same input.
/// See `BUSINESS_SEARCH_AUDIT.md` at the Android repo root for the full
/// rationale.
///
/// `score(_:queryService:now:)` returns the product of four bounded factors:
///
///     Dist      = exp(-d / DISTANCE_HALF_LIFE_KM)
///     Relevance = 1.0 exact / 0.4 related / 0.0 otherwise
///     Quality   = (n · r + C · m) / (n + C)   (normalised to 0…1)
///     Trust     = BaseTrust × Tenure
///                 BaseTrust:  1.20 verified, 1.00 claimed, 0.85 unclaimed
///                 Tenure:     1 + min(1, daysVerified / 365) × 0.10
///
/// A hard radius gate at `MAX_RADIUS_KM` zero-scores providers further
/// than 50 km before computing anything else.
enum BusinessRanker {

    static let MAX_RADIUS_KM: Double = 50.0
    static let DISTANCE_HALF_LIFE_KM: Double = 10.0

    static let BAYESIAN_PRIOR_M: Double = 4.2
    static let BAYESIAN_CONFIDENCE_C: Double = 20.0

    static let TRUST_VERIFIED: Double = 1.20
    static let TRUST_CLAIMED: Double = 1.00
    static let TRUST_UNCLAIMED: Double = 0.85

    static let MAX_TENURE_BOOST: Double = 0.10
    static let TENURE_RAMP_DAYS: Double = 365.0

    static let RELEVANCE_EXACT: Double = 1.0
    static let RELEVANCE_RELATED: Double = 0.4

    /// Score a single provider. Returns 0 for unrankable providers — out
    /// of radius, irrelevant, or suspended.
    static func score(
        _ provider: ServiceProviderLite,
        queryService: DiscoveryServiceType?,
        now: Date = Date()
    ) -> Double {
        guard let d = provider.distance, d >= 0, d <= MAX_RADIUS_KM else { return 0 }

        let rel = relevance(provider, query: queryService)
        if rel == 0 { return 0 }

        let dist = exp(-d / DISTANCE_HALF_LIFE_KM)
        let qual = quality(provider)
        let trust = trust(provider, now: now)
        return dist * rel * qual * trust
    }

    /// Rank a list by WOOF_RANK, highest first. Drops zero-score results.
    static func rank(
        _ providers: [ServiceProviderLite],
        queryService: DiscoveryServiceType?,
        now: Date = Date()
    ) -> [ServiceProviderLite] {
        return providers
            .map { ($0, score($0, queryService: queryService, now: now)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
    }

    // MARK: - Components

    static func relevance(
        _ provider: ServiceProviderLite,
        query: DiscoveryServiceType?
    ) -> Double {
        guard let query = query, query != .all else { return RELEVANCE_EXACT }
        // If the provider has no services declared we assume the caller
        // has already filtered by category and let it pass as exact.
        if provider.services.isEmpty { return RELEVANCE_EXACT }

        let queryName = query.rawValue.lowercased()
        let providerServices = provider.services.map { $0.lowercased() }

        if providerServices.contains(queryName) { return RELEVANCE_EXACT }
        if providerServices.contains(where: { related(queryName, $0) }) {
            return RELEVANCE_RELATED
        }
        return 0
    }

    static func quality(_ provider: ServiceProviderLite) -> Double {
        let n = Double(provider.reviewCount ?? 0)
        let r = max(0, min(5, provider.rating ?? 0))
        let bayes = (n * r + BAYESIAN_CONFIDENCE_C * BAYESIAN_PRIOR_M) /
                    (n + BAYESIAN_CONFIDENCE_C)
        return bayes / 5.0
    }

    static func trust(_ provider: ServiceProviderLite, now: Date) -> Double {
        let base = baseTrust(provider)
        if base == 0 { return 0 }
        return base * tenure(provider, now: now)
    }

    static func baseTrust(_ provider: ServiceProviderLite) -> Double {
        if provider.isPartner { return TRUST_VERIFIED }
        if provider.isExternal { return TRUST_UNCLAIMED }
        return TRUST_CLAIMED
    }

    static func tenure(_ provider: ServiceProviderLite, now: Date) -> Double {
        guard provider.isPartner, let since = provider.verifiedSince else { return 1 }
        let days = max(0, now.timeIntervalSince(since)) / 86_400.0
        let fraction = min(1.0, days / TENURE_RAMP_DAYS)
        return 1.0 + fraction * MAX_TENURE_BOOST
    }

    // MARK: - Service-type relatedness

    private static func related(_ query: String, _ offered: String) -> Bool {
        let sittingLike: Set<String> = ["sitting", "in-home sitting", "out-home sitting", "pet sitting"]
        switch query {
        case "walking":
            return offered == "daycare" || sittingLike.contains(offered)
        case "daycare":
            return offered == "walking" || sittingLike.contains(offered)
        case let q where sittingLike.contains(q):
            return offered == "walking" || offered == "daycare" || offered == "boarding" || sittingLike.contains(offered)
        case "boarding":
            return sittingLike.contains(offered) || offered == "daycare"
        case "grooming", "training", "vet":
            return false
        default:
            return false
        }
    }
}
