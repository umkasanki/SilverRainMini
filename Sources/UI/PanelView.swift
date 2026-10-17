import SwiftUI

/// The glass panel under the menu bar icon. Until step S5 it holds a plain
/// ▶︎/⏸ row to drive the player; the real cards arrive then.
struct PanelView: View {
    let appState: AppState
    let collapse: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            GlassEffectContainer {
                VStack(spacing: 10) {
                    nowPlaying
                        .padding(14)
                        .glassEffect(.regular, in: .rect(cornerRadius: 20))

                    Text("Звук")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .glassEffect(.regular, in: .rect(cornerRadius: 20))
                }
            }

            Button("Свернуть", action: collapse)
                .buttonStyle(.glass)
                .controlSize(.small)
        }
        .padding(10)
        .frame(width: 300)
    }

    private var nowPlaying: some View {
        HStack(spacing: 13) {
            StationArtwork()
            VStack(alignment: .leading, spacing: 2) {
                Text("Серебряный Дождь")
                    .font(.headline)
                Text(statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: appState.togglePlayback) {
                Image(systemName: isActive ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .frame(width: 32, height: 32)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isActive ? "Пауза" : "Воспроизвести")
        }
    }

    private var isActive: Bool { appState.player.state.isActive }

    /// Interim wording; SPEC FR-7 settles it in step S5.
    private var statusText: String {
        switch appState.player.state {
        case .idle: "AAC 96"
        case .connecting: "Подключение…"
        case .playing where appState.player.isOnFallback: "В эфире · запасной поток"
        case .playing: "В эфире · AAC 96"
        case .reconnecting: "Переподключение…"
        case .error: "Не удалось подключиться"
        }
    }
}
