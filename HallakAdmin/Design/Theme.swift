import SwiftUI

/// Colors from the brief (section 6). Each has a light and a dark version in Assets.xcassets.
enum Theme {
    static let navy = Color("Navy")
    /// Accents and the icon.
    static let brandRed = Color("BrandRed")
    /// Red for text and buttons (white text stays readable).
    static let actionRed = Color("ActionRed")
    /// Screen background (cream in light mode, deep navy in dark mode).
    static let background = Color("Cream")
    static let card = Color("CardBG")
    static let ink = Color("Ink")
    static let inkSecondary = Color("InkSecondary")

    static let green = Color("StatusGreen")
    static let orange = Color("StatusOrange")
    static let red = Color("StatusRed")
    static let grey = Color("StatusGrey")
    static let blue = Color("StatusBlue")

    static let cardRadius: CGFloat = 14
    static let minTouch: CGFloat = 44

    /// Color of a billing status (never the only signal: always shown with its label).
    static func color(for status: BillingStatus?) -> Color {
        switch status {
        case .active: return green
        case .trial: return blue
        case .grace: return orange
        case .overdue: return red
        case .free, .unknown, .none: return grey
        }
    }

    static func color(for status: InvoiceStatus?) -> Color {
        switch status {
        case .paid: return green
        case .unpaid: return orange
        case .void, .unknown, .none: return grey
        }
    }
}

extension Font {
    /// Numbers in cards: .title.bold() with monospaced digits.
    static let statNumber = Font.title.bold().monospacedDigit()
}

/// The red-and-cream diagonal stripe, used once as a thin accent on Home.
struct BarberStripe: View {
    var height: CGFloat = 6

    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color("Cream")))
            let step: CGFloat = 14
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                var p = Path()
                p.move(to: CGPoint(x: x, y: size.height))
                p.addLine(to: CGPoint(x: x + size.height, y: 0))
                p.addLine(to: CGPoint(x: x + size.height + step / 2, y: 0))
                p.addLine(to: CGPoint(x: x + step / 2, y: size.height))
                p.closeSubpath()
                ctx.fill(p, with: .color(Theme.brandRed))
                x += step
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}
