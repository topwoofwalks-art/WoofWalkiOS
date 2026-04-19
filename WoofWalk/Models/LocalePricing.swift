import Foundation

// MARK: - Top-level document

struct LocalePricing: Codable {
    let countries: [String: CountryPricing]
    let fallback: String

    init(countries: [String: CountryPricing] = [:], fallback: String = "GB") {
        self.countries = countries
        self.fallback = fallback
    }

    func pricing(for countryCode: String) -> CountryPricing {
        countries[countryCode] ?? countries[fallback] ?? CountryPricing()
    }
}

// MARK: - Country pricing

struct CountryPricing: Codable {
    let currency: String
    let symbol: String
    let walk: WalkPricing
    let grooming: GroomingPricing
    let boarding: BoardingPricing
    let training: TrainingPricing
    let daycare: DaycarePricing
    let sitting: SittingPricing

    init(
        currency: String = "GBP",
        symbol: String = "\u{00A3}",
        walk: WalkPricing = WalkPricing(),
        grooming: GroomingPricing = GroomingPricing(),
        boarding: BoardingPricing = BoardingPricing(),
        training: TrainingPricing = TrainingPricing(),
        daycare: DaycarePricing = DaycarePricing(),
        sitting: SittingPricing = SittingPricing()
    ) {
        self.currency = currency
        self.symbol = symbol
        self.walk = walk
        self.grooming = grooming
        self.boarding = boarding
        self.training = training
        self.daycare = daycare
        self.sitting = sitting
    }
}

// MARK: - Walk pricing

struct WalkPricing: Codable {
    let min15: Double
    let min30: Double
    let min45: Double
    let min60: Double
    let groupDiscount: Double

    init(
        min15: Double = 8,
        min30: Double = 12,
        min45: Double = 16,
        min60: Double = 20,
        groupDiscount: Double = 0.25
    ) {
        self.min15 = min15
        self.min30 = min30
        self.min45 = min45
        self.min60 = min60
        self.groupDiscount = groupDiscount
    }

    enum CodingKeys: String, CodingKey {
        case min15 = "15min"
        case min30 = "30min"
        case min45 = "45min"
        case min60 = "60min"
        case groupDiscount
    }
}

// MARK: - Size pricing (used by grooming sub-services)

struct SizePricing: Codable {
    let small: Double
    let medium: Double
    let large: Double
    let xl: Double

    init(
        small: Double = 0,
        medium: Double = 0,
        large: Double = 0,
        xl: Double = 0
    ) {
        self.small = small
        self.medium = medium
        self.large = large
        self.xl = xl
    }

    enum CodingKeys: String, CodingKey {
        case small = "S"
        case medium = "M"
        case large = "L"
        case xl = "XL"
    }
}

// MARK: - Grooming pricing

struct GroomingPricing: Codable {
    let bathAndDry: SizePricing
    let fullGroom: SizePricing
    let nailTrim: Double
    let puppyIntro: SizePricing
    let handStrip: SizePricing
    let deShed: SizePricing

    init(
        bathAndDry: SizePricing = SizePricing(small: 25, medium: 35, large: 45, xl: 55),
        fullGroom: SizePricing = SizePricing(small: 35, medium: 50, large: 65, xl: 80),
        nailTrim: Double = 12,
        puppyIntro: SizePricing = SizePricing(small: 20, medium: 25, large: 30, xl: 35),
        handStrip: SizePricing = SizePricing(small: 45, medium: 60, large: 75, xl: 90),
        deShed: SizePricing = SizePricing(small: 30, medium: 40, large: 50, xl: 60)
    ) {
        self.bathAndDry = bathAndDry
        self.fullGroom = fullGroom
        self.nailTrim = nailTrim
        self.puppyIntro = puppyIntro
        self.handStrip = handStrip
        self.deShed = deShed
    }
}

// MARK: - Boarding pricing

struct BoardingPricing: Codable {
    let standard: Double
    let premium: Double
    let luxury: Double

    init(standard: Double = 30, premium: Double = 45, luxury: Double = 65) {
        self.standard = standard
        self.premium = premium
        self.luxury = luxury
    }
}

// MARK: - Training pricing

struct TrainingPricing: Codable {
    let oneToOne: Double
    let groupClass: Double
    let boardAndTrain: Double
    let homeVisit: Double
    let online: Double

    init(
        oneToOne: Double = 50,
        groupClass: Double = 20,
        boardAndTrain: Double = 350,
        homeVisit: Double = 65,
        online: Double = 35
    ) {
        self.oneToOne = oneToOne
        self.groupClass = groupClass
        self.boardAndTrain = boardAndTrain
        self.homeVisit = homeVisit
        self.online = online
    }
}

// MARK: - Daycare pricing

struct DaycarePricing: Codable {
    let fullDay: Double
    let halfDay: Double

    init(fullDay: Double = 28, halfDay: Double = 18) {
        self.fullDay = fullDay
        self.halfDay = halfDay
    }
}

// MARK: - Sitting pricing

struct SittingPricing: Codable {
    let min30: Double
    let min60: Double
    let overnight: Double

    init(min30: Double = 12, min60: Double = 18, overnight: Double = 35) {
        self.min30 = min30
        self.min60 = min60
        self.overnight = overnight
    }

    enum CodingKeys: String, CodingKey {
        case min30 = "30min"
        case min60 = "60min"
        case overnight
    }
}
