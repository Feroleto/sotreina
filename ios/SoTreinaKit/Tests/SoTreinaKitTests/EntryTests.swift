import Foundation
import Testing
@testable import SoTreinaKit

@Suite struct EntryTests {
    @Test func registerNeedsAnEmailAndAPasswordOfEight() {
        #expect(EntryForm.registerProblem(email: " ", password: "12345678") == .emailMissing)
        #expect(EntryForm.registerProblem(email: "a@b.co", password: "1234567") == .passwordTooShort)
        #expect(EntryForm.registerProblem(email: "a@b.co", password: "12345678") == nil)
    }

    @Test func registerBodyTrimsAndDropsAnEmptyName() throws {
        let blank = RegisterRequest(email: " A@b.co ", password: "pw", firstName: "  ")
        #expect(blank.email == "A@b.co")
        #expect(blank.firstName == nil)
        let json = try String(decoding: JSONEncoder().encode(blank), as: UTF8.self)
        #expect(!json.contains("firstName"))
        #expect(RegisterRequest(email: "a@b.co", password: "pw", firstName: " Ana ").firstName == "Ana")
    }

    @Test func areasGoInTheServersOrder() {
        #expect(EntryForm.canonicalAreas([.diet, .run]) == [.run, .diet])
        #expect(EntryForm.canonicalAreas([]) == [])
    }

    @Test func theAreasPatchEncodesRawValues() throws {
        let json = try String(decoding: JSONEncoder().encode(EnabledAreasPatch(enabledAreas: [.gym])), as: UTF8.self)
        #expect(json == #"{"enabledAreas":["GYM"]}"#)
    }
}
