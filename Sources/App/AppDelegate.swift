import AppKit
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private let settingsOpener = SettingsOpener()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let opener = settingsOpener
        statusItemController = StatusItemController(openSettings: { opener.open() })
        Logger.app.info("Launched")

        #if DEBUG
        performDebugAction()
        #endif
    }

    #if DEBUG
    /// Lets a check run without a mouse: `open … --args -SRMDebugAction settings`.
    private func performDebugAction() {
        guard let action = UserDefaults.standard.string(forKey: "SRMDebugAction") else { return }
        // The status item gets its place in the menu bar only after launch.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            Logger.app.debug("Debug action: \(action, privacy: .public)")
            switch action {
            case "settings": settingsOpener.open()
            case "panel": statusItemController?.togglePanel()
            default: break
            }
        }
    }
    #endif
}
