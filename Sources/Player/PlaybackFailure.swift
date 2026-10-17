import AVFoundation

/// Why playback stopped without being asked to (SPEC FR-5).
enum PlaybackFailure: Error, Equatable, Sendable {
    /// No network, no host, refused or dropped connection, server error 5xx.
    case unreachable
    /// No sound within the connect timeout.
    case connectTimeout
    /// The address is malformed or not HTTPS.
    case invalidAddress
    /// HTTP 404.
    case notFound
    /// HTTP 401 and other refusals that retrying will not change.
    case refused
    /// The server answered, but not with audio that `AVPlayer` can play.
    case unsupportedFormat

    /// Whether trying again later may help.
    var isRecoverable: Bool {
        switch self {
        case .unreachable, .connectTimeout: true
        case .invalidAddress, .notFound, .refused, .unsupportedFormat: false
        }
    }
}

extension PlaybackFailure {
    /// Classifies an `AVPlayer` error by the first URL error in its chain.
    ///
    /// Observed on macOS 26.3, 17.10.2026: 404 → `NSURLErrorFileDoesNotExist`,
    /// 5xx → `NSURLErrorResourceUnavailable`, 401 → `NSURLErrorUserAuthenticationRequired`,
    /// no host → `NSURLErrorCannotFindHost`, refused → `NSURLErrorCannotConnectToHost`.
    /// An HTML page or a 403 arrives as an AVFoundation error with no URL error inside.
    init(_ error: any Error) {
        let chain = sequence(first: error as NSError) { $0.userInfo[NSUnderlyingErrorKey] as? NSError }
        guard let urlError = chain.first(where: { $0.domain == NSURLErrorDomain }) else {
            self = .unsupportedFormat
            return
        }
        switch urlError.code {
        case NSURLErrorFileDoesNotExist:
            self = .notFound
        case NSURLErrorBadURL, NSURLErrorUnsupportedURL, NSURLErrorAppTransportSecurityRequiresSecureConnection:
            self = .invalidAddress
        case NSURLErrorUserAuthenticationRequired, NSURLErrorNoPermissionsToReadFile:
            self = .refused
        default:
            self = .unreachable
        }
    }
}
