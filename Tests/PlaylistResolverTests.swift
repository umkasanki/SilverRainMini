import Foundation
import Testing
@testable import SilverRainMini

struct PlaylistResolverTests {
    private let stream = URL(string: "https://silverrain.hostingradio.ru/silver128.mp3")!

    @Test func todaysPlaylistMovesToHTTPS() {
        // What https://silver.ru/radio/48.m3u returned on 17.10.2026, byte for byte.
        #expect(PlaylistResolver.streamURL(inPlaylist: "http://silverrain.hostingradio.ru/silver128.mp3") == stream)
    }

    @Test func extendedPlaylistWithCommentsAndCRLF() {
        let text = "\u{FEFF}#EXTM3U\r\n#EXTINF:-1,Серебряный Дождь\r\n\r\n  http://silverrain.hostingradio.ru/silver128.mp3  \r\n"
        #expect(PlaylistResolver.streamURL(inPlaylist: text) == stream)
    }

    @Test(arguments: ["", "#EXTM3U\n#EXTINF:-1,nothing", "not an address", "ftp://example.com/a.mp3", "http://"])
    func noStream(text: String) {
        #expect(PlaylistResolver.streamURL(inPlaylist: text) == nil)
    }

    @Test func takesTheFirstStream() {
        let text = "garbage\nhttps://a.example/1.aac\nhttps://b.example/2.aac"
        #expect(PlaylistResolver.streamURL(inPlaylist: text) == URL(string: "https://a.example/1.aac"))
    }

    @Test func resolveReadsTheStationPlaylist() async throws {
        var resolver = PlaylistResolver()
        resolver.fetch = { request in
            #expect(request.url == PlaylistResolver.stationPlaylist)
            return Data("http://silverrain.hostingradio.ru/silver128.mp3\n".utf8)
        }
        #expect(try await resolver.resolve() == stream)
    }

    @Test func playlistIsNeverTakenFromTheCache() {
        #expect(PlaylistResolver.request.cachePolicy == .reloadIgnoringLocalCacheData)
    }

    @Test func resolveFailsOnAnEmptyPlaylist() async {
        var resolver = PlaylistResolver()
        resolver.fetch = { _ in Data() }
        await #expect(throws: PlaylistResolver.Failure.self) { try await resolver.resolve() }
    }
}
