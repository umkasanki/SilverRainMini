import SwiftUI

/// The "Now Playing" card (SPEC FR-6, FR-7): the station's logo, its name, what
/// the player is doing, and the one button that starts or stops the sound.
struct NowPlayingCard: View {
    let state: PlaybackState
    let isOnFallback: Bool
    let streamTitle: String
    let togglePlayback: () -> Void

    /// The station's red, as in the approved mockup.
    private static let buttonColor = Color(red: 1, green: 0x36 / 255, blue: 0)

    var body: some View {
        HStack(spacing: 13) {
            StationArtwork()
            VStack(alignment: .leading, spacing: 2) {
                Text("Серебряный Дождь")
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text(Self.subtitle(for: state, isOnFallback: isOnFallback, streamTitle: streamTitle))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            playButton
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
    }

    private var playButton: some View {
        Button(action: togglePlayback) {
            Image(systemName: state.isActive ? "pause.fill" : "play.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Self.buttonColor, in: .circle)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(state.isActive ? "Пауза" : "Воспроизвести")
    }

    /// What the line under the station's name says (SPEC FR-7).
    static func subtitle(for state: PlaybackState, isOnFallback: Bool, streamTitle: String) -> String {
        switch state {
        case .idle: "Остановлено"
        case .connecting: "Подключение…"
        case .playing where isOnFallback: "В эфире · запасной поток"
        case .playing: "В эфире · \(streamTitle)"
        case .reconnecting: "Переподключение…"
        case .error: "Не удалось подключиться"
        }
    }
}

/// Dims a plain button while it is held, so a click is felt.
private struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(.circle)
    }
}
