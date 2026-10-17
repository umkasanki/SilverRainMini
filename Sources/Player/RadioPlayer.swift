import Foundation
import Observation
import os

/// The playback state machine (SPEC FR-4). It makes no sound itself:
/// the engine plays, the player decides what each event means.
@MainActor
@Observable
final class RadioPlayer {
    typealias Sleep = @Sendable (Duration) async throws -> Void

    private(set) var state: PlaybackState = .idle {
        didSet {
            // `notice`, not `info`: only these survive on disk for an overnight run.
            Logger.player.notice("\(String(describing: oldValue), privacy: .public) → \(String(describing: self.state), privacy: .public)")
        }
    }

    @ObservationIgnored private let engine: any PlaybackEngine
    @ObservationIgnored private let connectTimeout: Duration
    @ObservationIgnored private let sleep: Sleep
    @ObservationIgnored private var url: URL?
    @ObservationIgnored private var timeoutTask: Task<Void, Never>?

    /// - Parameter sleep: Waits out the connect timeout; tests replace it.
    init(
        engine: any PlaybackEngine,
        connectTimeout: Duration = .seconds(15),
        sleep: @escaping Sleep = { try await Task.sleep(for: $0) }
    ) {
        self.engine = engine
        self.connectTimeout = connectTimeout
        self.sleep = sleep
        engine.onEvent = { [weak self] event in self?.handle(event) }
    }

    /// Starts the live stream at `url`. Does nothing unless stopped.
    func play(_ url: URL) {
        guard !state.isActive else {
            Logger.player.debug("play() ignored while \(String(describing: self.state), privacy: .public)")
            return
        }
        self.url = url
        state = .connecting
        startEngine()
    }

    /// Stops completely; the next `play` starts from the live edge.
    func stop() {
        cancelTimeout()
        engine.stop()
        state = .idle
    }

    // MARK: - Transitions

    private func handle(_ event: PlaybackEngineEvent) {
        switch (event, state) {
        case (.started, .connecting), (.started, .reconnecting):
            cancelTimeout()
            state = .playing
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
        cancelTimeout()
        engine.stop()
        if failure.isRecoverable {
            // The retry schedule arrives in step S3 (`ReconnectPolicy`).
            state = .reconnecting(attempt: state.reconnectAttempt + 1)
        } else {
            state = .error(failure)
        }
    }

    // MARK: - Engine and timeout

    private func startEngine() {
        guard let url else { return }
        engine.start(url: url)
        armTimeout()
    }

    private func armTimeout() {
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self, sleep, connectTimeout] in
            do {
                try await sleep(connectTimeout)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.connectTimedOut()
        }
    }

    private func cancelTimeout() {
        timeoutTask?.cancel()
        timeoutTask = nil
    }

    private func connectTimedOut() {
        guard state == .connecting || state.reconnectAttempt > 0 else { return }
        fail(.connectTimeout)
    }
}
