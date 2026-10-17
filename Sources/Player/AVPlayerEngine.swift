import AVFoundation
import os

/// Plays a live stream with `AVPlayer` and tells `RadioPlayer` only two things:
/// sound has started, or the stream has failed.
@MainActor
final class AVPlayerEngine: PlaybackEngine {
    var onEvent: ((PlaybackEngineEvent) -> Void)?

    var volume: Float {
        get { player.volume }
        set { player.volume = newValue }
    }

    private let player = AVPlayer()
    private var observations: [NSKeyValueObservation] = []
    private var failureObserver: (any NSObjectProtocol)?
    /// Whether the current stream has made any sound yet: waiting before that is
    /// connecting, waiting after it is a stall.
    private var hasStarted = false
    /// Counts `start` and `stop` calls. Each stream's observers carry the value it
    /// was started with, so a late event from an earlier stream is recognised even
    /// if the new item happens to occupy the old one's memory.
    private var generation = 0

    /// Enough to ride out a short network hiccup without a long delay to the live edge.
    private static let forwardBufferDuration: TimeInterval = 5

    init() {
        player.automaticallyWaitsToMinimizeStalling = true
    }

    func start(url: URL) {
        stop()
        hasStarted = false
        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = Self.forwardBufferDuration
        observe(item, generation: generation)
        player.replaceCurrentItem(with: item)
        player.play()
        Logger.player.notice("Starting \(url.absoluteString, privacy: .public)")
    }

    func stop() {
        generation += 1
        observations.forEach { $0.invalidate() }
        observations.removeAll()
        if let failureObserver {
            NotificationCenter.default.removeObserver(failureObserver)
        }
        failureObserver = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
    }

    // MARK: - Observing

    private func observe(_ item: AVPlayerItem, generation: Int) {
        observations = [
            player.observe(\.timeControlStatus) { [weak self] player, _ in
                let status = player.timeControlStatus
                Task { @MainActor in self?.timeControlStatusChanged(to: status, for: generation) }
            },
            item.observe(\.status) { [weak self] item, _ in
                guard item.status == .failed, let error = item.error else { return }
                Task { @MainActor in self?.report(error, for: generation) }
            },
        ]
        // A stream that was playing and then broke does not change `status`.
        failureObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.failedToPlayToEndTimeNotification, object: item, queue: .main
        ) { [weak self] notification in
            let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? any Error
            Task { @MainActor in self?.report(error, for: generation) }
        }
    }

    private func timeControlStatusChanged(to status: AVPlayer.TimeControlStatus, for generation: Int) {
        guard generation == self.generation else { return }
        switch status {
        case .playing:
            hasStarted = true
            report(.started, for: generation)
        case .waitingToPlayAtSpecifiedRate where hasStarted:
            report(.stalled, for: generation)
        default:
            break
        }
    }

    private func report(_ error: (any Error)?, for generation: Int) {
        guard generation == self.generation else { return }
        if let error {
            Logger.player.error("Stream failed: \(error as NSError, privacy: .public)")
        }
        report(.failed(error.map(PlaybackFailure.init) ?? .unreachable), for: generation)
    }

    /// Drops events from a stream that has since been replaced or stopped.
    private func report(_ event: PlaybackEngineEvent, for generation: Int) {
        guard generation == self.generation else { return }
        onEvent?(event)
    }
}
