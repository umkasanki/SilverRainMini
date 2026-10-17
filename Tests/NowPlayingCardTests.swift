import Testing
@testable import SilverRainMini

/// SPEC FR-7: the line under the station's name.
@MainActor
struct NowPlayingCardTests {
    @Test(arguments: [
        (PlaybackState.idle, false, "Остановлено"),
        (.connecting, false, "Подключение…"),
        (.playing, false, "В эфире · AAC 96"),
        (.playing, true, "В эфире · запасной поток"),
        (.reconnecting(attempt: 3), false, "Переподключение…"),
        (.error(.notFound), false, "Не удалось подключиться"),
    ])
    func subtitle(state: PlaybackState, isOnFallback: Bool, expected: String) {
        #expect(NowPlayingCard.subtitle(for: state, isOnFallback: isOnFallback, streamTitle: "AAC 96") == expected)
    }
}
