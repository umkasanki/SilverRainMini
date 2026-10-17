import Foundation
import Testing
@testable import SilverRainMini

/// SPEC FR-5: retries on a schedule, the network shortcut, stalls and the emergency path.
@MainActor
struct RadioPlayerReconnectTests {
    private let url = URL(string: "https://example.com/live.aac")!
    private let fallbackURL = URL(string: "https://example.org/spare.mp3")!
    private let engine = FakePlaybackEngine()
    private let clock = ManualClock()

    private func makePlayer() -> RadioPlayer {
        RadioPlayer(engine: engine, sleep: clock.sleep)
    }

    private func playing(_ player: RadioPlayer, fallback: RadioPlayer.Fallback? = nil) -> RadioPlayer {
        player.play(url, fallback: fallback)
        engine.send(.started)
        return player
    }

    /// Fails once and lets the player schedule its retry.
    private func failAndWait(_ player: RadioPlayer, _ failure: PlaybackFailure = .unreachable) async {
        let sleepsBefore = clock.requested.count
        engine.send(.failed(failure))
        await settle { clock.requested.count > sleepsBefore || !player.state.isActive }
    }

    /// Every wait except the connect timeout. None of these tests stalls, so a
    /// 10-second wait here is the third retry delay, not the stall timeout.
    private var retryDelays: [Duration] {
        clock.requested.filter { $0 != .seconds(15) }
    }

    // MARK: - Schedule

    @Test func retriesAfterTheScheduledDelay() async {
        let player = playing(makePlayer())
        await failAndWait(player)
        #expect(engine.startedURLs.count == 1)
        clock.fire(.seconds(2))
        await settle { engine.startedURLs.count == 2 }
        #expect(engine.startedURLs == [url, url])
        #expect(player.state == .reconnecting(attempt: 1))
        engine.send(.started)
        #expect(player.state == .playing)
    }

    @Test func delaysGrowThenStayAtThirtySeconds() async {
        let player = makePlayer()
        player.play(url)
        player.isNetworkAvailable = false // keeps the emergency path out of the way
        for delay in [2, 5, 10, 30, 30] {
            await failAndWait(player)
            clock.fire(.seconds(delay))
            await settle { clock.pending == [.seconds(15)] }
        }
        #expect(retryDelays == [2, 5, 10, 30, 30].map { .seconds($0) })
        #expect(player.state == .reconnecting(attempt: 5))
    }

    @Test func scheduleStartsOverAfterSound() async {
        let player = playing(makePlayer())
        await failAndWait(player)
        clock.fire(.seconds(2))
        await settle { engine.startedURLs.count == 2 }
        engine.send(.started)
        await failAndWait(player)
        #expect(retryDelays == [.seconds(2), .seconds(2)])
        #expect(player.state == .reconnecting(attempt: 1))
    }

    @Test func stopCancelsThePendingRetry() async {
        let player = playing(makePlayer())
        await failAndWait(player)
        player.stop()
        clock.fire(.seconds(2))
        await settle()
        #expect(engine.startedURLs.count == 1)
        #expect(player.state == .idle)
    }

    // MARK: - Network

    @Test func networkReturnRetriesAtOnce() async {
        let player = playing(makePlayer())
        player.isNetworkAvailable = false
        await failAndWait(player)
        player.isNetworkAvailable = true
        #expect(engine.startedURLs.count == 2)
    }

    @Test func networkReturnWhilePlayingChangesNothing() {
        let player = playing(makePlayer())
        player.isNetworkAvailable = false
        player.isNetworkAvailable = true
        #expect(engine.startedURLs.count == 1)
        #expect(player.state == .playing)
    }

    // MARK: - Stalls

    @Test func longStallIsARecoverableFailure() async {
        let player = playing(makePlayer())
        engine.send(.stalled)
        await settle { clock.pending.contains(.seconds(10)) }
        clock.fire(.seconds(10))
        await settle { player.state != .playing }
        #expect(player.state == .reconnecting(attempt: 1))
    }

    @Test func soundBackInTimeEndsTheStall() async {
        let player = playing(makePlayer())
        engine.send(.stalled)
        await settle { clock.pending.contains(.seconds(10)) }
        engine.send(.started)
        await settle { !clock.pending.contains(.seconds(10)) }
        clock.fire(.seconds(10))
        await settle()
        #expect(player.state == .playing)
    }

    // MARK: - Emergency path

    private var fallback: RadioPlayer.Fallback {
        let url = fallbackURL
        return { url }
    }

    @Test func threeFailuresInARowTakeTheEmergencyPath() async {
        let player = playing(makePlayer(), fallback: fallback)
        await failAndWait(player)
        clock.fire(.seconds(2))
        await settle { engine.startedURLs.count == 2 }
        await failAndWait(player)
        clock.fire(.seconds(5))
        await settle { engine.startedURLs.count == 3 }
        #expect(engine.startedURLs.allSatisfy { $0 == url })

        engine.send(.failed(.unreachable))
        await settle { engine.startedURLs.count == 4 }
        #expect(engine.startedURLs.last == fallbackURL)
        engine.send(.started)
        #expect(player.state == .playing)
        #expect(player.isOnFallback)
    }

    @Test func deadAddressTakesTheEmergencyPathAtOnce() async {
        let player = makePlayer()
        player.play(url, fallback: fallback)
        engine.send(.failed(.notFound))
        await settle { engine.startedURLs.count == 2 }
        #expect(engine.startedURLs.last == fallbackURL)
        #expect(player.state == .reconnecting(attempt: 1))
    }

    @Test func noEmergencyPathWhileTheNetworkIsDown() async {
        let player = playing(makePlayer(), fallback: fallback)
        player.isNetworkAvailable = false
        for delay in [2, 5, 10] {
            await failAndWait(player)
            clock.fire(.seconds(delay))
            await settle { clock.pending == [.seconds(15)] }
        }
        #expect(!engine.startedURLs.contains(fallbackURL))
    }

    @Test func nextCycleTriesTheChosenStreamFirst() async {
        let player = makePlayer()
        player.play(url, fallback: fallback)
        engine.send(.failed(.notFound))
        await settle { engine.startedURLs.count == 2 }
        engine.send(.started)
        await failAndWait(player)
        clock.fire(.seconds(2))
        await settle { engine.startedURLs.count == 3 }
        #expect(engine.startedURLs.last == url)
        #expect(!player.isOnFallback)
    }

    @Test func unavailableEmergencyPathEndsInTheOriginalError() async {
        let player = makePlayer()
        player.play(url, fallback: { throw PlaylistResolver.Failure.noStreamInPlaylist })
        engine.send(.failed(.notFound))
        await settle { player.state == .error(.notFound) }
        #expect(player.state == .error(.notFound))
    }

    @Test func emergencyPathFailingForGoodIsAnError() async {
        let player = makePlayer()
        player.play(url, fallback: fallback)
        engine.send(.failed(.notFound))
        await settle { engine.startedURLs.count == 2 }
        engine.send(.failed(.notFound))
        #expect(player.state == .error(.notFound))
    }

    @Test func playAfterStopStartsWithTheChosenStream() async {
        let player = makePlayer()
        player.play(url, fallback: fallback)
        engine.send(.failed(.notFound))
        await settle { engine.startedURLs.count == 2 }
        player.stop()
        player.play(url, fallback: fallback)
        #expect(engine.startedURLs.last == url)
        #expect(!player.isOnFallback)
    }
}
