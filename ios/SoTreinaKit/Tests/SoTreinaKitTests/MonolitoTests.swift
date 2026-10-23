import Foundation
import Testing
@testable import SoTreinaKit

@Suite struct MonolitoTests {
    /// `--name: #rrggbb;` pairs of one CSS block (`:root {` or `.dark {`).
    private static func cssTokens(block: String) throws -> [String: UInt32] {
        let css = URL(filePath: #filePath)
            .deletingLastPathComponent()  // SoTreinaKitTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // SoTreinaKit
            .deletingLastPathComponent()  // ios
            .deletingLastPathComponent()  // repo
            .appending(path: "client/src/index.css")
        let text = try String(contentsOf: css, encoding: .utf8)
        let start = try #require(text.range(of: "\n\(block) {"))
        let end = try #require(text.range(of: "\n}", range: start.upperBound..<text.endIndex))
        var tokens: [String: UInt32] = [:]
        for line in text[start.upperBound..<end.lowerBound].split(separator: "\n") {
            let parts = line.trimmingCharacters(in: .whitespaces).split(separator: ":", maxSplits: 1)
            guard parts.count == 2, parts[0].hasPrefix("--") else { continue }
            let value = parts[1].trimmingCharacters(in: .whitespaces.union(.init(charactersIn: ";")))
            guard value.hasPrefix("#"), value.count == 7, let hex = UInt32(value.dropFirst(), radix: 16) else { continue }
            tokens[String(parts[0].dropFirst(2))] = hex
        }
        return tokens
    }

    /// Every hex token the app mirrors must equal the web's, in both themes,
    /// so a palette change on the web fails here instead of drifting.
    @Test func paletteMatchesWebCSS() throws {
        let light = try Self.cssTokens(block: ":root")
        let dark = try Self.cssTokens(block: ".dark")
        for token in Monolito.Token.allCases {
            let pair = Monolito.color(token)
            guard let name = token.cssName else { continue }
            // `--acc`/`--acc-fg` live only in :root and are inherited by .dark
            let expectedLight = try #require(light[name], "missing --\(name) in :root")
            let expectedDark = dark[name] ?? expectedLight
            #expect(pair.light == expectedLight, "--\(name) light")
            #expect(pair.dark == expectedDark, "--\(name) dark")
        }
    }

    @Test func derivedTokensFollowTheWebsMixes() {
        // light --acc-tx = color-mix(in oklab, --acc 58%, black); dark = --acc
        #expect(Monolito.color(.accTx).light == 0x674C1A)
        #expect(Monolito.color(.accTx).dark == Monolito.color(.acc).dark)
    }

    @Test func textOnMustardIsAlwaysDark() {
        let fg = Monolito.color(.accFg)
        #expect(fg.light == 0x141414 && fg.dark == 0x141414)
    }

    @Test(arguments: [
        ("auto", ThemePreference.auto),
        ("light", .light),
        ("dark", .dark),
        ("", .auto),
        ("sepia", .auto),
    ])
    func themePreferenceReadsTheWebsValues(raw: String, expected: ThemePreference) {
        #expect(ThemePreference(stored: raw) == expected)
    }

    @Test func rgbComponents() {
        let c = Monolito.rgb(0xD9A441)
        #expect(c.red == 0xD9 / 255.0 && c.green == 0xA4 / 255.0 && c.blue == 0x41 / 255.0)
    }
}
