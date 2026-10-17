import AppKit
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private let settingsOpener = SettingsOpener()
    private lazy var appState = AppState(
        player: RadioPlayer(engine: AVPlayerEngine()),
        networkMonitor: NetworkMonitor(),
        sleepWatcher: SleepWatcher(),
        streamURL: AppDelegate.streamURL
    )

    private static var isHostingTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// In debug builds `-SRMDebugStreamURL <address>` stands in for the stream,
    /// e.g. a dead one to see the emergency path at work.
    private static var streamURL: URL {
        #if DEBUG
        if let address = UserDefaults.standard.string(forKey: "SRMDebugStreamURL"),
           let url = URL(string: address) {
            return url
        }
        #endif
        return AppState.defaultStreamURL
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests run inside the app: they need its code, not its icon or its sound.
        guard !Self.isHostingTests else { return }
        let opener = settingsOpener
        statusItemController = StatusItemController(appState: appState, openSettings: { opener.open() })
        Logger.app.info("Launched")

        #if DEBUG
        performDebugAction()
        #endif
    }

    #if DEBUG
    /// Lets a check run without a mouse: `open … --args -SRMDebugAction settings|panel|play`.
    private func performDebugAction() {
        if let folder = UserDefaults.standard.string(forKey: "SRMDebugRenderIcons") {
            DebugIconRenderer.render(to: URL(filePath: folder))
            NSApp.terminate(nil)
        }
        guard let action = UserDefaults.standard.string(forKey: "SRMDebugAction") else { return }
        // The status item gets its place in the menu bar only after launch.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            Logger.app.debug("Debug action: \(action, privacy: .public)")
            switch action {
            case "settings": settingsOpener.open()
            case "panel": statusItemController?.togglePanel()
            case "play": appState.togglePlayback()
            default: break
            }
        }
    }
    #endif
}
