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
    private var action: OpenSettingsAction?
    private let hostingView: NSHostingView<SettingsActionReader>

    init() {
        hostingView = NSHostingView(rootView: SettingsActionReader(onRead: { _ in }))
        hostingView.rootView = SettingsActionReader(onRead: { [weak self] in self?.action = $0 })
        hostingView.layoutSubtreeIfNeeded()
    }

    func open() {
        guard let action else {
            Logger.app.error("Settings action is not available")
            return
        }
        NSApp.activate()
        action()
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
