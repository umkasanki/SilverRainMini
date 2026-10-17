import SwiftUI

@main
struct SilverRainMiniApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
        // HIG, Settings: the window takes the size of its content, so nobody needs to resize it.
        .windowResizability(.contentSize)
    }
}
