import Foundation
import Testing
@testable import SilverRainMini

@MainActor
struct RadioPlayerStateTests {
    private let url = URL(string: "https://example.com/live.aac")!
    private let engine = FakePlaybackEngine()

    /// A player whose connect timeout never fires unless a test wants it to.
    private static let instantSleep: RadioPlayer.Sleep = { _ in }
    private static let endlessSleep: RadioPlayer.Sleep = { _ in try await Task.sleep(for: .seconds(3600)) }

    private func makePlayer(timeoutFiresAtOnce: Bool = false) -> RadioPlayer {
        RadioPlayer(engine: engine, sleep: timeoutFiresAtOnce ? Self.instantSleep : Self.endlessSleep)
    }

    private func playing(_ player: RadioPlayer) -> RadioPlayer {
        player.play(url)
        engine.send(.started)
        return player
    }

    // MARK: - Allowed transitions

    @Test func startsIdle() {
        #expect(makePlayer().state == .idle)
    }

    @Test func playConnectsAndStartsTheEngine() {
        let player = makePlayer()
        player.play(url)
        #expect(player.state == .connecting)
        #expect(engine.startedURLs == [url])
    }

    @Test func soundMakesItPlaying() {
        let player = playing(makePlayer())
        #expect(player.state == .playing)
    }

    @Test func recoverableFailureReconnectsAndCountsAttempts() {
        let player = playing(makePlayer())
        engine.send(.failed(.unreachable))
        #expect(player.state == .reconnecting(attempt: 1))
        engine.send(.failed(.unreachable))
        #expect(player.state == .reconnecting(attempt: 2))
        engine.send(.started)
        #expect(player.state == .playing)
    }

    @Test(arguments: [PlaybackFailure.notFound, .refused, .unsupportedFormat, .invalidAddress])
    func unrecoverableFailureIsAnError(failure: PlaybackFailure) {
        let player = makePlayer()
        player.play(url)
        engine.send(.failed(failure))
        #expect(player.state == .error(failure))
    }

    @Test func playAfterAnErrorConnectsAgain() {
        let player = makePlayer()
        player.play(url)
        engine.send(.failed(.notFound))
        player.play(url)
        #expect(player.state == .connecting)
        #expect(engine.startedURLs.count == 2)
    }

    @Test func stopFromAnyActiveStateIsIdle() {
        for prepare in [
            { (p: RadioPlayer) in p.play(self.url) },
            { p in p.play(self.url); self.engine.send(.started) },
            { p in p.play(self.url); self.engine.send(.failed(.unreachable)) },
        ] {
            let player = makePlayer()
            prepare(player)
            player.stop()
            #expect(player.state == .idle)
        }
    }

    @Test func failureStopsTheEngine() {
        let player = playing(makePlayer())
        let stopsBefore = engine.stopCount
        engine.send(.failed(.unreachable))
        #expect(player.state == .reconnecting(attempt: 1))
        #expect(engine.stopCount == stopsBefore + 1)
    }

    // MARK: - Ignored events

    @Test func lateEventsAfterStopAreIgnored() {
        let player = makePlayer()
        player.play(url)
        player.stop()
        engine.send(.started)
        engine.send(.failed(.unreachable))
        #expect(player.state == .idle)
    }

    @Test func playWhilePlayingIsIgnored() {
        let player = playing(makePlayer())
        player.play(url)
        #expect(player.state == .playing)
        #expect(engine.startedURLs.count == 1)
    }

    @Test func soundAfterAnErrorIsIgnored() {
        let player = makePlayer()
        player.play(url)
        engine.send(.failed(.notFound))
        engine.send(.started)
        #expect(player.state == .error(.notFound))
    }

    // MARK: - Connect timeout

    @Test func silenceTooLongIsARecoverableTimeout() async {
        let player = makePlayer(timeoutFiresAtOnce: true)
        player.play(url)
        await settle { player.state != .connecting }
        #expect(player.state == .reconnecting(attempt: 1))
    }

    @Test func soundInTimeCancelsTheTimeout() async {
        let player = makePlayer(timeoutFiresAtOnce: true)
        player.play(url)
        engine.send(.started)
        await settle { false }
        #expect(player.state == .playing)
    }

    /// Lets pending tasks run until `condition` holds or they have had plenty of turns.
    private func settle(until condition: () -> Bool) async {
        for _ in 0..<100 where !condition() {
            await Task.yield()
        }
    }
}
