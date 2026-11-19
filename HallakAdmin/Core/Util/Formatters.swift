import Foundation

/// Times from the API are already Lebanon time as text ("2026-11-17 22:45", days "2026-11-17").
/// They are read and shown in Asia/Beirut: never converted from UTC.
enum Formatters {
    static let lebanon = TimeZone(identifier: "Asia/Beirut")!

    private static func parser(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = lebanon
        f.dateFormat = format
        return f
    }

    private static let dateTimeParser = parser("yyyy-MM-dd HH:mm")
    private static let dateTimeSecondsParser = parser("yyyy-MM-dd HH:mm:ss")
    private static let dayParser = parser("yyyy-MM-dd")

    /// "2026-11-17 22:45", "2026-11-17 22:45:10" or "2026-11-17" → Date.
    static func date(_ text: String?) -> Date? {
        guard let t = text?.trimmingCharacters(in: .whitespaces), !t.isEmpty else { return nil }
        return dateTimeParser.date(from: t) ?? dateTimeSecondsParser.date(from: t) ?? dayParser.date(from: t)
    }

    static func isDayOnly(_ text: String?) -> Bool { (text?.count ?? 0) == 10 }

    /// The app language, with Western digits in Arabic too (the same 0-9 as money and the API).
    static var appLocale: Locale {
        let lang = Bundle.main.preferredLocalizations.first ?? "en"
        return lang.hasPrefix("ar") ? Locale(identifier: "ar_LB@numbers=latn") : Locale.current
    }

    private static func display(_ date: Style, locale: Locale) -> DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = lebanon
        // Arabic short month names are "تشرين ٢"-style: use the full name there.
        let month = (locale.language.languageCode?.identifier == "ar") ? "MMMM" : "MMM"
        switch date {
        case .day: f.setLocalizedDateFormatFromTemplate("d \(month) yyyy")
        case .dayTime: f.setLocalizedDateFormatFromTemplate("d \(month) yyyy HH:mm")
        case .time: f.setLocalizedDateFormatFromTemplate("HH:mm")
        }
        return f
    }

    enum Style { case day, dayTime, time }

    /// "17 Nov 2026" / "17 Nov 2026, 22:45" in the app language. Falls back to the raw text.
    static func show(_ text: String?, _ style: Style? = nil, locale: Locale = Formatters.appLocale) -> String {
        guard let text, !text.isEmpty else { return "–" }
        guard let d = date(text) else { return text }
        let s = style ?? (isDayOnly(text) ? .day : .dayTime)
        return display(s, locale: locale).string(from: d)
    }

    /// "Updated 13:13": the time part of `generated_at`, as sent.
    static func updatedTime(_ generatedAt: String?) -> String? {
        guard let g = generatedAt, let space = g.lastIndex(of: " ") else { return nil }
        let time = g[g.index(after: space)...]
        return time.count >= 5 ? String(time.prefix(5)) : nil
    }

    /// "2 h ago", relative to `now` (both in Lebanon time).
    static func relative(_ text: String?, now: Date = Date(), locale: Locale = Formatters.appLocale) -> String? {
        guard let d = date(text) else { return nil }
        let f = RelativeDateTimeFormatter()
        f.locale = locale
        f.unitsStyle = .short
        return f.localizedString(for: d, relativeTo: now)
    }

    /// Days left on a subscription: "20 days left", "Today", "3 days late".
    static func daysLeft(_ days: Int?) -> String? {
        guard let days else { return nil }
        if days == 0 { return String(localized: "Today") }
        if days > 0 { return String(localized: "\(days) days left") }
        return String(localized: "\(-days) days late")
    }
}
