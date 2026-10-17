import Foundation
import Observation
import os

/// The playback state machine (SPEC FR-4, FR-5). It makes no sound itself:
/// the engine plays, the player decides what each event means and when to try again.
@MainActor
@Observable
final class RadioPlayer {
    typealias Sleep = @Sendable (Duration) async throws -> Void
    /// Finds a stand-in address when the stream itself is gone (PLAN 3, emergency path).
    typealias Fallback = @Sendable () async throws -> URL

    private(set) var state: PlaybackState = .idle {
        didSet {
            // `notice`, not `info`: only these survive on disk for an overnight run.
            Logger.player.notice("\(String(describing: oldValue), privacy: .public) → \(String(describing: self.state), privacy: .public)")
        }
    }

    /// Whether the sound comes from the emergency path rather than the chosen stream.
    private(set) var isOnFallback = false

    /// The app's own volume, 0…1, passed straight to the engine.
    var volume: Float {
        get { engine.volume }
        set { engine.volume = newValue }
    }

    /// Kept up to date from `NetworkMonitor`. Its return cuts short the wait before the next attempt.
    var isNetworkAvailable = true {
        didSet {
            if isNetworkAvailable && !oldValue { retryNow() }
        }
    }

    @ObservationIgnored private let engine: any PlaybackEngine
    @ObservationIgnored private let policy: ReconnectPolicy
    @ObservationIgnored private let connectTimeout: Duration
    @ObservationIgnored private let stallTimeout: Duration
    @ObservationIgnored private let sleep: Sleep
    @ObservationIgnored private var url: URL?
    @ObservationIgnored private var fallback: Fallback?
    @ObservationIgnored private var failuresInARow = 0
    @ObservationIgnored private var timeoutTask: Task<Void, Never>?
    @ObservationIgnored private var stallTask: Task<Void, Never>?
    @ObservationIgnored private var retryTask: Task<Void, Never>?
    @ObservationIgnored private var fallbackTask: Task<Void, Never>?

    /// Failures in a row on the chosen stream, with the network up, before the emergency path is tried.
    private static let failuresBeforeFallback = 3

    /// - Parameter sleep: Waits out timeouts and retry delays; tests replace it.
    init(
        engine: any PlaybackEngine,
        policy: ReconnectPolicy = ReconnectPolicy(),
        connectTimeout: Duration = .seconds(15),
        stallTimeout: Duration = .seconds(10),
        sleep: @escaping Sleep = { try await Task.sleep(for: $0) }
    ) {
        self.engine = engine
        self.policy = policy
        self.connectTimeout = connectTimeout
        self.stallTimeout = stallTimeout
        self.sleep = sleep
        engine.onEvent = { [weak self] event in self?.handle(event) }
    }

    /// Starts the live stream at `url`. Does nothing unless stopped.
    /// - Parameter fallback: The emergency path, for the station's own streams only.
    func play(_ url: URL, fallback: Fallback? = nil) {
        guard !state.isActive else {
            Logger.player.debug("play() ignored while \(String(describing: self.state), privacy: .public)")
            return
        }
        self.url = url
        self.fallback = fallback
        failuresInARow = 0
        isOnFallback = false
        state = .connecting
        start(url)
    }

    /// Stops completely; the next `play` starts from the live edge.
    func stop() {
        cancelTasks()
        engine.stop()
        isOnFallback = false
        state = .idle
    }

    // MARK: - Transitions

    private func handle(_ event: PlaybackEngineEvent) {
        switch (event, state) {
        case (.started, .connecting), (.started, .reconnecting):
            cancelTasks()
            failuresInARow = 0
            state = .playing
        case (.started, .playing):
            // Sound is back after a stall.
            stallTask?.cancel()
            stallTask = nil
        case (.stalled, .playing) where stallTask == nil:
            // A second report of the same stall must not restart the clock.
            stallTask = after(stallTimeout) { $0.stalledTooLong() }
        case (.failed(let failure), .connecting), (.failed(let failure), .playing),
             (.failed(let failure), .reconnecting):
            fail(failure)
        default:
            // A late event after `stop()` is an ordinary race, not a bug.
            Logger.player.debug("Ignored \(String(describing: event), privacy: .public) while \(String(describing: self.state), privacy: .public)")
        }
    }

    private func fail(_ failure: PlaybackFailure) {
        Logger.player.notice("Failure: \(String(describing: failure), privacy: .public)")
        cancelTasks()
        engine.stop()
        if !isOnFallback {
            failuresInARow += 1
        }
        if shouldTryFallback(after: failure) {
            tryFallback(after: failure)
        } else if failure.isRecoverable {
            state = .reconnecting(attempt: state.reconnectAttempt + 1)
            scheduleRetry()
        } else {
            state = .error(failure)
        }
    }

    private func stalledTooLong() {
        guard state == .playing else { return }
        fail(.stalled)
    }

    private func connectTimedOut() {
        guard state == .connecting || state.reconnectAttempt > 0 else { return }
        fail(.connectTimeout)
    }

    // MARK: - Retrying

    private func scheduleRetry() {
        let delay = policy.delay(beforeAttempt: state.reconnectAttempt)
        retryTask = after(delay) { $0.retry() }
    }

    /// Skips the rest of the wait, if the player is waiting.
    private func retryNow() {
        guard retryTask != nil else { return }
        Logger.player.notice("Network is back, retrying now")
        retry()
    }

    /// Every new cycle tries the chosen stream first, so the emergency path never sticks.
    private func retry() {
        cancelTasks()
        guard state.reconnectAttempt > 0, let url else { return }
        isOnFallback = false
        start(url)
    }

    // MARK: - Emergency path

    private func shouldTryFallback(after failure: PlaybackFailure) -> Bool {
        guard fallback != nil, !isOnFallback else { return false }
        return !failure.isRecoverable
            || (isNetworkAvailable && failuresInARow >= Self.failuresBeforeFallback)
    }

    private func tryFallback(after failure: PlaybackFailure) {
        guard let fallback else { return }
        failuresInARow = 0
        state = .reconnecting(attempt: state.reconnectAttempt + 1)
        fallbackTask = Task { [weak self] in
            do {
                let url = try await fallback()
                guard !Task.isCancelled else { return }
                self?.startFallback(url)
            } catch {
                guard !Task.isCancelled else { return }
                self?.fallbackUnavailable(after: failure, error: error)
            }
        }
    }

    private func startFallback(_ url: URL) {
        Logger.player.notice("Emergency path: \(url.absoluteString, privacy: .public)")
        fallbackTask = nil
        isOnFallback = true
        start(url)
    }

    private func fallbackUnavailable(after failure: PlaybackFailure, error: any Error) {
        Logger.player.error("Emergency path unavailable: \(error, privacy: .public)")
        fallbackTask = nil
        if failure.isRecoverable {
            scheduleRetry()
        } else {
            state = .error(failure)
        }
    }

    // MARK: - Engine and timers

    private func start(_ url: URL) {
        engine.start(url: url)
        timeoutTask = after(connectTimeout) { $0.connectTimedOut() }
    }

    /// Runs `action` after `delay` unless cancelled first.
    private func after(
        _ delay: Duration,
        _ action: @escaping @MainActor @Sendable (RadioPlayer) -> Void
    ) -> Task<Void, Never> {
        Task { [weak self, sleep] in
            do {
                try await sleep(delay)
            } catch {
                return
            }
            guard !Task.isCancelled, let self else { return }
            action(self)
        }
    }

    private func cancelTasks() {
        for task in [timeoutTask, stallTask, retryTask, fallbackTask] {
            task?.cancel()
        }
        timeoutTask = nil
        stallTask = nil
        retryTask = nil
        fallbackTask = nil
    }
}
