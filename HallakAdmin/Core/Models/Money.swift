import Foundation

/// Money is always `{amount, currency, display}`. Show `display`; use `amount` only to sort or compare.
struct Money: Codable, Hashable {
    let amount: Double
    let currency: String
    let display: String

    var isZero: Bool { amount == 0 }
    var isLBP: Bool { currency.uppercased() == "LBP" }

    static func zero(_ currency: String = "USD") -> Money {
        Money(amount: 0, currency: currency, display: currency.uppercased() == "LBP" ? "0 LBP" : "$0")
    }
}

extension Money: Comparable {
    /// Compares amounts of the same currency; otherwise USD sorts before LBP.
    static func < (l: Money, r: Money) -> Bool {
        l.currency == r.currency ? l.amount < r.amount : l.currency > r.currency
    }
}
