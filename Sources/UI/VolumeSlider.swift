import AppKit
import SwiftUI

/// The volume control (SPEC FR-8): a thick capsule the full width of its card,
/// with the speaker inside on the left. A deliberate departure from Control
/// Centre's thin track: a 28-point target is three times easier to hit when the
/// app is driven by head movement (PLAN 6.2). Do not "fix" it back without a talk.
struct VolumeSlider: View {
    let volume: Double
    let isMuted: Bool
    let setVolume: (Double) -> Void
    let toggleMute: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var scrollMonitor = ScrollWheelMonitor()

    static let height: CGFloat = 28
    /// Clicks this close to the left edge land on the speaker: mute, not volume.
    private static let speakerZone: CGFloat = 30
    /// What one arrow key press changes.
    private static let keyboardStep = 0.05

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                Rectangle().fill(trackColor)
                Rectangle()
                    .fill(fillColor.opacity(isMuted ? 0.45 : 1))
                    .frame(width: width * volume)
                Image(systemName: speakerSymbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(glyphColor(onFill: width * volume > Self.speakerZone * 0.6))
                    .frame(width: Self.speakerZone, height: Self.height)
            }
            .clipShape(.capsule)
            .contentShape(.capsule)
            .gesture(drag(width: width))
            .onAppear {
                scrollMonitor.onScroll = { points in setVolume(volume + points / width) }
            }
            .onChange(of: volume) {
                scrollMonitor.onScroll = { points in setVolume(volume + points / width) }
            }
        }
        .frame(height: Self.height)
        .onContinuousHover { phase in
            if case .active = phase { scrollMonitor.start() } else { scrollMonitor.stop() }
        }
        .onDisappear { scrollMonitor.stop() }
        .focusable()
        // The slider takes focus as soon as the panel opens, and the system ring
        // around it looked like a stray outline (17.10.2026). Arrows still work.
        .focusEffectDisabled()
        .onKeyPress(keys: [.leftArrow, .downArrow]) { _ in
            setVolume(volume - Self.keyboardStep)
            return .handled
        }
        .onKeyPress(keys: [.rightArrow, .upArrow]) { _ in
            setVolume(volume + Self.keyboardStep)
            return .handled
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Громкость")
        .accessibilityValue(isMuted ? "Без звука" : "\(Int((volume * 100).rounded())) %")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: setVolume(volume + Self.keyboardStep)
            case .decrement: setVolume(volume - Self.keyboardStep)
            @unknown default: break
            }
        }
        .accessibilityAction(named: isMuted ? "Включить звук" : "Без звука", toggleMute)
    }

    /// A press and release on the speaker toggles mute; anything else sets the
    /// volume where the pointer is, whether clicked once or dragged.
    private func drag(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { drag in
                guard !isSpeakerClick(drag) else { return }
                setVolume(drag.location.x / width)
            }
            .onEnded { drag in
                if isSpeakerClick(drag) { toggleMute() }
            }
    }

    private func isSpeakerClick(_ drag: DragGesture.Value) -> Bool {
        drag.startLocation.x < Self.speakerZone && abs(drag.translation.width) < 3
    }

    private var speakerSymbol: String {
        if isMuted { return "speaker.slash.fill" }
        switch volume {
        case ..<0.01: return "speaker.fill"
        case ..<0.34: return "speaker.wave.1.fill"
        case ..<0.67: return "speaker.wave.2.fill"
        default: return "speaker.wave.3.fill"
        }
    }

    // The mockup's tones for the track; the cards themselves stay system glass.
    private var isDark: Bool { colorScheme == .dark }
    private var trackColor: Color {
        isDark ? .white.opacity(0.16) : Color(red: 120 / 255, green: 140 / 255, blue: 160 / 255).opacity(0.26)
    }
    private var fillColor: Color { .white.opacity(isDark ? 0.92 : 0.95) }
    private static let darkGlyph = Color(red: 0x2A / 255, green: 0x35 / 255, blue: 0x40 / 255)
    private static let lightGlyph = Color(red: 0xE7 / 255, green: 0xEB / 255, blue: 0xF0 / 255)

    /// The speaker must stand out from whatever is under it: dark on the white
    /// fill, and on the bare track whatever suits the theme. In the mockup it was
    /// light on the fill in dark mode and all but vanished (seen on screen, 17.10.2026).
    private func glyphColor(onFill: Bool) -> Color {
        onFill || !isDark ? Self.darkGlyph : Self.lightGlyph
    }
}

/// Feeds scroll-wheel and trackpad movement to the slider while the pointer is over it.
@MainActor
final class ScrollWheelMonitor {
    /// Points of movement: positive is louder (up or right).
    var onScroll: ((CGFloat) -> Void)?
    private var monitor: Any?

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            let horizontal = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)
            var points = horizontal ? -event.scrollingDeltaX : event.scrollingDeltaY
            // Follow the finger, not the content: with natural scrolling the deltas are flipped.
            if event.isDirectionInvertedFromDevice { points = -points }
            if !event.hasPreciseScrollingDeltas { points *= 8 }
            let handled = MainActor.assumeIsolated { () -> Bool in
                guard let onScroll = self?.onScroll else { return false }
                onScroll(points)
                return true
            }
            return handled ? nil : event
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }
}
