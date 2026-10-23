import Foundation
import os
import SoTreinaDesign
import SoTreinaKit
import SwiftUI
import UserNotifications

/// Spec §6.5: warn before the 7-day free signature runs out. Everything
/// fails silent — no profile, no warning (e.g. a build that never got one).
enum ExpiryNotice {
    private static let log = Logger(subsystem: "com.feroleto.sotreina", category: "expiry")
    private static let notificationId = "app-expiry"

    /// Read once per launch: the profile only changes with a reinstall.
    static let expiration: Date? = {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url)
        else {
            log.notice("no embedded.mobileprovision")
            return nil
        }
        let date = AppExpiry.expirationDate(fromProvisioningProfile: data)
        log.notice("signature expires \(date?.ISO8601Format() ?? "unparsed", privacy: .public)")
        return date
    }()

    /// Every launch replaces the reminder, so a reinstall (new profile, new
    /// date) moves it. Needs the notification permission asked by the first
    /// workout; without it the request is simply dropped.
    static func scheduleReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationId])
        guard let expiration, let reminder = AppExpiry.reminderDate(expiration: expiration) else { return }

        let content = UNMutableNotificationContent()
        // in the language at scheduling time; every launch reschedules it
        let lang = AppLanguageStore.current
        content.title = L10n.string("app.expiry.notificationTitle", lang: lang)
        content.body = L10n.string("app.expiry.notificationBody", lang: lang)
        content.sound = .default
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        center.add(UNNotificationRequest(identifier: notificationId, content: content, trigger: trigger)) { error in
            if let error { log.error("schedule failed: \(String(describing: error), privacy: .public)") }
        }
    }
}

/// The fixed banner at the top of every screen, from 2 days before expiry.
struct ExpiryBanner: View {
    @Environment(AppLanguageStore.self) private var language

    var body: some View {
        if let expiration = ExpiryNotice.expiration {
            TimelineView(.everyMinute) { context in
                if let text = AppExpiry.banner(expiration: expiration, now: context.date, lang: language.lang) {
                    Label(text, systemImage: "exclamationmark.triangle.fill")
                        .font(Font.geist(13, relativeTo: .footnote).weight(.medium))
                        .foregroundStyle(Color.accFg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .padding(.horizontal)
                        .background(Color.acc)
                }
            }
        }
    }
}
