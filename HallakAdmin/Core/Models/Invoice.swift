import Foundation

enum InvoiceStatus: String, Decodable, CaseIterable, Hashable {
    case unpaid, paid, void, unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = InvoiceStatus(rawValue: raw) ?? .unknown
    }
}

/// Payment methods. The platform never takes card payments.
enum PaymentMethod: String, CaseIterable, Hashable {
    case cash, whish, omt, bank, other
}

struct Invoice: Decodable, Hashable, Identifiable {
    let id: Int
    let number: String?
    let salonId: Int?
    let salonName: String?
    let plan: String?
    let periodFrom: String?
    let periodTo: String?
    let months: Int?
    let amount: Money?
    let status: InvoiceStatus?
    /// cash | whish | omt | bank | other, kept as text so a new method never breaks decoding.
    let method: String?
    let methodLabel: String?
    let paidAt: String?
    let note: String?
    let createdAt: String?

    var paymentMethod: PaymentMethod? { method.flatMap(PaymentMethod.init(rawValue:)) }
    var title: String { number ?? "#\(id)" }
}

/// GET /admin/invoices/{id}
struct InvoiceAnswer: Decodable, Hashable {
    let invoice: Invoice
    let generatedAt: String?
}
