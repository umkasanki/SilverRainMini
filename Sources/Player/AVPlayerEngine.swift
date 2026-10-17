import AVFoundation
import os

/// Plays a live stream with `AVPlayer` and tells `RadioPlayer` only two things:
/// sound has started, or the stream has failed.
@MainActor
final class AVPlayerEngine: PlaybackEngine {
    var onEvent: ((PlaybackEngineEvent) -> Void)?

    private let player = AVPlayer()
    private var observations: [NSKeyValueObservation] = []
    private var failureObserver: (any NSObjectProtocol)?

    /// Enough to ride out a short network hiccup without a long delay to the live edge.
    private static let forwardBufferDuration: TimeInterval = 5

    init() {
        player.automaticallyWaitsToMinimizeStalling = true
    }

    func start(url: URL) {
        stop()
        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = Self.forwardBufferDuration
        observe(item)
        player.replaceCurrentItem(with: item)
        player.play()
        Logger.player.notice("Starting \(url.absoluteString, privacy: .public)")
    }

    func stop() {
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

    private func observe(_ item: AVPlayerItem) {
        let itemID = ObjectIdentifier(item)
        observations = [
            player.observe(\.timeControlStatus) { [weak self] player, _ in
                guard player.timeControlStatus == .playing else { return }
                Task { @MainActor in self?.report(.started, for: itemID) }
            },
            item.observe(\.status) { [weak self] item, _ in
                guard item.status == .failed, let error = item.error else { return }
                Task { @MainActor in self?.report(error, for: itemID) }
            },
        ]
        // A stream that was playing and then broke does not change `status`.
        failureObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.failedToPlayToEndTimeNotification, object: item, queue: .main
        ) { [weak self] notification in
            let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? any Error
            Task { @MainActor in self?.report(error, for: itemID) }
        }
    }

    private func report(_ error: (any Error)?, for itemID: ObjectIdentifier) {
        if let error {
            Logger.player.error("Stream failed: \(error as NSError, privacy: .public)")
        }
        report(.failed(error.map(PlaybackFailure.init) ?? .unreachable), for: itemID)
    }

    /// Drops events from an item that has since been replaced or stopped.
    private func report(_ event: PlaybackEngineEvent, for itemID: ObjectIdentifier) {
        guard let current = player.currentItem, ObjectIdentifier(current) == itemID else { return }
        onEvent?(event)
    }
}
