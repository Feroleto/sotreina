import Foundation
import Testing
@testable import SoTreinaKit

@Suite struct AccountDeletionTests {
    @Test func bodyCarriesThePasswordAsTyped() throws {
        let json = try String(decoding: JSONEncoder().encode(DeleteAccountRequest(password: " pw ")), as: UTF8.self)
        #expect(json == #"{"password":" pw "}"#)
    }

    @Test func needsAPassword() {
        #expect(!AccountDeletion.canSubmit(password: ""))
        #expect(AccountDeletion.canSubmit(password: "x"))
    }

    @Test func only403MeansWrongPassword() {
        #expect(AccountDeletion.failure(status: 403) == .wrongPassword)
        #expect(AccountDeletion.failure(status: 429) == .tooManyAttempts)
        #expect(AccountDeletion.failure(status: 500) == .other)
        #expect(AccountDeletion.failure(status: nil) == .other)
    }
}
