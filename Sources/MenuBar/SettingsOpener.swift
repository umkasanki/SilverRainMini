import AppKit
import SwiftUI
import os

/// Opens the `Settings` scene from AppKit code.
///
/// `OpenSettingsAction` exists only inside a SwiftUI environment, and the old
/// `showSettingsWindow:` selector no longer works, so an off-screen hosting view
/// keeps the action at hand.
@MainActor
final class SettingsOpener {
    /// Filled in by the hidden view once SwiftUI hands it the action.
    private final class ActionBox {
        var action: OpenSettingsAction?
    }

    private let box: ActionBox
    private let hostingView: NSHostingView<SettingsActionReader>

    init() {
        let box = ActionBox()
        self.box = box
        hostingView = NSHostingView(rootView: SettingsActionReader { box.action = $0 })
        hostingView.layoutSubtreeIfNeeded()
    }

    func open() {
        guard let action = box.action else {
            Logger.app.error("Settings action is not available")
            return
        }
        // `NSApp.activate()`, which Apple recommends, leaves a menu bar app inactive
        // even after a click on its own menu (measured 17.10.2026, macOS 26.3): the
        // window opens behind the others and typing goes elsewhere. The older call,
        // marked "to be deprecated", still activates. Recorded in the PLAN decision log.
        NSApp.activate(ignoringOtherApps: true)
        action()
        Task { @MainActor in
            await Task.yield()
            guard let window = settingsWindow else { return }
            window.orderFrontRegardless()
            window.makeKey()
            Logger.app.notice("Settings opened; app active: \(NSApp.isActive), window key: \(window.isKeyWindow)")
        }
    }

    /// The only titled window this app has.
    private var settingsWindow: NSWindow? {
        NSApp.windows.first { $0.isVisible && $0.styleMask.contains(.titled) }
    }
}

struct SettingsActionReader: View {
    @Environment(\.openSettings) private var openSettings
    let onRead: (OpenSettingsAction) -> Void

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .onAppear { onRead(openSettings) }
    }
}
