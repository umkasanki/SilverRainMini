import Foundation
import Testing
@testable import SilverRainMini

extension SettingsTests {
    /// SPEC FR-5: sleep and wake, and the network reaching the player.
    @MainActor
    struct AppStateTests {
        private final class FakeNetwork: NetworkMonitoring {
            var isAvailable = true
            var onChange: ((Bool) -> Void)?

            func change(to isAvailable: Bool) {
                self.isAvailable = isAvailable
                onChange?(isAvailable)
            }
        }

        private final class FakeSleep: SleepWatching {
            var onSleep: (() -> Void)?
            var onWake: (() -> Void)?
        }

        private let engine = FakePlaybackEngine()
        private let network = FakeNetwork()
        private let sleep = FakeSleep()
        private let clock = ManualClock()

        private func makeAppState() -> AppState {
            AppState(
                player: RadioPlayer(engine: engine, sleep: clock.sleep),
                networkMonitor: network,
                sleepWatcher: sleep,
                defaults: TestDefaults.fresh(),
                playlistResolver: .offline
            )
        }

        @Test func playingBeforeSleepPlaysAgainAfterWake() {
            let appState = makeAppState()
            appState.togglePlayback()
            engine.send(.started)
            sleep.onSleep?()
            #expect(appState.player.state == .idle)
            sleep.onWake?()
            #expect(appState.player.state == .connecting)
            #expect(engine.startedURLs.count == 2)
        }

        @Test func reconnectingBeforeSleepAlsoResumes() {
            let appState = makeAppState()
            appState.togglePlayback()
            engine.send(.failed(.unreachable))
            sleep.onSleep?()
            sleep.onWake?()
            #expect(appState.player.state == .connecting)
        }

        @Test func stoppedBeforeSleepStaysStopped() {
            let appState = makeAppState()
            appState.togglePlayback()
            appState.togglePlayback()
            sleep.onSleep?()
            sleep.onWake?()
            #expect(appState.player.state == .idle)
            #expect(engine.startedURLs.count == 1)
        }

        @Test func wakeResumesOnlyOnce() {
            let appState = makeAppState()
            appState.togglePlayback()
            sleep.onSleep?()
            sleep.onWake?()
            appState.togglePlayback()
            sleep.onWake?()
            #expect(appState.player.state == .idle)
        }

        @Test func networkStateReachesThePlayer() {
            network.isAvailable = false
            let appState = makeAppState()
            #expect(!appState.player.isNetworkAvailable)
            network.change(to: true)
            #expect(appState.player.isNetworkAvailable)
        }
    }
}
