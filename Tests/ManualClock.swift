@testable import SilverRainMini

/// Hands out sleeps that end only when a test says the time has come,
/// so timeouts and retry delays are tested without waiting.
@MainActor
final class ManualClock {
    private struct Sleeper {
        let id: Int
        let duration: Duration
        let continuation: CheckedContinuation<Void, any Error>
    }

    private var sleepers: [Sleeper] = []
    private var nextID = 0

    /// Every duration asked for, in order, including cancelled ones.
    private(set) var requested: [Duration] = []

    /// Durations still being waited for.
    var pending: [Duration] { sleepers.map(\.duration) }

    nonisolated var sleep: RadioPlayer.Sleep {
        { [self] duration in try await self.sleep(for: duration) }
    }

    /// Ends every sleep of exactly `duration`.
    func fire(_ duration: Duration) {
        let due = sleepers.filter { $0.duration == duration }
        sleepers.removeAll { $0.duration == duration }
        due.forEach { $0.continuation.resume() }
    }

    private func sleep(for duration: Duration) async throws {
        requested.append(duration)
        let id = nextID
        nextID += 1
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else {
                    sleepers.append(Sleeper(id: id, duration: duration, continuation: continuation))
                }
            }
        } onCancel: {
            Task { @MainActor in self.cancel(id) }
        }
    }

    private func cancel(_ id: Int) {
        guard let index = sleepers.firstIndex(where: { $0.id == id }) else { return }
        sleepers.remove(at: index).continuation.resume(throwing: CancellationError())
    }
}

/// Lets pending tasks run until `condition` holds or they have had plenty of turns.
@MainActor
func settle(until condition: () -> Bool = { false }) async {
    for _ in 0..<100 where !condition() {
        await Task.yield()
    }
}
