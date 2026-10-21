import Foundation

public enum APICoding {
    /// The NestJS backend serializes dates as ISO-8601 *with* milliseconds
    /// (`2026-10-18T21:42:57.123Z`), which `.iso8601` rejects. Accepts both
    /// forms so a field without fraction never breaks a whole response.
    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = parseDate(raw) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Not an ISO-8601 date: \(raw)"
            )
        }
        return decoder
    }

    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.formatted(withFraction))
        }
        return encoder
    }

    public static func parseDate(_ raw: String) -> Date? {
        (try? withFraction.parse(raw)) ?? (try? withoutFraction.parse(raw))
    }

    private static let withFraction = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let withoutFraction = Date.ISO8601FormatStyle()
}
