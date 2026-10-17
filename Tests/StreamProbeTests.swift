import Testing
@testable import SilverRainMini

/// SPEC FR-10: what «Проверить» says about the headers it got.
struct StreamProbeTests {
    @Test(arguments: [
        (String?("audio/aacp"), String?("96"), StreamProbe.Outcome.stream("AAC · 96 kbps")),
        ("audio/aac", "96, 96", .stream("AAC · 96 kbps")),
        ("audio/mpeg", "128", .stream("MP3 · 128 kbps")),
        ("application/ogg", nil, .stream("Ogg")),
        ("audio/flac", "1000", .stream("FLAC · 1000 kbps")),
        ("text/html; charset=utf-8", nil, .failure("Это не аудиопоток")),
        (nil, nil, .failure("Это не аудиопоток")),
    ])
    func describesTheHeaders(contentType: String?, bitrate: String?, expected: StreamProbe.Outcome) {
        #expect(StreamProbe.describe(contentType: contentType, bitrate: bitrate) == expected)
    }

    @Test func refusesPlainHTTPWithoutAsking() async {
        #expect(await StreamProbe().probe("http://example.com/live") == .failure("Нужен адрес https://"))
    }
}
