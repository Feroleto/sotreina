import Foundation
import Testing
@testable import SoTreinaKit

@Suite struct AppExpiryTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return calendar
    }

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        // October 2026: the 22nd is a Thursday
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    /// Synthetic envelope in the real file's layout (no real profile exists
    /// off-device: xtool signs at install time) — binary CMS bytes around
    /// an XML plist.
    private func profile(expiration: String) -> Data {
        var data = Data([0x30, 0x82, 0x0F, 0x3A, 0x06, 0x09, 0x2A, 0x86, 0x48])
        data.append(Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>AppIDName</key><string>XC com feroleto sotreina</string>
            <key>CreationDate</key><date>2026-10-22T19:00:00Z</date>
            <key>ExpirationDate</key><date>\(expiration)</date>
            <key>TeamIdentifier</key><array><string>KBVDP58W3Z</string></array>
        </dict>
        </plist>
        """.utf8))
        data.append(Data([0xA0, 0x82, 0x03, 0x00, 0xFF]))
        return data
    }

    @Test func readsExpirationFromTheEnvelope() throws {
        let expiration = try #require(AppExpiry.expirationDate(fromProvisioningProfile: profile(expiration: "2026-10-29T19:00:00Z")))
        #expect(expiration == APICoding.parseDate("2026-10-29T19:00:00Z"))
    }

    @Test func garbageGivesNoDate() {
        #expect(AppExpiry.expirationDate(fromProvisioningProfile: Data()) == nil)
        #expect(AppExpiry.expirationDate(fromProvisioningProfile: Data("<?xml no end".utf8)) == nil)
        #expect(AppExpiry.expirationDate(fromProvisioningProfile: profile(expiration: "not a date")) == nil)
    }

    @Test func noBannerBeforeTheTwoDayWindow() {
        #expect(AppExpiry.banner(expiration: date(29, 16), now: date(22, 10), calendar: calendar) == nil)
        #expect(AppExpiry.banner(expiration: date(29, 16), now: date(27, 15), calendar: calendar) == nil)
    }

    @Test func bannerNamesTheDay() {
        // Thu 29th, seen from Tue 27th 17:00 — inside the 48h window
        #expect(AppExpiry.banner(expiration: date(29, 16), now: date(27, 17), calendar: calendar)
            == "O app expira quinta. Rode ios/scripts/deploy.sh.")
        #expect(AppExpiry.banner(expiration: date(29, 16, 5), now: date(28, 9), calendar: calendar)
            == "O app expira amanhã às 16:05. Rode ios/scripts/deploy.sh.")
        #expect(AppExpiry.banner(expiration: date(29, 16), now: date(29, 8), calendar: calendar)
            == "O app expira hoje às 16:00. Rode ios/scripts/deploy.sh.")
        #expect(AppExpiry.banner(expiration: date(29, 16), now: date(29, 17), calendar: calendar)
            == "O app expirou. Rode ios/scripts/deploy.sh.")
    }

    @Test func reminderIsTheEveAt20h() {
        #expect(AppExpiry.reminderDate(expiration: date(29, 16), now: date(22, 10), calendar: calendar) == date(28, 20))
        // the eve's 20:00 already passed: nothing to schedule
        #expect(AppExpiry.reminderDate(expiration: date(29, 16), now: date(28, 21), calendar: calendar) == nil)
    }
}
