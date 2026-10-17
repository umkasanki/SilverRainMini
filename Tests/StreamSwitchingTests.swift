import Foundation
import Testing
@testable import SilverRainMini

extension SettingsTests {
    /// SPEC FR-9: the stream follows the settings, on the fly while playing.
    @MainActor
    struct StreamSwitchingTests {
        private final class StillNetwork: NetworkMonitoring {
            var isAvailable = true
            var onChange: ((Bool) -> Void)?
        }

        private final class NoSleep: SleepWatching {
            var onSleep: (() -> Void)?
            var onWake: (() -> Void)?
        }

        private let engine = FakePlaybackEngine()
        private let defaults = TestDefaults.fresh()

        private func makeAppState() -> AppState {
            AppState(
                player: RadioPlayer(engine: engine),
                networkMonitor: StillNetwork(),
                sleepWatcher: NoSleep(),
                defaults: defaults
            )
        }

        private let aac96 = URL(string: "https://silverrain.hostingradio.ru/silver64.aac")!
        private let mp3 = URL(string: "https://silverrain.hostingradio.ru/silver128.mp3")!

        @Test func playsTheDefaultStreamFirst() {
            let appState = makeAppState()
            appState.togglePlayback()
            #expect(engine.startedURLs == [aac96])
            #expect(appState.stream.shortTitle == "AAC 96")
        }

        @Test func switchingWhilePlayingStartsTheNewStream() {
            let appState = makeAppState()
            appState.togglePlayback()
            engine.send(.started)
            appState.selectStream(id: "mp3128")
            #expect(engine.startedURLs == [aac96, mp3])
            #expect(appState.player.state == .connecting)
            #expect(appState.stream.shortTitle == "MP3 128")
        }

        @Test func switchingWhileStoppedIsOnlyRemembered() {
            let appState = makeAppState()
            appState.selectStream(id: "mp3128")
            #expect(engine.startedURLs.isEmpty)
            #expect(appState.player.state == .idle)
            appState.togglePlayback()
            #expect(engine.startedURLs == [mp3])
        }

        @Test func anotherSettingChangingDoesNotRestart() {
            let appState = makeAppState()
            appState.togglePlayback()
            engine.send(.started)
            appState.setVolume(0.3)
            defaults.set(true, forKey: SettingsKey.showQuality)
            #expect(engine.startedURLs.count == 1)
            #expect(appState.player.state == .playing)
        }

        @Test func aBrokenOwnAddressIsAnErrorAtOnce() {
            defaults.set(StreamCatalog.customID, forKey: SettingsKey.streamID)
            defaults.set("http://example.com/live", forKey: SettingsKey.customURL)
            let appState = makeAppState()
            appState.togglePlayback()
            #expect(engine.startedURLs.isEmpty)
            #expect(appState.player.state == .error(.invalidAddress))
        }

        @Test func theOwnAddressHasNoEmergencyPath() async {
            defaults.set(StreamCatalog.customID, forKey: SettingsKey.streamID)
            defaults.set("https://example.com/live", forKey: SettingsKey.customURL)
            let appState = makeAppState()
            appState.togglePlayback()
            engine.send(.failed(.notFound))
            await settle()
            #expect(engine.startedURLs == [URL(string: "https://example.com/live")!])
            #expect(appState.player.state == .error(.notFound))
        }

        @Test func aStreamGoneFromTheCatalogBecomesTheDefault() {
            defaults.set("gone-since-1.0", forKey: SettingsKey.streamID)
            let appState = makeAppState()
            #expect(defaults.string(forKey: SettingsKey.streamID) == "aac96")
            #expect(appState.selectedStreamID == "aac96")
            #expect(appState.stream.shortTitle == "AAC 96")
        }

        @Test func theOwnAddressIsNotForgotten() {
            defaults.set(StreamCatalog.customID, forKey: SettingsKey.streamID)
            _ = makeAppState()
            #expect(defaults.string(forKey: SettingsKey.streamID) == StreamCatalog.customID)
        }

        @Test func radioPlaysOnLaunchUnlessTurnedOff() {
            #expect(makeAppState().playsOnLaunch)
            defaults.set(false, forKey: SettingsKey.playOnLaunch)
            #expect(!makeAppState().playsOnLaunch)
            // As it arrives from `--args -playOnLaunch NO`.
            defaults.set("NO", forKey: SettingsKey.playOnLaunch)
            #expect(!makeAppState().playsOnLaunch)
        }
    }
}
