import Foundation
import Testing
@testable import SilverRainMini

/// SPEC FR-8: the app's own volume, remembered with the mute between launches.
@MainActor
struct VolumeTests {
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

    @Test func fullVolumeOnFirstLaunch() {
        let appState = makeAppState()
        #expect(appState.volume == 1)
        #expect(!appState.isMuted)
        #expect(engine.volume == 1)
    }

    @Test func volumeReachesTheEngineAndIsRemembered() {
        makeAppState().setVolume(0.4)
        #expect(engine.volume == 0.4)
        let relaunched = makeAppState()
        #expect(relaunched.volume == 0.4)
        #expect(engine.volume == 0.4)
    }

    @Test(arguments: [(-0.3, 0.0), (1.7, 1.0)])
    func volumeStaysInRange(asked: Double, kept: Double) {
        let appState = makeAppState()
        appState.setVolume(asked)
        #expect(appState.volume == kept)
    }

    @Test func muteSilencesButKeepsTheLevel() {
        let appState = makeAppState()
        appState.setVolume(0.6)
        appState.toggleMute()
        #expect(engine.volume == 0)
        #expect(appState.volume == 0.6)
        appState.toggleMute()
        #expect(engine.volume == 0.6)
    }

    @Test func muteIsRememberedToo() {
        let appState = makeAppState()
        appState.setVolume(0.6)
        appState.toggleMute()
        let relaunched = makeAppState()
        #expect(relaunched.isMuted)
        #expect(engine.volume == 0)
    }

    @Test func quickAdjustmentsAddUp() {
        let appState = makeAppState()
        appState.setVolume(0.5)
        appState.adjustVolume(by: 0.05)
        appState.adjustVolume(by: 0.05)
        appState.adjustVolume(by: 0.05)
        #expect(abs(appState.volume - 0.65) < 0.0001)
    }

    @Test func aDragIsSavedOnlyWhenItEnds() {
        let appState = makeAppState()
        appState.setVolume(0.2)
        appState.setVolume(0.7, persist: false)
        #expect(engine.volume == 0.7)
        #expect(makeAppState().volume == 0.2)
        appState.setVolume(0.7)
        #expect(makeAppState().volume == 0.7)
    }

    @Test func anyVolumeChangeLiftsTheMute() {
        let appState = makeAppState()
        appState.toggleMute()
        appState.setVolume(0.3)
        #expect(!appState.isMuted)
        #expect(engine.volume == 0.3)
    }
}
