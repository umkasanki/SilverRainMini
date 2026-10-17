import Foundation

/// What `RadioPlayer` needs from whatever actually makes the sound.
/// The protocol lets the state machine be tested without a network.
@MainActor
protocol PlaybackEngine: AnyObject {
    /// Reports what happened to the stream started last.
    var onEvent: ((PlaybackEngineEvent) -> Void)? { get set }

    /// Drops whatever was playing and starts `url` from the live edge.
    func start(url: URL)

    /// Drops whatever was playing. No events follow.
    func stop()
}

enum PlaybackEngineEvent: Equatable, Sendable {
    /// Sound is coming out.
    case started
    case failed(PlaybackFailure)
}
