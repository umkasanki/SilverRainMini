import AppKit
import QuartzCore

/// The menu bar icon in its four looks (SPEC FR-2): a filled cloud, neutral at
/// rest, pulsing while connecting, coral with a white outline on air, with a small
/// exclamation mark after an error.
@MainActor
enum MenuBarIcon {
    /// The cloud plus room for the on-air outline; every look shares it, so the
    /// item never changes width.
    static var size: NSSize {
        NSSize(width: cloud.size.width + 2 * margin, height: cloud.size.height + 2 * margin)
    }

    /// 10 % above the default 13 pt: next to the other icons the cloud looked small.
    private static let pointSize: CGFloat = 14.3
    /// A lighter, coral take on the station's #FF3600: in the menu bar the full
    /// brand red looked too heavy (chosen side by side, 17.10.2026).
    private static let onAirColor = NSColor(srgbRed: 1, green: 0x6A / 255, blue: 0x3D / 255, alpha: 1)
    /// Sets the coral apart from a dark menu bar (chosen side by side, 17.10.2026).
    private static let outlineWidth: CGFloat = 1
    /// Room around the cloud for the outline and its soft edge.
    private static let margin: CGFloat = 1.5
    private static let pulseKey = "pulse"

    /// Applies the look for `state` to the status item's button.
    static func apply(_ state: PlaybackState, to button: NSStatusBarButton) {
        button.image = image(for: state)
        button.setAccessibilityValue(accessibilityValue(for: state))
        pulse(button, while: state)
    }

    static func image(for state: PlaybackState) -> NSImage {
        switch state {
        case .playing: onAirImage()
        case .error: errorImage()
        case .idle, .connecting, .reconnecting: restingImage()
        }
    }

    // MARK: - Images

    private static let cloud: NSImage =
        NSImage(systemSymbolName: "cloud.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular))
            ?? NSImage()

    private static var cloudRect: NSRect {
        NSRect(origin: NSPoint(x: margin, y: margin), size: cloud.size)
    }

    /// The cloud in one colour, for layering.
    private static func cloud(in color: NSColor) -> NSImage {
        let cloud = cloud
        return NSImage(size: cloud.size, flipped: false) { rect in
            cloud.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
    }

    /// A template: the system colours it for the menu bar's own appearance.
    private static func restingImage() -> NSImage {
        let cloud = cloud
        let image = NSImage(size: size, flipped: false) { _ in
            cloud.draw(in: cloudRect)
            return true
        }
        image.isTemplate = true
        return image
    }

    /// Not a template: the coral and the white outline are the point of this look.
    /// The outline is the cloud in white, nudged out in sixteen directions underneath.
    private static func onAirImage() -> NSImage {
        let white = cloud(in: .white)
        let coral = cloud(in: onAirColor)
        return NSImage(size: size, flipped: false) { _ in
            for step in 0..<16 {
                let angle = Double(step) * .pi / 8
                white.draw(in: cloudRect.offsetBy(dx: outlineWidth * cos(angle), dy: outlineWidth * sin(angle)))
            }
            coral.draw(in: cloudRect)
            return true
        }
    }

    /// A template too: the cloud with a small badge cut into its lower right corner.
    private static func errorImage() -> NSImage {
        let cloud = cloud
        let badgeSide: CGFloat = 9
        let badgeRect = NSRect(x: cloudRect.maxX - badgeSide, y: cloudRect.minY, width: badgeSide, height: badgeSide)
        let badge = NSImage(systemSymbolName: "exclamationmark.circle.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: badgeSide, weight: .bold))
        let image = NSImage(size: size, flipped: false) { _ in
            cloud.draw(in: cloudRect)
            // A clear ring keeps the badge readable against the cloud.
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            NSBezierPath(ovalIn: badgeRect.insetBy(dx: -1.5, dy: -1.5)).fill()
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            badge?.draw(in: badgeRect)
            return true
        }
        image.isTemplate = true
        return image
    }

    // MARK: - Pulse and accessibility

    /// A soft opacity pulse while connecting; a steady half tone with Reduce Motion.
    /// A pulse already running carries on, so each new reconnect attempt does not
    /// snap it back to full opacity.
    private static func pulse(_ button: NSStatusBarButton, while state: PlaybackState) {
        button.wantsLayer = true
        let shouldPulse = state == .connecting || state.reconnectAttempt > 0
        if shouldPulse, button.layer?.animation(forKey: pulseKey) != nil {
            return
        }
        button.layer?.removeAnimation(forKey: pulseKey)
        button.alphaValue = 1
        guard shouldPulse else { return }
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            button.alphaValue = 0.5
            return
        }
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1
        animation.toValue = 0.35
        animation.duration = 0.8
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        button.layer?.add(animation, forKey: pulseKey)
    }

    private static func accessibilityValue(for state: PlaybackState) -> String {
        switch state {
        case .idle: "Остановлено"
        case .connecting: "Подключение"
        case .playing: "В эфире"
        case .reconnecting: "Переподключение"
        case .error: "Не удалось подключиться"
        }
    }
}
