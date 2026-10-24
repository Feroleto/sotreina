import Foundation
import Testing
@testable import SoTreinaKit

@Suite struct EmailVerificationTests {
    @Test func meReadsEmailVerified() throws {
        let json = #"{"id":"u1","email":"a@b.co","hasStravaAccount":false,"hasPassword":true,"emailVerified":false}"#
        let me = try APICoding.makeDecoder().decode(Me.self, from: Data(json.utf8))
        #expect(me.emailVerified == false)
    }

    @Test func aBackendWithoutTheFieldCountsAsVerified() throws {
        // auth-token.json predates email verification: nothing to nag about
        // (and send-code doesn't exist there)
        let url = try #require(Bundle.module.url(forResource: "auth-token", withExtension: "json", subdirectory: "Fixtures"))
        let response = try APICoding.makeDecoder().decode(TokenResponse.self, from: Data(contentsOf: url))
        #expect(response.user.emailVerified)
    }

    @Test func theCodeKeepsOnlySixDigits() {
        #expect(EmailCode.sanitize("12a 34-5") == "12345")
        #expect(EmailCode.sanitize("1234567") == "123456")
        #expect(EmailCode.sanitize("") == "")
        #expect(!EmailCode.isComplete("12345"))
        #expect(EmailCode.isComplete("123456"))
    }

    @Test func the429BodyGivesTheCountdown() {
        let body = Data(#"{"statusCode":429,"message":"Too many","retryAfterSeconds":42}"#.utf8)
        #expect(EmailCode.retryAfterSeconds(from: body) == 42)
        // no usable body: the server's cooldown
        #expect(EmailCode.retryAfterSeconds(from: Data("oops".utf8)) == EmailCode.resendCooldown)
        #expect(EmailCode.retryAfterSeconds(from: Data()) == EmailCode.resendCooldown)
    }

    @Test func only400IsAWrongCode() {
        #expect(EmailCode.verifyFailure(status: 400) == .invalidCode)
        #expect(EmailCode.verifyFailure(status: 429) == .other)
        #expect(EmailCode.verifyFailure(status: nil) == .other)
    }

    @Test func verifyBodyIsTheCode() throws {
        let json = try String(decoding: JSONEncoder().encode(VerifyEmailRequest(code: "123456")), as: UTF8.self)
        #expect(json == #"{"code":"123456"}"#)
    }
}
