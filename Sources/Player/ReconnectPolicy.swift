/// How long to wait before each reconnection attempt (SPEC FR-5):
/// 2, 5 and 10 seconds, then every 30 seconds, without limit.
struct ReconnectPolicy: Sendable {
    let delays: [Duration]

    init(delays: [Duration] = [.seconds(2), .seconds(5), .seconds(10), .seconds(30)]) {
        precondition(!delays.isEmpty, "A reconnect policy needs at least one delay")
        self.delays = delays
    }

    /// The wait before attempt number `attempt`, counting from 1.
    /// Attempts past the end of `delays` keep the last delay.
    func delay(beforeAttempt attempt: Int) -> Duration {
        delays[min(max(attempt, 1), delays.count) - 1]
    }
}
