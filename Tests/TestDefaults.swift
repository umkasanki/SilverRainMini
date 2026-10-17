import Foundation

/// One fixed preferences file for every test that needs settings, wiped each time
/// it is handed out. A fresh name per test left a new file in ~/Library/Preferences
/// on every run. Tests that use it run on the main actor one at a time.
enum TestDefaults {
    private static let suite = "local.oleg.SilverRainMini.tests"

    @MainActor
    static func fresh() -> UserDefaults {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
