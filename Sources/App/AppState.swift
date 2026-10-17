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

    @ObservationIgnored private let networkMonitor: NetworkMonitor
    @ObservationIgnored private let sleepWatcher: SleepWatcher
    @ObservationIgnored private let playlistResolver = PlaylistResolver()
    /// Whether the player was busy when the Mac went to sleep; lives in memory only.
    @ObservationIgnored private var wasActiveBeforeSleep = false

    static let defaultStreamURL = URL(string: "https://silverrain.hostingradio.ru/silver64.aac")!

    init(
        player: RadioPlayer,
        networkMonitor: NetworkMonitor,
        sleepWatcher: SleepWatcher,
        streamURL: URL = AppState.defaultStreamURL
    ) {
        self.player = player
        self.networkMonitor = networkMonitor
        self.sleepWatcher = sleepWatcher
        self.streamURL = streamURL

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
