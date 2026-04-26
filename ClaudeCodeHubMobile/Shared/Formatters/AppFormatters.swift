import Foundation

enum AppFormatters {
    static var serverTimeZone: TimeZone?
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoFormatterNoFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let relativeDate: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 4
        return formatter
    }()

    static let compactNumber: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    static func parseDate(_ value: String, timeZone: TimeZone? = nil) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let date = isoFormatter.date(from: trimmed) ?? isoFormatterNoFraction.date(from: trimmed) {
            return date
        }

        let zonedFallbackFormats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        ]
        for format in zonedFallbackFormats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) { return date }
        }

        let naiveFallbackFormats = ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"]
        for format in naiveFallbackFormats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = timeZone ?? serverTimeZone ?? TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) { return date }
        }
        return nil
    }

    static func number(_ value: Double?) -> String {
        guard let value else { return "—" }
        return compactNumber.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    static func integer(_ value: Int?) -> String {
        guard let value else { return "—" }
        return compactNumber.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func money(_ value: Double?) -> String {
        guard let value else { return "—" }
        return currency.string(from: NSNumber(value: value)) ?? number(value)
    }

    static func dateTime(_ date: Date?, timeZone: TimeZone? = nil) -> String {
        guard let date else { return "—" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = timeZone ?? serverTimeZone ?? .current
        return formatter.string(from: date)
    }

    static func relative(_ date: Date?) -> String {
        guard let date else { return "—" }
        return relativeDate.localizedString(for: date, relativeTo: Date())
    }

    static func resolvedTimeZone(_ identifier: String?) -> TimeZone? {
        guard let identifier, !identifier.isEmpty else { return nil }
        return TimeZone(identifier: identifier)
    }
}
