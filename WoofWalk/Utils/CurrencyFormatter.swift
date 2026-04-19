import Foundation

struct CurrencyFormatter {
    static let shared = CurrencyFormatter()

    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "GBP"
    }

    func formatPrice(_ amount: Double, code: String? = nil) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code ?? currencyCode
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
    }

    func formatDiscount(_ amount: Double, code: String? = nil) -> String {
        let formatted = formatPrice(amount, code: code)
        return "-\(formatted)"
    }

    func symbol(for code: String? = nil) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code ?? currencyCode
        formatter.locale = Locale.current
        return formatter.currencySymbol ?? "£"
    }

    /// Format an integer amount with currency symbol (e.g. for chart axis labels).
    func formatInteger(_ amount: Int, code: String? = nil) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code ?? currencyCode
        formatter.locale = Locale.current
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(symbol(for: code))\(amount)"
    }
}
