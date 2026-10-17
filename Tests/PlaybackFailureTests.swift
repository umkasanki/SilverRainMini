import AVFoundation
import Testing
@testable import SilverRainMini

/// The error chains are the ones `AVPlayer` produced on macOS 26.3 (17.10.2026).
struct PlaybackFailureTests {
    private static func error(_ domain: String, _ code: Int, underlying: NSError? = nil) -> NSError {
        NSError(domain: domain, code: code, userInfo: underlying.map { [NSUnderlyingErrorKey: $0] } ?? [:])
    }

    private static func osStatus(_ code: Int) -> NSError {
        error(NSOSStatusErrorDomain, code)
    }

    @Test(arguments: [
        (error(NSURLErrorDomain, -1100, underlying: osStatus(-12938)), PlaybackFailure.notFound),       // 404
        (error(NSURLErrorDomain, -1008, underlying: osStatus(-16849)), .unreachable),                   // 503
        (error(NSURLErrorDomain, -1013, underlying: osStatus(-16840)), .refused),                       // 401
        (error(NSURLErrorDomain, -1003, underlying: osStatus(-1003)), .unreachable),                    // no host
        (error(NSURLErrorDomain, -1004, underlying: osStatus(-1004)), .unreachable),                    // refused connection
        (error(NSURLErrorDomain, -1009), .unreachable),                                                 // offline
        (error(NSURLErrorDomain, -1022), .invalidAddress),                                              // plain http
        (error(AVFoundationErrorDomain, -11828, underlying: osStatus(-12847)), .unsupportedFormat),      // 403
        (error(AVFoundationErrorDomain, -11850, underlying: osStatus(-12939)), .unsupportedFormat),      // HTML page
    ])
    func classifiesObservedErrors(error: NSError, expected: PlaybackFailure) {
        #expect(PlaybackFailure(error) == expected)
    }

    @Test func findsTheURLErrorDeepInTheChain() {
        let error = Self.error(AVFoundationErrorDomain, -11800, underlying: Self.error(NSURLErrorDomain, -1100))
        #expect(PlaybackFailure(error) == .notFound)
    }

    @Test func onlyNetworkTroubleIsRecoverable() {
        #expect(PlaybackFailure.unreachable.isRecoverable)
        #expect(PlaybackFailure.connectTimeout.isRecoverable)
        #expect(!PlaybackFailure.notFound.isRecoverable)
        #expect(!PlaybackFailure.refused.isRecoverable)
        #expect(!PlaybackFailure.invalidAddress.isRecoverable)
        #expect(!PlaybackFailure.unsupportedFormat.isRecoverable)
    }
}
