import Foundation
import Observation

/// Ties the modules together; the interface reads everything from here.
@MainActor
@Observable
final class AppState {
    let player: RadioPlayer

    /// Fixed until the stream catalog arrives in step S6.
    let streamURL = URL(string: "https://silverrain.hostingradio.ru/silver64.aac")!

    init(player: RadioPlayer) {
        self.player = player
    }

    /// ▶︎ or ⏸: starts the live stream, or stops whatever the player is doing.
    func togglePlayback() {
        if player.state.isActive {
            player.stop()
        } else {
            player.play(streamURL)
        }
    }
}
