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

    /// The screen y of the panel's top edge while shown. When the content grows
    /// or shrinks, the panel changes height downwards and stays under the menu bar.
    private var anchoredTop: CGFloat?

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
        let controller = NSHostingController(rootView: rootView)
        controller.sizingOptions = [.preferredContentSize]
        contentViewController = controller
    }

    override var canBecomeKey: Bool { true }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        var frame = frameRect
        if let anchoredTop {
            frame.origin.y = anchoredTop - frame.height
        }
        super.setFrame(frame, display: flag)
    }

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
        anchoredTop = buttonFrame.minY - Self.gap

        setFrame(NSRect(x: x, y: 0, width: size.width, height: size.height), display: true)
        makeKeyAndOrderFront(nil)
    }
}
