import Testing
@testable import SilverRainMini

struct ReconnectPolicyTests {
    @Test(arguments: [(1, 2), (2, 5), (3, 10), (4, 30), (5, 30), (100, 30)])
    func delays(attempt: Int, seconds: Int) {
        #expect(ReconnectPolicy().delay(beforeAttempt: attempt) == .seconds(seconds))
    }

    @Test func attemptsBelowOneWaitTheFirstDelay() {
        #expect(ReconnectPolicy().delay(beforeAttempt: 0) == .seconds(2))
    }
}
