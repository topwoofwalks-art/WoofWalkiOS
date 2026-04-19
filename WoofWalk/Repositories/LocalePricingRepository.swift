import Foundation
import FirebaseFirestore

class LocalePricingRepository: ObservableObject {
    static let shared = LocalePricingRepository()

    @Published private(set) var localePricing: LocalePricing?
    private let db = Firestore.firestore()

    func fetchPricing() async -> LocalePricing {
        if let cached = localePricing { return cached }

        do {
            let doc = try await db.collection("config").document("locale_pricing").getDocument()
            guard let data = doc.data() else { return LocalePricing() }

            let pricing = parsePricing(from: data)
            await MainActor.run { self.localePricing = pricing }
            return pricing
        } catch {
            print("Failed to fetch locale pricing: \(error)")
            return LocalePricing()
        }
    }

    func pricingForCurrentLocale() async -> CountryPricing {
        let pricing = await fetchPricing()
        let country = Locale.current.region?.identifier ?? "GB"
        return pricing.pricing(for: country)
    }

    // MARK: - Manual parsing

    /// Parses the raw Firestore document into typed models.
    /// Manual parsing is required because Firestore keys like "15min" and "30min"
    /// aren't handled automatically by `Codable` when decoding from `[String: Any]`.
    private func parsePricing(from data: [String: Any]) -> LocalePricing {
        let fallback = data["fallback"] as? String ?? "GB"
        var countries: [String: CountryPricing] = [:]

        if let countriesMap = data["countries"] as? [String: Any] {
            for (code, value) in countriesMap {
                if let countryData = value as? [String: Any] {
                    countries[code] = parseCountryPricing(from: countryData)
                }
            }
        }

        return LocalePricing(countries: countries, fallback: fallback)
    }

    private func parseCountryPricing(from data: [String: Any]) -> CountryPricing {
        CountryPricing(
            currency: data["currency"] as? String ?? "GBP",
            symbol: data["symbol"] as? String ?? "\u{00A3}",
            walk: parseWalkPricing(from: data["walk"] as? [String: Any] ?? [:]),
            grooming: parseGroomingPricing(from: data["grooming"] as? [String: Any] ?? [:]),
            boarding: parseBoardingPricing(from: data["boarding"] as? [String: Any] ?? [:]),
            training: parseTrainingPricing(from: data["training"] as? [String: Any] ?? [:]),
            daycare: parseDaycarePricing(from: data["daycare"] as? [String: Any] ?? [:]),
            sitting: parseSittingPricing(from: data["sitting"] as? [String: Any] ?? [:])
        )
    }

    // MARK: - Walk

    private func parseWalkPricing(from data: [String: Any]) -> WalkPricing {
        WalkPricing(
            min15: doubleValue(data["15min"]),
            min30: doubleValue(data["30min"]),
            min45: doubleValue(data["45min"]),
            min60: doubleValue(data["60min"]),
            groupDiscount: doubleValue(data["groupDiscount"], default: 0.25)
        )
    }

    // MARK: - Grooming

    private func parseGroomingPricing(from data: [String: Any]) -> GroomingPricing {
        GroomingPricing(
            bathAndDry: parseSizePricing(from: data["bathAndDry"] as? [String: Any] ?? [:]),
            fullGroom: parseSizePricing(from: data["fullGroom"] as? [String: Any] ?? [:]),
            nailTrim: doubleValue(data["nailTrim"], default: 12),
            puppyIntro: parseSizePricing(from: data["puppyIntro"] as? [String: Any] ?? [:]),
            handStrip: parseSizePricing(from: data["handStrip"] as? [String: Any] ?? [:]),
            deShed: parseSizePricing(from: data["deShed"] as? [String: Any] ?? [:])
        )
    }

    private func parseSizePricing(from data: [String: Any]) -> SizePricing {
        SizePricing(
            small: doubleValue(data["S"]),
            medium: doubleValue(data["M"]),
            large: doubleValue(data["L"]),
            xl: doubleValue(data["XL"])
        )
    }

    // MARK: - Boarding

    private func parseBoardingPricing(from data: [String: Any]) -> BoardingPricing {
        BoardingPricing(
            standard: doubleValue(data["standard"], default: 30),
            premium: doubleValue(data["premium"], default: 45),
            luxury: doubleValue(data["luxury"], default: 65)
        )
    }

    // MARK: - Training

    private func parseTrainingPricing(from data: [String: Any]) -> TrainingPricing {
        TrainingPricing(
            oneToOne: doubleValue(data["oneToOne"], default: 50),
            groupClass: doubleValue(data["groupClass"], default: 20),
            boardAndTrain: doubleValue(data["boardAndTrain"], default: 350),
            homeVisit: doubleValue(data["homeVisit"], default: 65),
            online: doubleValue(data["online"], default: 35)
        )
    }

    // MARK: - Daycare

    private func parseDaycarePricing(from data: [String: Any]) -> DaycarePricing {
        DaycarePricing(
            fullDay: doubleValue(data["fullDay"], default: 28),
            halfDay: doubleValue(data["halfDay"], default: 18)
        )
    }

    // MARK: - Sitting

    private func parseSittingPricing(from data: [String: Any]) -> SittingPricing {
        SittingPricing(
            min30: doubleValue(data["30min"], default: 12),
            min60: doubleValue(data["60min"], default: 18),
            overnight: doubleValue(data["overnight"], default: 35)
        )
    }

    // MARK: - Helpers

    /// Safely extracts a `Double` from a Firestore value that may be `Int`, `Double`, or `NSNumber`.
    private func doubleValue(_ value: Any?, default fallback: Double = 0) -> Double {
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        if let n = value as? NSNumber { return n.doubleValue }
        return fallback
    }
}
