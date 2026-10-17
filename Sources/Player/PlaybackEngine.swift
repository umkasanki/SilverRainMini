import Foundation

/// What `RadioPlayer` needs from whatever actually makes the sound.
/// The protocol lets the state machine be tested without a network.
@MainActor
protocol PlaybackEngine: AnyObject {
    /// Reports what happened to the stream started last.
    var onEvent: ((PlaybackEngineEvent) -> Void)? { get set }

    /// The app's own volume, 0…1; the system volume is left alone. Survives `start`.
    var volume: Float { get set }

    /// Drops whatever was playing and starts `url` from the live edge.
    func start(url: URL)

    /// Drops whatever was playing. No events follow.
    func stop()
}

enum PlaybackEngineEvent: Equatable, Sendable {
    /// Sound is coming out, for the first time or again after a stall.
    case started
    /// Sound was coming out and has stopped while the player waits for data.
    case stalled
    case failed(PlaybackFailure)
}
