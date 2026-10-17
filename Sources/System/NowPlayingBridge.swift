import AppKit
import MediaPlayer
import os

/// The system's Now Playing (SPEC FR-11): the tile in Control Centre, the media
/// keys, AirPods buttons and the lock screen all come from here.
@MainActor
final class NowPlayingBridge {
    enum Command {
        case play, pause, togglePlayPause, stop
    }

    private let appState: AppState
    private let infoCenter: MPNowPlayingInfoCenter
    private let commandCenter: MPRemoteCommandCenter
    private var observation: Task<Void, Never>?

    /// Built once: the logo does not change.
    private let artwork = MPMediaItemArtwork(boundsSize: CGSize(width: 600, height: 600)) { _ in
        StationArtwork.coverImage()
    }

    init(
        appState: AppState,
        infoCenter: MPNowPlayingInfoCenter = .default(),
        commandCenter: MPRemoteCommandCenter = .shared()
    ) {
        self.appState = appState
        self.infoCenter = infoCenter
        self.commandCenter = commandCenter
        configureCommands()
        observePlayer()
    }

    /// Clears the tile on quit (SPEC FR-12).
    func clear() {
        observation?.cancel()
        infoCenter.nowPlayingInfo = nil
        infoCenter.playbackState = .stopped
    }

    // MARK: - What the system shows

    /// «Paused» rather than «stopped» while idle: stopped, macOS may hand the
    /// media keys and the tile to another app, and F8 would start Music instead.
    static func playbackState(for state: PlaybackState) -> MPNowPlayingPlaybackState {
        state.isActive ? .playing : .paused
    }

    /// Everything but the artwork, which is added once it exists.
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

    private func observePlayer() {
        let appState = self.appState
        observation = Task { [weak self] in
            for await snapshot in Observations({
                (appState.player.state, appState.player.isOnFallback, appState.stream.shortTitle)
            }) {
                self?.publish(state: snapshot.0, isOnFallback: snapshot.1, streamTitle: snapshot.2)
            }
        }
    }

    private func publish(state: PlaybackState, isOnFallback: Bool, streamTitle: String) {
        var info = Self.info(state: state, isOnFallback: isOnFallback, streamTitle: streamTitle)
        info[MPMediaItemPropertyArtwork] = artwork
        infoCenter.nowPlayingInfo = info
        infoCenter.playbackState = Self.playbackState(for: state)
    }

    // MARK: - Commands

    /// What a remote command does. Pause is a full stop: live radio has no place
    /// to resume from, the next play starts at the live edge.
    @discardableResult
    func perform(_ command: Command) -> MPRemoteCommandHandlerStatus {
        Logger.system.notice("Remote command: \(String(describing: command), privacy: .public)")
        switch command {
        case .play: appState.startPlayback()
        case .pause, .stop: appState.stopPlayback()
        case .togglePlayPause: appState.togglePlayback()
        }
        return .success
    }

    private func configureCommands() {
        let handlers: [(MPRemoteCommand, Command)] = [
            (commandCenter.playCommand, .play),
            (commandCenter.pauseCommand, .pause),
            (commandCenter.togglePlayPauseCommand, .togglePlayPause),
            (commandCenter.stopCommand, .stop),
        ]
        for (remote, command) in handlers {
            remote.isEnabled = true
            remote.addTarget { [weak self] _ in
                MainActor.assumeIsolated { self?.perform(command) ?? .commandFailed }
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
