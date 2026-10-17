import AppKit
import Testing
@testable import SilverRainMini

/// SPEC FR-2: only the on-air look carries its own colours; the rest let the menu bar tint them.
@MainActor
struct MenuBarIconTests {
    @Test(arguments: [PlaybackState.idle, .connecting, .reconnecting(attempt: 2), .error(.notFound)])
    func systemTintedLooks(state: PlaybackState) {
        #expect(MenuBarIcon.image(for: state).isTemplate)
    }

    @Test func onAirKeepsItsOrange() {
        #expect(!MenuBarIcon.image(for: .playing).isTemplate)
    }

    @Test(arguments: [PlaybackState.idle, .playing, .error(.notFound)])
    func everyLookIsTheSameSize(state: PlaybackState) {
        #expect(MenuBarIcon.image(for: state).size == MenuBarIcon.size)
    }

    @Test func theLogoForThePanelIsInTheBundle() {
        #expect(NSImage(named: "StationLogo") != nil)
    }
}
