import AppKit
import SwiftUI

/// A borderless, transparent panel that drops down from the menu bar icon.
/// It draws nothing itself: the glass comes from the SwiftUI content.
final class PanelWindow: NSPanel {
    /// Called on Esc.
    var onCancel: (() -> Void)?

    /// Gap between the menu bar and the panel, as under Control Centre.
    private static let gap: CGFloat = 6
    /// Keeps the panel off the very edge of the screen.
    private static let screenInset: CGFloat = 8

    init<Content: View>(rootView: Content) {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        isFloatingPanel = true
        level = .popUpMenu
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        isMovable = false
        animationBehavior = .utilityWindow
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        contentView = NSHostingView(rootView: rootView)
    }

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    /// Places the panel under `button`, centred on it and kept inside the screen.
    func show(below button: NSStatusBarButton) {
        guard let buttonWindow = button.window, let contentView else { return }
        let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let visibleFrame = (buttonWindow.screen ?? NSScreen.main)?.visibleFrame ?? .zero
        let size = contentView.fittingSize

        let minX = visibleFrame.minX + Self.screenInset
        let maxX = visibleFrame.maxX - Self.screenInset - size.width
        let x = min(max(buttonFrame.midX - size.width / 2, minX), maxX)
        let y = buttonFrame.minY - Self.gap - size.height

        setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        makeKeyAndOrderFront(nil)
    }
}
