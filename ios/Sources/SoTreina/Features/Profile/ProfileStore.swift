import Foundation
import Observation
import os
import SoTreinaKit

/// Perfil's state: the `/users/me` snapshot (goals and preferences) and its
/// saves. The fields `/auth/me` shares (name, areas, units) go back into the
/// session's `Me`, so the tabs and the rest of the app follow at once.
@MainActor
@Observable
final class ProfileStore {
    /// What failed last, shown under its own section (the web's
    /// `areasError`/`unitsError`); the drill-down pages show their own.
    enum SaveError: Equatable {
        case areas
        case units
    }

    private(set) var settings: MeSettings?
    private(set) var loadFailed = false
    var saveError: SaveError?

    private let session: SessionStore
    private let log = Logger(subsystem: "com.feroleto.sotreina", category: "profile")

    init(session: SessionStore) {
        self.session = session
    }

    func load() async {
        guard let cached = session.cachedAPI else { return }
        if settings == nil, let hit: ResponseCache.Hit<MeSettings> = cached.cached("users/me") {
            settings = hit.value
        }
        do {
            settings = try await cached.get("users/me")
            loadFailed = false
        } catch APIError.unauthorized {
            session.expire()
        } catch {
            log.error("load failed: \(String(describing: error), privacy: .public)")
            loadFailed = settings == nil
        }
    }

    /// The area switches: flips at once (tabs included), back on failure.
    func toggle(_ area: Area) async {
        guard let me, let next = ProfileRules.toggling(area, in: me.enabledAreas) else { return }
        await saveOptimistically(MeSettingsPatch(enabledAreas: next), failure: .areas)
    }

    func setDistanceUnit(_ unit: DistanceUnit) async {
        guard me?.distanceUnit != unit else { return }
        await saveOptimistically(MeSettingsPatch(distanceUnit: unit), failure: .units)
    }

    func setWeightUnit(_ unit: WeightUnit) async {
        guard me?.weightUnit != unit else { return }
        await saveOptimistically(MeSettingsPatch(weightUnit: unit), failure: .units)
    }

    /// The drill-down pages (name, goals): waits for the server and throws,
    /// so the page stays open with its error.
    func save(_ patch: MeSettingsPatch) async throws {
        let saved = try await send(patch)
        apply(saved)
    }

    // MARK: -

    private var me: Me? {
        if case .loggedIn(let me) = session.state { return me }
        return nil
    }

    private func saveOptimistically(_ patch: MeSettingsPatch, failure: SaveError) async {
        guard let me else { return }
        let previousSettings = settings
        saveError = nil
        session.setMe(me.applying(patch.applied(to: settings ?? MeSettings(snapshotOf: me))))
        if let settings { self.settings = patch.applied(to: settings) }
        do {
            apply(try await send(patch))
        } catch {
            session.setMe(me)
            settings = previousSettings
            saveError = failure
        }
    }

    private func send(_ patch: MeSettingsPatch) async throws -> MeSettings {
        do {
            guard let saved: MeSettings = try await session.api.patch("users/me", body: patch) else {
                throw APIError.invalidResponse
            }
            return saved
        } catch APIError.unauthorized {
            session.expire()
            throw APIError.unauthorized
        } catch {
            log.error("save failed: \(String(describing: error), privacy: .public)")
            throw error
        }
    }

    private func apply(_ saved: MeSettings) {
        settings = saved
        session.cachedAPI?.store(saved, as: "users/me")
        if let me { session.setMe(me.applying(saved)) }
    }
}

private extension MeSettings {
    /// Before `/users/me` loads: the `Me` fields, goals at their defaults
    /// (only used to carry an optimistic patch into `Me`).
    init(snapshotOf me: Me) {
        self.init(
            firstName: me.firstName,
            enabledAreas: me.enabledAreas,
            distanceUnit: me.distanceUnit,
            weightUnit: me.weightUnit
        )
    }
}
