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

    @Test func thePulseCarriesOnAcrossReconnectAttempts() {
        let button = NSStatusBarButton(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
        MenuBarIcon.apply(.connecting, to: button)
        let pulse = button.layer?.animation(forKey: "pulse")
        #expect(pulse != nil)
        MenuBarIcon.apply(.reconnecting(attempt: 1), to: button)
        MenuBarIcon.apply(.reconnecting(attempt: 2), to: button)
        #expect(button.layer?.animation(forKey: "pulse") === pulse)
        MenuBarIcon.apply(.playing, to: button)
        #expect(button.layer?.animation(forKey: "pulse") == nil)
    }

    @Test func theLogoForThePanelIsInTheBundle() {
        #expect(NSImage(named: "StationLogo") != nil)
    }
}
