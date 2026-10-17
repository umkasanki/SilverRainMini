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
    /// SPEC FR-11: the remote commands, on a real AppState with a fake engine.
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

        private let engine = FakePlaybackEngine()

        private func makeBridge() -> (NowPlayingBridge, AppState) {
            let appState = AppState(
                player: RadioPlayer(engine: engine),
                networkMonitor: StillNetwork(),
                sleepWatcher: NoSleep(),
                defaults: TestDefaults.fresh(),
                playlistResolver: .offline
            )
            return (NowPlayingBridge(appState: appState), appState)
        }

        @Test func playStartsAndPlayingTwiceDoesNotRestart() {
            let (bridge, appState) = makeBridge()
            bridge.perform(.play)
            engine.send(.started)
            bridge.perform(.play)
            #expect(appState.player.state == .playing)
            #expect(engine.startedURLs.count == 1)
        }

        @Test func pauseIsAFullStop() {
            let (bridge, appState) = makeBridge()
            bridge.perform(.play)
            engine.send(.started)
            bridge.perform(.pause)
            #expect(appState.player.state == .idle)
            bridge.perform(.pause)
            #expect(appState.player.state == .idle)
        }

        @Test func toggleFlipsAndF8DoesTheSame() {
            let (bridge, appState) = makeBridge()
            bridge.perform(.togglePlayPause)
            #expect(appState.player.state == .connecting)
            bridge.perform(.togglePlayPause)
            #expect(appState.player.state == .idle)
        }

        @Test func everyCommandReportsSuccess() {
            let (bridge, _) = makeBridge()
            for command in [NowPlayingBridge.Command.play, .pause, .togglePlayPause, .stop] {
                #expect(bridge.perform(command) == .success)
            }
        }
    }
}
