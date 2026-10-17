import AppKit
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private var nowPlaying: NowPlayingBridge?
    private let settingsOpener = SettingsOpener()
    private lazy var appState = AppState(
        player: RadioPlayer(engine: AVPlayerEngine()),
        networkMonitor: NetworkMonitor(),
        sleepWatcher: SleepWatcher(),
        streamOverride: AppDelegate.streamOverride
    )

    private static var isHostingTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// In debug builds `-SRMDebugStreamURL <address>` stands in for the stream,
    /// e.g. a dead one to see the emergency path at work.
    private static var streamOverride: URL? {
        #if DEBUG
        UserDefaults.standard.string(forKey: "SRMDebugStreamURL").flatMap(URL.init(string:))
        #else
        nil
        #endif
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests run inside the app: they need its code, not its icon or its sound.
        guard !Self.isHostingTests else { return }
        let opener = settingsOpener
        statusItemController = StatusItemController(appState: appState, openSettings: { opener.open() })
        nowPlaying = NowPlayingBridge(appState: appState)
        Logger.app.info("Launched")
        if appState.playsOnLaunch {
            appState.playOnLaunch()
        }

        #if DEBUG
        performDebugAction()
        #endif
    }

    /// «Выйти» (SPEC FR-12): stop, and take the tile out of Control Centre.
    func applicationWillTerminate(_ notification: Notification) {
        // Nothing was set up when hosting tests.
        guard let nowPlaying else { return }
        appState.stopPlayback()
        nowPlaying.clear()
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
            case "play" where !appState.player.state.isActive: appState.togglePlayback()
            default: break
            }
        }
    }
    #endif
}
