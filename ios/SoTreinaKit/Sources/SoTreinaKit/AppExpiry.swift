import Foundation

/// The free Apple ID signature lasts 7 days; after that the app won't open
/// until `ios/scripts/deploy.sh` reinstalls it (spec §6.5). The date comes
/// from the bundle's own `embedded.mobileprovision`.
public enum AppExpiry {
    /// `embedded.mobileprovision` is an XML plist wrapped in a CMS envelope:
    /// the plist is the bytes from `<?xml` through `</plist>`. nil on anything
    /// unexpected — the app then simply shows no warning.
    public static func expirationDate(fromProvisioningProfile data: Data) -> Date? {
        guard let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex)
        else { return nil }
        let plist = data[start.lowerBound..<end.upperBound]
        guard let dict = try? PropertyListSerialization.propertyList(from: plist, format: nil) as? [String: Any]
        else { return nil }
        return dict["ExpirationDate"] as? Date
    }

    public static let warningWindow: TimeInterval = 2 * 86_400

    /// Banner text from 2 days before expiry, nil before that.
    public static func banner(
        expiration: Date, now: Date = .now, calendar: Calendar = .current, lang: Lang = .pt
    ) -> String? {
        let pt = lang == .pt
        let remaining = expiration.timeIntervalSince(now)
        guard remaining <= warningWindow else { return nil }
        let when: String
        if remaining <= 0 {
            return pt ? "O app expirou. Rode ios/scripts/deploy.sh." : "The app has expired. Run ios/scripts/deploy.sh."
        } else if calendar.isDate(expiration, inSameDayAs: now) {
            when = pt ? "hoje às \(time(expiration, calendar))" : "today at \(time(expiration, calendar))"
        } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
                  calendar.isDate(expiration, inSameDayAs: tomorrow) {
            when = pt ? "amanhã às \(time(expiration, calendar))" : "tomorrow at \(time(expiration, calendar))"
        } else {
            let index = calendar.component(.weekday, from: expiration) - 1
            when = pt ? weekdaysPT[index] : "on \(weekdaysEN[index])"
        }
        return pt ? "O app expira \(when). Rode ios/scripts/deploy.sh." : "The app expires \(when). Run ios/scripts/deploy.sh."
    }

    /// The eve of the expiry at 20:00 (spec §6.5); nil if that's already past.
    public static func reminderDate(expiration: Date, now: Date = .now, calendar: Calendar = .current) -> Date? {
        guard let eve = calendar.date(byAdding: .day, value: -1, to: expiration),
              let reminder = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: eve),
              reminder > now
        else { return nil }
        return reminder
    }

    private static let weekdaysPT = ["domingo", "segunda", "terça", "quarta", "quinta", "sexta", "sábado"]
    private static let weekdaysEN = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    private static func time(_ date: Date, _ calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let minute = parts.minute ?? 0
        return "\(parts.hour ?? 0):\(minute < 10 ? "0" : "")\(minute)"
    }
}
