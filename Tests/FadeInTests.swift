import Foundation
import Testing
@testable import SilverRainMini

extension SettingsTests {
    /// SPEC FR-8, FR-10: the sound rises from silence when the radio starts by itself.
    @MainActor
    struct FadeInTests {
        private final class StillNetwork: NetworkMonitoring {
            var isAvailable = true
            var onChange: ((Bool) -> Void)?
        }

        private final class FakeSleep: SleepWatching {
            var onSleep: (() -> Void)?
            var onWake: (() -> Void)?
        }

        private let engine = FakePlaybackEngine()
        private let defaults = TestDefaults.fresh()
        private let clock = ManualClock()
        private let sleepWatcher = FakeSleep()
        private var step: Duration { AppState.fadeInDuration / AppState.fadeInSteps }

        private func makeAppState(fades: Bool = true, volume: Double = 0.8) -> AppState {
            defaults.set(fades, forKey: SettingsKey.fadeInOnLaunch)
            defaults.set(volume, forKey: SettingsKey.volume)
            return AppState(
                player: RadioPlayer(engine: engine, sleep: clock.sleep),
                networkMonitor: StillNetwork(),
                sleepWatcher: sleepWatcher,
                defaults: defaults,
                sleep: clock.sleep
            )
        }

        /// Lets the fade take `count` steps.
        private func advance(_ count: Int) async {
            for _ in 0..<count {
                await settle { clock.pending.contains(step) }
                clock.fire(step)
            }
            await settle()
        }

        @Test func offByDefault() {
            let appState = makeAppState()
            defaults.removeObject(forKey: SettingsKey.fadeInOnLaunch)
            #expect(!appState.fadesInOnLaunch)
        }

        @Test func withoutTheSettingTheSoundComesAtOnce() {
            let appState = makeAppState(fades: false)
            appState.playOnLaunch()
            engine.send(.started)
            #expect(engine.volume == 0.8)
        }

        @Test func silentUntilSoundThenRisesToTheSavedLevel() async {
            let appState = makeAppState()
            appState.playOnLaunch()
            #expect(engine.volume == 0)
            // Time passes while connecting: nothing may rise yet.
            await settle()
            clock.fire(step)
            await settle()
            #expect(engine.volume == 0, "the fade waits for sound, not for the click")
            engine.send(.started)
            await advance(AppState.fadeInSteps / 2)
            #expect(engine.volume > 0 && engine.volume < 0.8 / 2, "a curve: below half way at half time")
            await advance(AppState.fadeInSteps / 2)
            #expect(abs(engine.volume - 0.8) < 0.0001)
            #expect(appState.volume == 0.8)
        }

        @Test func aPressIsNeverFaded() {
            let appState = makeAppState()
            appState.togglePlayback()
            engine.send(.started)
            #expect(engine.volume == 0.8)
        }

        @Test func touchingTheVolumeEndsTheFade() async {
            let appState = makeAppState()
            appState.playOnLaunch()
            engine.send(.started)
            await advance(5)
            appState.setVolume(0.3)
            await advance(5)
            #expect(engine.volume == 0.3)
        }

        @Test func stoppingDuringTheFadeLeavesTheRealVolumeForNextTime() async {
            let appState = makeAppState()
            appState.playOnLaunch()
            engine.send(.started)
            await advance(5)
            appState.togglePlayback()
            #expect(engine.volume == 0.8)
            appState.togglePlayback()
            engine.send(.started)
            #expect(engine.volume == 0.8)
        }

        @Test func aFailedStartDoesNotLeaveItSilent() async {
            let appState = makeAppState()
            appState.playOnLaunch()
            engine.send(.failed(.notFound))
            await settle()
            appState.togglePlayback()
            #expect(engine.volume == 0.8)
        }

        @Test func mutedStaysMuted() async {
            let appState = makeAppState()
            appState.toggleMute()
            appState.playOnLaunch()
            engine.send(.started)
            await advance(3)
            #expect(engine.volume == 0)
            #expect(clock.pending.filter { $0 == step }.isEmpty)
        }

        @Test func wakingUpFadesInToo() async {
            let appState = makeAppState()
            appState.togglePlayback()
            engine.send(.started)
            sleepWatcher.onSleep?()
            sleepWatcher.onWake?()
            #expect(engine.volume == 0)
            engine.send(.started)
            await advance(AppState.fadeInSteps)
            #expect(abs(engine.volume - 0.8) < 0.0001)
        }
    }
}
