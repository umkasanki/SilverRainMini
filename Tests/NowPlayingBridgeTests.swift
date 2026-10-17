import Foundation
import MediaPlayer
import Testing
@testable import SilverRainMini

/// SPEC FR-11: what Control Centre shows and what the media keys do.
@MainActor
struct NowPlayingBridgeTests {
    @Test(arguments: [
        (PlaybackState.idle, MPNowPlayingPlaybackState.paused),
        (.connecting, .playing),
        (.playing, .playing),
        (.reconnecting(attempt: 2), .playing),
        (.error(.notFound), .paused),
    ])
    func playbackState(state: PlaybackState, expected: MPNowPlayingPlaybackState) {
        #expect(NowPlayingBridge.playbackState(for: state) == expected)
    }

    @Test func theTileNamesTheStationAndWhatItIsDoing() {
        let info = NowPlayingBridge.info(state: .playing, isOnFallback: false, streamTitle: "AAC 96")
        #expect(info[MPMediaItemPropertyTitle] as? String == "Серебряный Дождь")
        #expect(info[MPMediaItemPropertyArtist] as? String == "В эфире · AAC 96")
        #expect(info[MPNowPlayingInfoPropertyIsLiveStream] as? Bool == true)
    }

    @Test func theCoverIsTheLogoAtFullSize() {
        let cover = StationArtwork.coverImage()
        #expect(cover.size == CGSize(width: 600, height: 600))
    }
}

extension SettingsTests {
    /// SPEC FR-11: the bridge on a real AppState with a fake engine and a fake
    /// system, so the run never touches the real tile or media keys.
    @MainActor
    struct RemoteCommandTests {
        private final class StillNetwork: NetworkMonitoring {
            var isAvailable = true
            var onChange: ((Bool) -> Void)?
        }

        private final class NoSleep: SleepWatching {
            var onSleep: (() -> Void)?
            var onWake: (() -> Void)?
        }

        private final class FakeSystem: NowPlayingSystem {
            private(set) var published: [(title: String?, state: MPNowPlayingPlaybackState)] = []
            private(set) var send: ((NowPlayingBridge.Command) -> Void)?

            func publish(_ info: [String: Any]?, state: MPNowPlayingPlaybackState) {
                published.append((info?[MPMediaItemPropertyArtist] as? String, state))
            }

            func onCommand(_ handler: @escaping @MainActor (NowPlayingBridge.Command) -> Void) {
                send = handler
            }
        }

        private let engine = FakePlaybackEngine()
        private let system = FakeSystem()

        private func makeAppState() -> AppState {
            AppState(
                player: RadioPlayer(engine: engine),
                networkMonitor: StillNetwork(),
                sleepWatcher: NoSleep(),
                defaults: TestDefaults.fresh(),
                playlistResolver: .offline
            )
        }

        @Test func silentUntilTheRadioFirstPlays() async {
            let appState = makeAppState()
            let bridge = NowPlayingBridge(appState: appState, system: system)
            await settle()
            #expect(system.published.isEmpty, "F8 must stay with Music until the radio is used")
            appState.togglePlayback()
            await settle { !system.published.isEmpty }
            #expect(system.published.last?.state == .playing)
            appState.togglePlayback()
            await settle { system.published.last?.state == .paused }
            #expect(system.published.last?.state == .paused, "idle after playing keeps the tile")
            _ = bridge
        }

        @Test func playStartsAndPlayingTwiceDoesNotRestart() {
            let appState = makeAppState()
            let bridge = NowPlayingBridge(appState: appState, system: system)
            system.send?(.play)
            engine.send(.started)
            system.send?(.play)
            #expect(appState.player.state == .playing)
            #expect(engine.startedURLs.count == 1)
            _ = bridge
        }

        @Test func pauseIsAFullStop() {
            let appState = makeAppState()
            let bridge = NowPlayingBridge(appState: appState, system: system)
            system.send?(.play)
            engine.send(.started)
            system.send?(.pause)
            #expect(appState.player.state == .idle)
            system.send?(.stop)
            #expect(appState.player.state == .idle)
            _ = bridge
        }

        @Test func toggleFlips() {
            let appState = makeAppState()
            let bridge = NowPlayingBridge(appState: appState, system: system)
            system.send?(.togglePlayPause)
            #expect(appState.player.state == .connecting)
            system.send?(.togglePlayPause)
            #expect(appState.player.state == .idle)
            _ = bridge
        }

        @Test func quittingClearsTheTile() {
            let appState = makeAppState()
            let bridge = NowPlayingBridge(appState: appState, system: system)
            bridge.clear()
            #expect(system.published.last?.title == nil)
            #expect(system.published.last?.state == .stopped)
        }

        @Test func noLeftoversOnceTheBridgeIsGone() async {
            weak var weakAppState: AppState?
            do {
                let appState = makeAppState()
                weakAppState = appState
                _ = NowPlayingBridge(appState: appState, system: system)
                await settle()
            }
            await settle { weakAppState == nil }
            #expect(weakAppState == nil)
        }
    }
}
