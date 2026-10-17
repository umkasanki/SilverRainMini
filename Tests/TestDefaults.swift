import Foundation
import Testing
@testable import SilverRainMini

/// Every suite that touches settings lives inside this one, and it runs them one
/// at a time, awaits included. That is what makes sharing one preferences file
/// safe: a suite never finds it wiped by another in the middle of a test.
@Suite(.serialized)
enum SettingsTests {}

/// One fixed preferences file for every test that needs settings, wiped each time
/// it is handed out. A fresh name per test left a new file in ~/Library/Preferences
/// on every run.
enum TestDefaults {
    private static let suite = "local.oleg.SilverRainMini.tests"

    @MainActor
    static func fresh() -> UserDefaults {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}

extension PlaylistResolver {
    /// The emergency path without the network: tests must never reach silver.ru.
    static var offline: PlaylistResolver {
        var resolver = PlaylistResolver()
        resolver.fetch = { _ in throw URLError(.notConnectedToInternet) }
        return resolver
    }
}
