/// The one source of truth for the player (SPEC FR-4). The interface and the
/// menu bar icon are drawn from this value and nothing else.
enum PlaybackState: Equatable, Sendable {
    case idle
    case connecting
    case playing
    case reconnecting(attempt: Int)
    case error(PlaybackFailure)
}

extension PlaybackState {
    /// The number of the reconnection attempt in progress, 0 when not reconnecting.
    var reconnectAttempt: Int {
        if case .reconnecting(let attempt) = self { attempt } else { 0 }
    }

    /// Whether the user has asked for sound and the player is trying to give it.
    var isActive: Bool {
        switch self {
        case .connecting, .playing, .reconnecting: true
        case .idle, .error: false
        }
    }
}
