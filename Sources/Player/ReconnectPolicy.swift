/// How long to wait before each reconnection attempt (SPEC FR-5):
/// 2, 5 and 10 seconds, then every 30 seconds, without limit.
struct ReconnectPolicy: Sendable {
    var delays: [Duration] = [.seconds(2), .seconds(5), .seconds(10), .seconds(30)]

    /// The wait before attempt number `attempt`, counting from 1.
    /// Attempts past the end of `delays` keep the last delay.
    func delay(beforeAttempt attempt: Int) -> Duration {
        delays[min(max(attempt, 1), delays.count) - 1]
    }
}
