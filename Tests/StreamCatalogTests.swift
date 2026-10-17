import Foundation
import Testing
@testable import SilverRainMini

/// SPEC FR-9: the catalog that ships, and the user's own address.
struct StreamCatalogTests {
    private func catalog(_ json: String) throws -> StreamCatalog {
        try StreamCatalog(data: Data(json.utf8))
    }

    @Test func theBundledCatalogIsSound() throws {
        let url = try #require(Bundle.main.url(forResource: "streams", withExtension: "json"))
        let catalog = try StreamCatalog(data: Data(contentsOf: url))
        #expect(catalog.streams.map(\.id) == ["aac96", "mp3128", "aac48"])
        #expect(catalog.defaultStream.id == "aac96")
        #expect(catalog.defaultStream.url.absoluteString == "https://silverrain.hostingradio.ru/silver64.aac")
    }

    @Test func anUnknownIDFallsBackToTheDefault() {
        let catalog = StreamCatalog.bundled
        #expect(catalog.stream(id: "gone-since-1.0").id == "aac96")
        #expect(catalog.stream(id: "mp3128").shortTitle == "MP3 128")
    }

    @Test func stationStreamsMayUseTheEmergencyPath() {
        let playable = StreamCatalog.bundled.playable(streamID: "aac48", customAddress: "")
        #expect(playable.allowsFallback)
        #expect(playable.shortTitle == "AAC 48")
    }

    @Test func theUsersOwnAddressMayNot() {
        let playable = StreamCatalog.bundled.playable(streamID: StreamCatalog.customID, customAddress: "https://example.com/live")
        #expect(!playable.allowsFallback)
        #expect(playable.url?.absoluteString == "https://example.com/live")
        #expect(playable.shortTitle == "Свой адрес")
    }

    @Test(arguments: [
        ("", StreamCatalog.AddressProblem.empty),
        ("   ", .empty),
        ("http://example.com/live", .notHTTPS),
        ("ftp://example.com/live", .malformed),
        ("https://", .malformed),
    ])
    func unplayableAddresses(text: String, problem: StreamCatalog.AddressProblem) {
        #expect(StreamCatalog.customURL(from: text) == .failure(problem))
    }

    @Test(arguments: [
        ("https://example.com/live.aac", "https://example.com/live.aac"),
        ("  https://example.com/live.aac \n", "https://example.com/live.aac"),
        ("example.com/live.aac", "https://example.com/live.aac"),
    ])
    func playableAddresses(text: String, expected: String) {
        #expect((try? StreamCatalog.customURL(from: text).get())?.absoluteString == expected)
    }

    @Test func anUnplayableAddressHasNoURL() {
        let playable = StreamCatalog.bundled.playable(streamID: StreamCatalog.customID, customAddress: "http://x.example")
        #expect(playable.url == nil)
    }

    @Test func brokenCatalogsAreRefused() {
        #expect(throws: (any Error).self) { try catalog("not json") }
        #expect(throws: StreamCatalog.Failure.empty) { try catalog("[]") }
        #expect(throws: StreamCatalog.Failure.notExactlyOneDefault) {
            try catalog(#"[{"id":"a","title":"A","shortTitle":"A","url":"https://a.example"}]"#)
        }
        #expect(throws: StreamCatalog.Failure.notExactlyOneDefault) {
            try catalog(#"[{"id":"a","title":"A","shortTitle":"A","url":"https://a.example","default":true},{"id":"b","title":"B","shortTitle":"B","url":"https://b.example","default":true}]"#)
        }
        #expect(throws: StreamCatalog.Failure.notHTTPS("a")) {
            try catalog(#"[{"id":"a","title":"A","shortTitle":"A","url":"http://a.example","default":true}]"#)
        }
        #expect(throws: StreamCatalog.Failure.duplicateID("a")) {
            try catalog(#"[{"id":"a","title":"A","shortTitle":"A","url":"https://a.example","default":true},{"id":"a","title":"B","shortTitle":"B","url":"https://b.example"}]"#)
        }
    }
}
