import Foundation

/// The emergency path (PLAN 3): the station's own playlist lives on silver.ru,
/// a host apart from the broadcast servers, and points at a working stream.
struct PlaylistResolver: Sendable {
    enum Failure: Error {
        case noStreamInPlaylist
    }

    static let stationPlaylist = URL(string: "https://silver.ru/radio/48.m3u")!

    /// Downloads a playlist; tests replace it.
    var fetch: @Sendable (URLRequest) async throws -> Data = { request in
        try await URLSession.shared.data(for: request).0
    }

    /// Asks the station every time: a cached copy would defeat the point of
    /// following the playlist when the station moves its stream.
    static let request = URLRequest(
        url: stationPlaylist,
        cachePolicy: .reloadIgnoringLocalCacheData,
        timeoutInterval: 10
    )

    /// The stream the station's playlist points at today.
    func resolve() async throws -> URL {
        let data = try await fetch(Self.request)
        guard let url = Self.streamURL(inPlaylist: String(decoding: data, as: UTF8.self)) else {
            throw Failure.noStreamInPlaylist
        }
        return url
    }

    /// The first web address in an M3U playlist, moved to HTTPS.
    ///
    /// The playlist says `http://`; the app plays HTTPS only, and the station
    /// serves the same stream there (checked 17.10.2026).
    static func streamURL(inPlaylist text: String) -> URL? {
        let blank = CharacterSet.whitespaces.union(CharacterSet(charactersIn: "\u{FEFF}"))
        return text
            .split(whereSeparator: \.isNewline)
            .lazy
            .map { $0.trimmingCharacters(in: blank) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            .compactMap(httpsURL)
            .first
    }

    private static func httpsURL(_ line: String) -> URL? {
        guard var components = URLComponents(string: line),
              let scheme = components.scheme?.lowercased(), scheme == "http" || scheme == "https",
              components.host?.isEmpty == false
        else { return nil }
        components.scheme = "https"
        return components.url
    }
}
