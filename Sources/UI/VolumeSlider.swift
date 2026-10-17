import AppKit
import SwiftUI

/// The volume control (SPEC FR-8): a thick capsule the full width of its card,
/// with the speaker inside on the left. A deliberate departure from Control
/// Centre's thin track: a 28-point target is three times easier to hit when the
/// app is driven by head movement (PLAN 6.2). Do not "fix" it back without a talk.
///
/// The speaker owns the left end: a click there mutes. The volume scale starts
/// right of it, so every level from 0 to 100 % is still one click away (NFR-4).
struct VolumeSlider: View {
    let volume: Double
    let isMuted: Bool
    /// Sets an absolute level; `persist` is false while a drag is still moving.
    let setVolume: (_ volume: Double, _ persist: Bool) -> Void
    /// Moves the level relative to whatever it is now, for scrolling and keys.
    let adjustVolume: (Double) -> Void
    let toggleMute: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    static let height: CGFloat = 28
    /// The speaker's end of the capsule: a click here mutes.
    static let speakerZone: CGFloat = 30
    /// What one arrow key press changes.
    private static let keyboardStep = 0.05

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                Rectangle().fill(trackColor)
                Rectangle()
                    .fill(fillColor.opacity(isMuted ? 0.45 : 1))
                    .frame(width: Self.fillWidth(volume: volume, width: width))
                Image(systemName: speakerSymbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(glyphColor(onFill: volume > 0))
                    .frame(width: Self.speakerZone, height: Self.height)
            }
            .clipShape(.capsule)
            .contentShape(.capsule)
            .gesture(drag(width: width))
            .overlay {
                ScrollCatcher { points in adjustVolume(points / max(width - Self.speakerZone, 1)) }
            }
        }
        .frame(height: Self.height)
        .focusable()
        // The slider takes focus as soon as the panel opens, and the system ring
        // around it looked like a stray outline (17.10.2026). Arrows still work.
        .focusEffectDisabled()
        .onKeyPress(keys: [.leftArrow, .downArrow]) { _ in
            adjustVolume(-Self.keyboardStep)
            return .handled
        }
        .onKeyPress(keys: [.rightArrow, .upArrow]) { _ in
            adjustVolume(Self.keyboardStep)
            return .handled
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Громкость")
        .accessibilityValue(isMuted ? "Без звука" : "\(Int((volume * 100).rounded())) %")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: adjustVolume(Self.keyboardStep)
            case .decrement: adjustVolume(-Self.keyboardStep)
            @unknown default: break
            }
        }
        .accessibilityAction(named: isMuted ? "Включить звук" : "Без звука", toggleMute)
    }

    // MARK: - Geometry

    /// The level a pointer at `x` asks for: 0 at the speaker's edge, 1 at the far end.
    static func volume(atX x: CGFloat, width: CGFloat) -> Double {
        let scale = max(width - speakerZone, 1)
        return min(max(Double((x - speakerZone) / scale), 0), 1)
    }

    /// How far the fill reaches, so that its edge sits exactly where a click set it.
    /// At zero there is no fill at all.
    static func fillWidth(volume: Double, width: CGFloat) -> CGFloat {
        guard volume > 0 else { return 0 }
        return speakerZone + CGFloat(volume) * max(width - speakerZone, 0)
    }

    // MARK: - Pointer

    /// A press and release on the speaker toggles mute; anything else sets the
    /// volume where the pointer is, whether clicked once or dragged. The level is
    /// saved when the pointer lets go, not on every step of a drag.
    private func drag(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { drag in
                guard !isSpeakerClick(drag) else { return }
                setVolume(Self.volume(atX: drag.location.x, width: width), false)
            }
            .onEnded { drag in
                if isSpeakerClick(drag) {
                    toggleMute()
                } else {
                    setVolume(Self.volume(atX: drag.location.x, width: width), true)
                }
            }
    }

    private func isSpeakerClick(_ drag: DragGesture.Value) -> Bool {
        drag.startLocation.x < Self.speakerZone && abs(drag.translation.width) < 3
    }

    // MARK: - Look

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

/// Takes scroll-wheel and trackpad movement over the slider and nothing else.
///
/// The view claims hits only while a scroll event is being routed, so clicks and
/// drags go straight through to the slider. Being an ordinary view, it stops
/// receiving anything the moment its panel is hidden.
private struct ScrollCatcher: NSViewRepresentable {
    /// Points of movement: positive is louder (up or right).
    let onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> CatcherView {
        CatcherView()
    }

    func updateNSView(_ view: CatcherView, context: Context) {
        view.onScroll = onScroll
    }

    final class CatcherView: NSView {
        var onScroll: ((CGFloat) -> Void)?

        override func hitTest(_ point: NSPoint) -> NSView? {
            NSApp.currentEvent?.type == .scrollWheel ? super.hitTest(point) : nil
        }

        override func scrollWheel(with event: NSEvent) {
            let horizontal = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)
            var points = horizontal ? -event.scrollingDeltaX : event.scrollingDeltaY
            // Follow the finger, not the content: with natural scrolling the deltas are flipped.
            if event.isDirectionInvertedFromDevice { points = -points }
            if !event.hasPreciseScrollingDeltas { points *= 8 }
            onScroll?(points)
        }
    }
}
