import Foundation
import Observation
import os

/// Ties the modules together; the interface reads everything from here.
@MainActor
@Observable
final class AppState {
    let player: RadioPlayer

    /// What the settings say to play; follows them as they change (SPEC FR-9).
    private(set) var stream: PlayableStream

    /// 0…1, remembered between launches (SPEC FR-8).
    private(set) var volume: Double
    /// Silences the app without forgetting `volume`; remembered too.
    private(set) var isMuted: Bool

    @ObservationIgnored private let networkMonitor: any NetworkMonitoring
    @ObservationIgnored private let sleepWatcher: any SleepWatching
    @ObservationIgnored private let playlistResolver = PlaylistResolver()
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let catalog: StreamCatalog
    /// Debug builds may force a stream; see `AppDelegate`.
    @ObservationIgnored private let streamOverride: URL?
    @ObservationIgnored private var settingsObserver: (any NSObjectProtocol)?
    /// Whether the player was busy when the Mac went to sleep; lives in memory only.
    @ObservationIgnored private var wasActiveBeforeSleep = false

    init(
        player: RadioPlayer,
        networkMonitor: any NetworkMonitoring,
        sleepWatcher: any SleepWatching,
        catalog: StreamCatalog = .bundled,
        defaults: UserDefaults = .standard,
        streamOverride: URL? = nil
    ) {
        self.player = player
        self.networkMonitor = networkMonitor
        self.sleepWatcher = sleepWatcher
        self.catalog = catalog
        self.defaults = defaults
        self.streamOverride = streamOverride
        Self.forgetUnknownStream(in: catalog, defaults: defaults)
        stream = Self.stream(in: catalog, defaults: defaults, override: streamOverride)
        volume = (defaults.object(forKey: SettingsKey.volume) as? Double).map { min(max($0, 0), 1) } ?? 1
        isMuted = defaults.bool(forKey: SettingsKey.isMuted)
        applyVolume()

        player.isNetworkAvailable = networkMonitor.isAvailable
        networkMonitor.onChange = { [weak player] isAvailable in
            player?.isNetworkAvailable = isAvailable
        }
        sleepWatcher.onSleep = { [weak self] in self?.prepareForSleep() }
        sleepWatcher.onWake = { [weak self] in self?.resumeAfterSleep() }
        settingsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: defaults, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.settingsChanged() }
        }
    }

    isolated deinit {
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
    }

    /// The «Включать радио при запуске» setting; on unless turned off (SPEC FR-10).
    var playsOnLaunch: Bool {
        // `bool(forKey:)` also understands "NO" from the command line, which `as? Bool` does not.
        defaults.object(forKey: SettingsKey.playOnLaunch) == nil || defaults.bool(forKey: SettingsKey.playOnLaunch)
    }

    // MARK: - Stream

    /// The station's streams, for the quality menu in the panel.
    var stationStreams: [RadioStream] { catalog.streams }

    /// The `streamId` setting as it stands, unknown ids included.
    var selectedStreamID: String {
        defaults.string(forKey: SettingsKey.streamID) ?? catalog.defaultStream.id
    }

    func selectStream(id: String) {
        defaults.set(id, forKey: SettingsKey.streamID)
    }

    /// Switching quality while playing starts the new stream at once (SPEC FR-9);
    /// stopped, it is only remembered.
    private func settingsChanged() {
        let latest = Self.stream(in: catalog, defaults: defaults, override: streamOverride)
        guard latest != stream else { return }
        stream = latest
        if player.state.isActive {
            player.stop()
            play()
        }
    }

    /// A stream dropped from a later `streams.json` would leave Settings with nothing
    /// selected while the default plays; the saved choice is moved to the default.
    private static func forgetUnknownStream(in catalog: StreamCatalog, defaults: UserDefaults) {
        guard let saved = defaults.string(forKey: SettingsKey.streamID),
              saved != StreamCatalog.customID,
              !catalog.streams.contains(where: { $0.id == saved })
        else { return }
        defaults.set(catalog.defaultStream.id, forKey: SettingsKey.streamID)
    }

    private static func stream(in catalog: StreamCatalog, defaults: UserDefaults, override: URL?) -> PlayableStream {
        if let override {
            return PlayableStream(url: override, shortTitle: "отладка", allowsFallback: true)
        }
        return catalog.playable(
            streamID: defaults.string(forKey: SettingsKey.streamID) ?? catalog.defaultStream.id,
            customAddress: defaults.string(forKey: SettingsKey.customURL) ?? ""
        )
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
        guard let url = stream.url else {
            player.reject(.invalidAddress)
            return
        }
        var fallback: RadioPlayer.Fallback?
        if stream.allowsFallback {
            let resolver = playlistResolver
            fallback = { try await resolver.resolve() }
        }
        player.play(url, fallback: fallback)
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
