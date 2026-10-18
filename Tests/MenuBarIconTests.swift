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

    // «Уменьшить движение» is given, not read: GitHub's macOS runners have it on.
    @Test func thePulseCarriesOnAcrossReconnectAttempts() {
        let button = NSStatusBarButton(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
        MenuBarIcon.apply(.connecting, to: button, reduceMotion: false)
        let pulse = button.layer?.animation(forKey: "pulse")
        #expect(pulse != nil)
        MenuBarIcon.apply(.reconnecting(attempt: 1), to: button, reduceMotion: false)
        MenuBarIcon.apply(.reconnecting(attempt: 2), to: button, reduceMotion: false)
        #expect(button.layer?.animation(forKey: "pulse") === pulse)
        MenuBarIcon.apply(.playing, to: button, reduceMotion: false)
        #expect(button.layer?.animation(forKey: "pulse") == nil)
    }

    @Test func withReducedMotionTheCloudDimsInsteadOfPulsing() {
        let button = NSStatusBarButton(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
        MenuBarIcon.apply(.connecting, to: button, reduceMotion: true)
        #expect(button.layer?.animation(forKey: "pulse") == nil)
        #expect(button.alphaValue == 0.5)
        MenuBarIcon.apply(.reconnecting(attempt: 1), to: button, reduceMotion: true)
        #expect(button.alphaValue == 0.5)
        MenuBarIcon.apply(.playing, to: button, reduceMotion: true)
        #expect(button.alphaValue == 1)
    }

    @Test func theLogoForThePanelIsInTheBundle() {
        #expect(NSImage(named: "StationLogo") != nil)
    }
}
