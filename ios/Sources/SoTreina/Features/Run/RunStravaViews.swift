import SoTreinaDesign
import SoTreinaKit
import SwiftUI

/// Corrida without a Strava connection (spec login-app-ios §5.1): what gets
/// imported and the official "Connect with Strava" button, which runs the
/// app's OAuth flow (§5.2). Cancelling the sheet says nothing.
struct RunConnectView: View {
    @Environment(SessionStore.self) private var session
    @State private var busy = false
    @State private var failure: StravaConnectReturn?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Image(systemName: "figure.run")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(Color.fg)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(Color.chip))

                Text("run.connect.title", bundle: .l10n)
                    .font(DSFont.rowTitle)
                    .foregroundStyle(Color.fg)
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)

                Text("run.connect.body", bundle: .l10n)
                    .font(DSFont.meta)
                    .foregroundStyle(Color.mutedFg)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)

                ConnectWithStrava(busy: busy) { connect() }
                    .padding(.top, 28)

                if let failure {
                    Text(failure == .conflict ? "run.connect.conflict" : "run.connect.error", bundle: .l10n)
                        .font(DSFont.meta)
                        .foregroundStyle(Color.neg)
                        .multilineTextAlignment(.center)
                        .padding(.top, 14)
                }
            }
            .frame(maxWidth: 360)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, pageGutter)
            .padding(.top, 56)
            .padding(.bottom, 44)
        }
        .background(Color.pageBg)
    }

    private func connect() {
        busy = true
        failure = nil
        Task {
            defer { busy = false }
            do {
                // `ok` refreshes /auth/me, and Corrida takes over from there
                if let result = try await session.connectStrava(), result != .ok { failure = result }
            } catch APIError.unauthorized {
                // the session store already went back to Entrar
            } catch {
                failure = .error
            }
        }
    }
}

/// The first import after connecting (spec §5.3), the web's `FirstSyncPage`
/// "syncing" card: N of M with a bar, the year being processed or the
/// countdown of a rate-limit pause, and the time left. Polls while on
/// screen; leaving doesn't cancel anything (the sync runs on the server).
struct RunFirstSyncView: View {
    let store: RunStore
    @Environment(\.tabActivation) private var activation

    private struct PollKey: Equatable {
        var notStarted: Bool
        var active: Bool
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                switch store.firstSync {
                case .running(let status):
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        running(FirstSyncProgress(status: status, now: context.date), eta: status.etaSeconds)
                    }
                case .notStarted:
                    notStarted
                case nil:
                    EmptyView()
                }

                Hairline()
                    .padding(.top, 28)
                Text("run.firstSync.readOnly", bundle: .l10n)
                    .font(DSFont.caption)
                    .foregroundStyle(Color.mutedFg)
                    .padding(.top, 14)
            }
            .padding(.horizontal, pageGutter)
            .padding(.top, 28)
            .padding(.bottom, 44)
        }
        .background(Color.pageBg)
        // only with the tab on screen: hidden tabs stay mounted
        .task(id: PollKey(notStarted: store.firstSync == .notStarted, active: activation.isActive)) {
            guard activation.isActive else { return }
            await store.pollFirstSync()
        }
    }

    private func running(_ progress: FirstSyncProgress, eta: Int?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("run.firstSync.title", bundle: .l10n)
                .font(DSFont.sectionTitle)
                .foregroundStyle(Color.fg)

            if let count = progress.count {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(count.processed, format: .number)
                        .font(DSFont.bigNumber)
                        .foregroundStyle(Color.fg)
                        .contentTransition(.numericText())
                    Text("run.firstSync.ofTotal \(count.total)", bundle: .l10n)
                        .font(DSFont.bigNumberUnit)
                        .foregroundStyle(Color.mutedFg)
                }
                .padding(.top, 18)
            } else {
                Text("run.firstSync.finding", bundle: .l10n)
                    .font(DSFont.body)
                    .foregroundStyle(Color.mutedFg)
                    .frame(minHeight: 64, alignment: .leading)
                    .padding(.top, 18)
            }

            Group {
                if let fraction = progress.fraction {
                    ProgressLine(fraction, height: 6)
                } else {
                    ProgressView().progressViewStyle(.linear).tint(Color.acc)
                }
            }
            .frame(height: 6)
            .padding(.top, 18)

            Group {
                switch progress.detail {
                case .rateLimited(let secondsLeft):
                    Text("run.firstSync.rateLimited \(FirstSyncProgress.countdown(secondsLeft))", bundle: .l10n)
                        .monospacedDigit()
                case .processingYear(let year):
                    Text("run.firstSync.processingYear \(String(year))", bundle: .l10n)
                case nil:
                    Text(verbatim: " ")
                }
            }
            .font(DSFont.meta)
            .foregroundStyle(Color.mutedFg)
            .padding(.top, 12)

            // during a pause the server's ETA is the pause itself, already counting down above
            if let eta, eta > 0, progress.count != nil, !progress.isPaused {
                Text("run.firstSync.eta \(max(1, Int((Double(eta) / 60).rounded())))", bundle: .l10n)
                    .font(DSFont.meta)
                    .foregroundStyle(Color.mutedFg)
                    .padding(.top, 4)
            }

            Text("run.firstSync.leaveHint", bundle: .l10n)
                .font(DSFont.caption)
                .foregroundStyle(Color.mutedFg)
                .padding(.top, 22)
        }
    }

    private var notStarted: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("run.firstSync.title", bundle: .l10n)
                .font(DSFont.sectionTitle)
                .foregroundStyle(Color.fg)
            Text("run.firstSync.notStarted", bundle: .l10n)
                .font(DSFont.body)
                .foregroundStyle(Color.mutedFg)
            Button { Task { await store.startFirstSync() } } label: {
                Text("common.retry", bundle: .l10n)
            }
            .buttonStyle(.pill)
        }
    }
}
