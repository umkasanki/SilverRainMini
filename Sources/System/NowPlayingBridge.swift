import AppKit
import MediaPlayer
import os

/// The part of the system that shows Now Playing and hands out remote commands;
/// tests stand in for it, so a test run never touches the real tile or keys.
@MainActor
protocol NowPlayingSystem: AnyObject {
    func publish(_ info: [String: Any]?, state: MPNowPlayingPlaybackState)
    func onCommand(_ handler: @escaping @MainActor (NowPlayingBridge.Command) -> Void)
}

/// The system's Now Playing (SPEC FR-11): the tile in Control Centre, the media
/// keys and the lock screen all come from here.
@MainActor
final class NowPlayingBridge {
    enum Command {
        case play, pause, togglePlayPause, stop
    }

    private let appState: AppState
    private let system: any NowPlayingSystem
    private let now: () -> ContinuousClock.Instant
    private var observation: Task<Void, Never>?
    private var startPause = StartPauseGuard()
    /// Nothing is shown until the radio has played once: claimed at launch, the
    /// tile and F8 would be taken from Music before the user asked for the radio.
    private var hasPlayed = false

    init(
        appState: AppState,
        system: any NowPlayingSystem = SystemNowPlaying(),
        now: @escaping () -> ContinuousClock.Instant = { .now }
    ) {
        self.appState = appState
        self.system = system
        self.now = now
        system.onCommand { [weak self] command in self?.perform(command) }
        observePlayer()
    }

    isolated deinit {
        observation?.cancel()
    }

    /// Clears the tile on quit (SPEC FR-12).
    func clear() {
        observation?.cancel()
        system.publish(nil, state: .stopped)
    }

    // MARK: - What the system shows

    /// «Paused» rather than «stopped» while idle: stopped, macOS may hand the
    /// media keys and the tile to another app, and F8 would start Music instead.
    static func playbackState(for state: PlaybackState) -> MPNowPlayingPlaybackState {
        state.isActive ? .playing : .paused
    }

    /// Everything but the artwork, which the system part adds.
    static func info(state: PlaybackState, isOnFallback: Bool, streamTitle: String) -> [String: Any] {
        [
            MPMediaItemPropertyTitle: "Серебряный Дождь",
            MPMediaItemPropertyArtist: NowPlayingCard.subtitle(
                for: state, isOnFallback: isOnFallback, streamTitle: streamTitle
            ),
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
        ]
    }

    /// Follows the player for as long as both the bridge and the app state exist.
    private func observePlayer() {
        observation = Task { [weak self, weak appState] in
            for await snapshot in Observations({ [weak appState] in
                appState.map { ($0.player.state, $0.player.isOnFallback, $0.stream.shortTitle) }
            }) {
                guard let self, let snapshot else { return }
                publish(state: snapshot.0, isOnFallback: snapshot.1, streamTitle: snapshot.2)
            }
            _ = appState
        }
    }

    private func publish(state: PlaybackState, isOnFallback: Bool, streamTitle: String) {
        startPause.note(state, at: now())
        if state.isActive {
            hasPlayed = true
        }
        guard hasPlayed else { return }
        system.publish(
            Self.info(state: state, isOnFallback: isOnFallback, streamTitle: streamTitle),
            state: Self.playbackState(for: state)
        )
    }

    // MARK: - Commands

    /// What a remote command does. Pause is a full stop: live radio has no place
    /// to resume from, the next play starts at the live edge.
    func perform(_ command: Command) {
        Logger.system.notice("Remote command: \(String(describing: command), privacy: .public)")
        switch command {
        case .play: appState.startPlayback()
        case .pause:
            if startPause.ignoresPause(at: now()) {
                Logger.system.notice("Remote pause ignored: the first one right after a start")
                return
            }
            appState.stopPlayback()
        case .stop: appState.stopPlayback()
        case .togglePlayPause: appState.togglePlayback()
        }
    }
}

/// Lets the first remote `pause` right after a start go.
///
/// A Sonos joined to the Mac both ways — Bluetooth as the system output, AirPlay
/// for the radio through SoundSource — switches inputs when the radio's AirPlay
/// stream reaches it after something played over Bluetooth, and tells the
/// Bluetooth source to pause. The Mac cannot tell whom that was for and hands it
/// to the app now playing: the radio stopped a few seconds into the sound, every
/// time, and played on the second click (measured 01.11.2026: the pause came
/// 2.5–3.2 s after the sound started). Apple Music routed the same way did the same.
///
/// Only `pause`, which is what Bluetooth sends; F8 and Control Centre send
/// `togglePlayPause` and are never held back. Only the first one, only while
/// connecting and for `window` after the sound starts.
struct StartPauseGuard {
    static let window: Duration = .seconds(5)

    private var wasActive = false
    private var armed = false
    private var soundSince: ContinuousClock.Instant?

    mutating func note(_ state: PlaybackState, at now: ContinuousClock.Instant) {
        if state.isActive, !wasActive {
            armed = true
            soundSince = nil
        }
        if state == .playing, soundSince == nil {
            soundSince = now
        }
        if !state.isActive {
            armed = false
        }
        wasActive = state.isActive
    }

    mutating func ignoresPause(at now: ContinuousClock.Instant) -> Bool {
        guard armed else { return false }
        armed = false
        guard let soundSince else { return true }
        return now - soundSince <= Self.window
    }
}

/// The real `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter`.
@MainActor
final class SystemNowPlaying: NowPlayingSystem {
    private let infoCenter = MPNowPlayingInfoCenter.default()
    private let commandCenter = MPRemoteCommandCenter.shared()

    /// Drawn once and handed out for every request: the logo does not change.
    private let artwork: MPMediaItemArtwork = {
        let cover = StationArtwork.coverImage()
        return MPMediaItemArtwork(boundsSize: cover.size) { _ in cover }
    }()

    func publish(_ info: [String: Any]?, state: MPNowPlayingPlaybackState) {
        var info = info
        info?[MPMediaItemPropertyArtwork] = artwork
        infoCenter.nowPlayingInfo = info
        infoCenter.playbackState = state
    }

    func onCommand(_ handler: @escaping @MainActor (NowPlayingBridge.Command) -> Void) {
        let commands: [(MPRemoteCommand, NowPlayingBridge.Command)] = [
            (commandCenter.playCommand, .play),
            (commandCenter.pauseCommand, .pause),
            (commandCenter.togglePlayPauseCommand, .togglePlayPause),
            (commandCenter.stopCommand, .stop),
        ]
        for (remote, command) in commands {
            remote.isEnabled = true
            remote.addTarget { _ in
                // Nothing promises the main thread here; never assume it.
                if Thread.isMainThread {
                    MainActor.assumeIsolated { handler(command) }
                } else {
                    Task { @MainActor in handler(command) }
                }
                return .success
            }
        }
        // A live stream cannot be skipped or wound.
        for remote in [
            commandCenter.nextTrackCommand, commandCenter.previousTrackCommand,
            commandCenter.skipForwardCommand, commandCenter.skipBackwardCommand,
            commandCenter.seekForwardCommand, commandCenter.seekBackwardCommand,
            commandCenter.changePlaybackPositionCommand,
        ] {
            remote.isEnabled = false
        }
    }
}
