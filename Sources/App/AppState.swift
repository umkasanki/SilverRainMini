import Foundation
import Observation
import os

/// Ties the modules together; the interface reads everything from here.
@MainActor
@Observable
final class AppState {
    let player: RadioPlayer

    /// Fixed until the stream catalog arrives in step S6.
    let streamURL: URL
    /// The short name of the stream for the interface; fixed until step S6.
    let streamTitle = "AAC 96"

    /// 0…1, remembered between launches (SPEC FR-8).
    private(set) var volume: Double
    /// Silences the app without forgetting `volume`; remembered too.
    private(set) var isMuted: Bool

    @ObservationIgnored private let networkMonitor: any NetworkMonitoring
    @ObservationIgnored private let sleepWatcher: any SleepWatching
    @ObservationIgnored private let playlistResolver = PlaylistResolver()
    @ObservationIgnored private let defaults: UserDefaults
    /// Whether the player was busy when the Mac went to sleep; lives in memory only.
    @ObservationIgnored private var wasActiveBeforeSleep = false

    static let defaultStreamURL = URL(string: "https://silverrain.hostingradio.ru/silver64.aac")!

    init(
        player: RadioPlayer,
        networkMonitor: any NetworkMonitoring,
        sleepWatcher: any SleepWatching,
        streamURL: URL = AppState.defaultStreamURL,
        defaults: UserDefaults = .standard
    ) {
        self.player = player
        self.networkMonitor = networkMonitor
        self.sleepWatcher = sleepWatcher
        self.streamURL = streamURL
        self.defaults = defaults
        volume = (defaults.object(forKey: SettingsKey.volume) as? Double).map { min(max($0, 0), 1) } ?? 1
        isMuted = defaults.bool(forKey: SettingsKey.isMuted)
        applyVolume()

        player.isNetworkAvailable = networkMonitor.isAvailable
        networkMonitor.onChange = { [weak player] isAvailable in
            player?.isNetworkAvailable = isAvailable
        }
        sleepWatcher.onSleep = { [weak self] in self?.prepareForSleep() }
        sleepWatcher.onWake = { [weak self] in self?.resumeAfterSleep() }
    }

    /// ▶︎ or ⏸: starts the live stream, or stops whatever the player is doing.
    func togglePlayback() {
        if player.state.isActive {
            player.stop()
        } else {
            play()
        }
    }

    // MARK: - Volume

    /// Any change of volume also lifts the mute (SPEC FR-8).
    /// - Parameter persist: False while a drag is still moving; the level is saved once, at the end.
    func setVolume(_ volume: Double, persist: Bool = true) {
        self.volume = min(max(volume, 0), 1)
        setMuted(false)
        if persist {
            defaults.set(self.volume, forKey: SettingsKey.volume)
        }
        applyVolume()
    }

    /// Moves the level from wherever it is now, so quick scroll events add up.
    func adjustVolume(by delta: Double) {
        setVolume(volume + delta)
    }

    func toggleMute() {
        setMuted(!isMuted)
        applyVolume()
    }

    private func setMuted(_ isMuted: Bool) {
        guard isMuted != self.isMuted else { return }
        self.isMuted = isMuted
        defaults.set(isMuted, forKey: SettingsKey.isMuted)
    }

    private func applyVolume() {
        player.volume = isMuted ? 0 : Float(volume)
    }

    // MARK: - Playback

    private func play() {
        let resolver = playlistResolver
        player.play(streamURL, fallback: { try await resolver.resolve() })
    }

    // MARK: - Sleep

    private func prepareForSleep() {
        wasActiveBeforeSleep = player.state.isActive
        if wasActiveBeforeSleep {
            player.stop()
        }
    }

    private func resumeAfterSleep() {
        guard wasActiveBeforeSleep else { return }
        wasActiveBeforeSleep = false
        play()
    }
}
