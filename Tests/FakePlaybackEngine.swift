import Foundation
@testable import SilverRainMini

/// Records what the player asked for and plays back whatever events a test sends.
@MainActor
final class FakePlaybackEngine: PlaybackEngine {
    var onEvent: ((PlaybackEngineEvent) -> Void)?
    private(set) var startedURLs: [URL] = []
    private(set) var stopCount = 0

    func start(url: URL) {
        startedURLs.append(url)
    }

    func stop() {
        stopCount += 1
    }

    func send(_ event: PlaybackEngineEvent) {
        onEvent?(event)
    }
}
