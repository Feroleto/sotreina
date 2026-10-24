import Foundation

/// Where the app's Strava connect lands (spec login-app-ios §5.2): the
/// callback redirects the ASWebAuthenticationSession to
/// `sotreina://strava/connected?status=ok|conflict|error`.
public enum StravaConnectReturn: Equatable, Sendable {
    case ok
    /// that Strava account is already linked to another SoTreina user
    case conflict
    case error

    public static let callbackScheme = "sotreina"

    public init(url: URL) {
        let parts = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let isConnected = parts?.scheme == Self.callbackScheme && parts?.host == "strava" && parts?.path == "/connected"
        let status = isConnected ? parts?.queryItems?.first { $0.name == "status" }?.value : nil
        switch status {
        case "ok": self = .ok
        case "conflict": self = .conflict
        default: self = .error
        }
    }
}

/// `GET /strava/sync/status` (the server's `SyncProgress`), what the first
/// sync screen polls. Only the fields the app shows.
public struct SyncStatus: Decodable, Equatable, Sendable {
    public enum State: String, Decodable, Sendable {
        case idle, running, done, error
    }

    public enum Phase: String, Decodable, Sendable {
        case listing, processing
        /// still running, sleeping until Strava's 15-min window resets
        case rateLimited = "rate_limited"
    }

    public var state: State
    public var phase: Phase?
    /// nil while the activity list is still being fetched
    public var total: Int?
    public var processed: Int
    public var etaSeconds: Int?
    /// start date of the activity being processed
    public var processingDate: Date?
    public var rateLimitResetAt: Date?

    public init(
        state: State, phase: Phase? = nil, total: Int? = nil, processed: Int = 0,
        etaSeconds: Int? = nil, processingDate: Date? = nil, rateLimitResetAt: Date? = nil
    ) {
        self.state = state
        self.phase = phase
        self.total = total
        self.processed = processed
        self.etaSeconds = etaSeconds
        self.processingDate = processingDate
        self.rateLimitResetAt = rateLimitResetAt
    }
}

/// What the first sync screen shows for a status, the web's `FirstSyncPage`
/// "syncing" card.
public struct FirstSyncProgress: Equatable, Sendable {
    public struct Count: Equatable, Sendable {
        public var processed: Int
        public var total: Int
    }

    public enum Detail: Equatable, Sendable {
        case rateLimited(secondsLeft: Int)
        case processingYear(Int)
    }

    /// nil while the activity list is still being fetched ("Buscando…")
    public var count: Count?
    /// 0...1; nil = indeterminate bar
    public var fraction: Double?
    public var detail: Detail?
    public var isFinished: Bool

    public init(status: SyncStatus, now: Date, calendar: Calendar = .current) {
        count = status.total.map { Count(processed: status.processed, total: $0) }
        // an account with no runs at all is simply complete
        fraction = status.total.map { $0 == 0 ? 1 : min(Double(status.processed) / Double($0), 1) }
        if status.phase == .rateLimited, let reset = status.rateLimitResetAt {
            detail = .rateLimited(secondsLeft: max(0, Int(reset.timeIntervalSince(now).rounded())))
        } else {
            detail = status.processingDate.map { .processingYear(calendar.component(.year, from: $0)) }
        }
        isFinished = status.state == .done || status.state == .error
    }

    public var isPaused: Bool {
        if case .rateLimited = detail { true } else { false }
    }

    /// "4:05", the web's `formatCountdown`
    public static func countdown(_ seconds: Int) -> String {
        "\(seconds / 60):" + String(format: "%02d", seconds % 60)
    }
}

/// `POST /strava/connect/start`: Strava's authorize URL, its state bound to
/// this user for 10 minutes.
public struct StravaConnectStart: Decodable, Sendable {
    public var url: URL
}

/// `DELETE /strava/connect`. `accountDeleted` only for an account without a
/// password, which can't be signed in to here anyway; treated as a logout.
public struct StravaDisconnectResponse: Decodable, Sendable {
    public var accountDeleted: Bool
}
