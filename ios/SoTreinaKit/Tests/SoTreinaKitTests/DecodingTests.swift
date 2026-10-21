import Foundation
import Testing
@testable import SoTreinaKit

@Suite struct DecodingTests {
    @Test func decodesTokenResponse() throws {
        let url = try #require(Bundle.module.url(forResource: "auth-token", withExtension: "json", subdirectory: "Fixtures"))
        let response = try APICoding.makeDecoder().decode(TokenResponse.self, from: Data(contentsOf: url))

        #expect(response.token.hasPrefix("eyJ"))
        #expect(response.user.id == "cmfixture0000000000000000")
        #expect(response.user.firstName == "Teste")
        #expect(response.user.profileImgUrl == nil)
        #expect(response.user.maxHr == 190)
        #expect(response.user.hasStravaAccount)
    }

    @Test func parsesDatesWithAndWithoutMilliseconds() throws {
        let withMs = try #require(APICoding.parseDate("2026-10-18T21:42:57.123Z"))
        let withoutMs = try #require(APICoding.parseDate("2026-10-18T21:42:57Z"))

        #expect(abs(withMs.timeIntervalSince(withoutMs) - 0.123) < 0.001)
        #expect(APICoding.parseDate("18/10/2026") == nil)
    }

    @Test func dateRoundTripsThroughEncoderAndDecoder() throws {
        struct Box: Codable { var at: Date }
        let original = Box(at: Date(timeIntervalSince1970: 1_792_000_000.5))

        let data = try APICoding.makeEncoder().encode(original)
        let decoded = try APICoding.makeDecoder().decode(Box.self, from: data)

        #expect(abs(decoded.at.timeIntervalSince(original.at)) < 0.001)
    }
}
